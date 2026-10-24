import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/app/theme/fx_design_tokens.dart';
import 'package:accounts_manager/core/utils/client_operation_id.dart';
import 'package:accounts_manager/core/utils/image_compressor.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
import 'package:accounts_manager/data/repositories/slip_import_repository.dart';
import 'package:accounts_manager/domain/models/cash_bank_account.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/slip_import/ocr/pak_bank_slip_parser.dart';
import 'package:accounts_manager/features/slip_import/ocr/slip_ocr_engine.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

final slipImportRepositoryProvider = Provider((_) => SlipImportRepository());

enum _SlipPhase { capture, review, action }

/// Import Payment Slip → OCR draft → human review → choose action → composer/post.
class ImportPaymentSlipScreen extends ConsumerStatefulWidget {
  const ImportPaymentSlipScreen({
    super.key,
    this.dealId,
    this.returnTo,
    this.moneyMode,
  });

  static const leaveFallback = '/accounts-hub';

  final String? dealId;
  /// When `money`, leave/handoff returns to the money composer.
  final String? returnTo;
  final String? moneyMode;

  @override
  ConsumerState<ImportPaymentSlipScreen> createState() =>
      _ImportPaymentSlipScreenState();
}

class _ImportPaymentSlipScreenState
    extends ConsumerState<ImportPaymentSlipScreen> {
  final _amountCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _senderCtrl = TextEditingController();
  final _receiverCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _rawCtrl = TextEditingController();

  Uint8List? _bytes;
  String? _fileName;
  int? _originalBytes;
  int? _storedBytes;
  bool _keptOriginal = false;
  String? _contentHash;
  String? _importId;
  String? _attachmentId;
  String? _clientOp;
  String? _cashAccountId;
  String? _destinationAccountId;
  String? _partyId;
  String _currency = 'PKR';
  String _classification = 'receive_from_party';
  String _partyFlow = 'unspecified';
  List<String> _uncertain = [];
  List<Map<String, dynamic>> _duplicates = [];
  String? _ocrError;
  String? _ocrProgress;
  String? _printedStatus;
  bool _busy = false;
  bool _keepHighQuality = false;
  bool _ready = false;
  bool _userTouchedFields = false;
  bool _showRawOcr = false;
  bool _showHelp = false;
  _SlipPhase _phase = _SlipPhase.capture;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _refCtrl.dispose();
    _senderCtrl.dispose();
    _receiverCtrl.dispose();
    _descCtrl.dispose();
    _rawCtrl.dispose();
    super.dispose();
  }

  String? _mimeFor(String? ext) => switch (ext?.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => null,
      };

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'heic'],
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.extension?.toLowerCase() == 'heic') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'HEIC is not supported in mobile Safari web — export as JPEG/PNG/PDF first.',
            ),
          ),
        );
      }
      return;
    }
    if (f.bytes == null) return;
    await _ingest(f.bytes!, f.name, _mimeFor(f.extension));
  }

  Future<void> _pasteText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.length < 20) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No usable OCR text on clipboard. Upload JPEG/PNG/WebP, or paste slip text. '
              'HEIC/PDF OCR is not reliable in browsers.',
            ),
          ),
        );
      }
      return;
    }
    setState(() {
      _rawCtrl.text = text;
      _applyExtract(PakBankSlipParser.parse(text));
      _ready = true;
      _ocrError = null;
      _phase = _SlipPhase.review;
    });
  }

  Future<void> _pasteClipboardImage() async {
    // Flutter web Clipboard API exposes text reliably; image paste is
    // browser-specific. Prefer Upload when image paste is unavailable.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Clipboard image paste is not available in this browser build. '
            'Use Upload (JPEG/PNG/WebP). Camera capture uses the file picker when the OS offers it.',
          ),
        ),
      );
    }
  }

  void _openComposerFromReview() {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    final receive = _classification == 'receive_from_party';
    final pay = _classification == 'pay_to_party';
    if (!receive && !pay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose Receive or Pay first'),
        ),
      );
      return;
    }
    if (_partyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identify the party before continuing')),
      );
      return;
    }
    final mode = receive
        ? (_partyFlow == 'agent_settlement' ? 'agent_return' : 'customer_receipt')
        : (_partyFlow == 'customer_receipt' || _partyFlow == 'unspecified'
            ? 'agent_payment'
            : _partyFlow == 'supplier_payment'
                ? 'agent_payment'
                : 'customer_refund');
    final accounts = ref.read(accountsProvider).asData?.value ?? const [];
    final vault = accounts.where((a) => a.id == _cashAccountId).firstOrNull;
    final method = vault == null
        ? null
        : (CashBankAccountRules.isBankVault(vault) ? 'bank' : 'cash');
    final q = <String, String>{
      'direction': receive ? 'receive' : 'pay',
      'mode': mode,
      'partyId': _partyId!,
      if (amount != null) 'amount': amount.toString(),
      'currency': _currency,
      if (_refCtrl.text.trim().isNotEmpty) 'reference': _refCtrl.text.trim(),
      if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
      if (vault != null) 'account': vault.code,
      if (method != null) 'method': method,
      if (_attachmentId != null) 'attachmentId': _attachmentId!,
    };
    final qs = q.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    context.push('/transactions/money?$qs');
  }

  void _resetCapture() {
    setState(() {
      _bytes = null;
      _fileName = null;
      _ready = false;
      _ocrError = null;
      _ocrProgress = null;
      _phase = _SlipPhase.capture;
      _showRawOcr = false;
    });
  }

  Future<void> _ingest(Uint8List bytes, String name, String? mime) async {
    setState(() {
      _busy = true;
      _ocrError = null;
      _ready = false;
      _bytes = bytes;
      _fileName = name;
      _contentHash = sha256.convert(bytes).toString();
      _originalBytes = bytes.length;
    });
    try {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) return;

      final preview = await ImageCompressor.compressIfNeeded(
        input: bytes,
        fileName: name,
        mimeType: mime,
        preferHigherQuality: _keepHighQuality,
      );
      _storedBytes = preview.storedBytes;
      _keptOriginal = preview.keptOriginal;

      _duplicates = await ref.read(slipImportRepositoryProvider).findDuplicates(
            contentHash: _contentHash,
          );

      _clientOp = 'slip-${const Uuid().v4()}';
      _importId = await ref.read(slipImportRepositoryProvider).upsertDraft({
        'client_operation_id': _clientOp,
        'branch_id': profile.branchId,
        'status': 'draft',
        'content_hash': _contentHash,
        'ocr_engine': SlipOcrEngine.engineId,
        'deal_id': widget.dealId,
      });

      final att = await ref.read(attachmentRepositoryProvider).upload(
            companyId: profile.companyId,
            branchId: profile.branchId,
            fileName: name,
            bytes: bytes,
            mimeType: mime,
            preferHigherQuality: _keepHighQuality,
            slipImportId: _importId,
            attachmentType: 'payment_slip',
          );
      _attachmentId = att.id;
      _originalBytes = att.originalByteSize ?? bytes.length;
      _storedBytes = att.storedByteSize ?? att.fileSizeBytes;
      _keptOriginal =
          att.compressionMeta?['action']?.toString().contains('passthrough') ==
          true;

      if (mime == 'application/pdf') {
        setState(() {
          _ocrError =
              'PDF OCR is limited in-browser. Enter fields from the slip; file stays attached.';
          _ready = true;
          _phase = _SlipPhase.review;
        });
        return;
      }

      if (!SlipOcrEngine.isSupported) {
        setState(() {
          _ocrError = 'OCR needs Flutter web. Fields remain editable.';
          _ready = true;
          _phase = _SlipPhase.review;
        });
        return;
      }

      try {
        final raw = await SlipOcrEngine.recognizeImageBytes(
          bytes,
          mimeType: mime ?? 'image/jpeg',
          onProgress: (s) {
            if (mounted) setState(() => _ocrProgress = s);
          },
        );
        final extract = PakBankSlipParser.parse(raw);
        // Never overwrite fields the user already corrected.
        _applyExtract(extract, onlyEmpty: _userTouchedFields);
        await ref.read(slipImportRepositoryProvider).upsertDraft({
          'client_operation_id': _clientOp,
          'raw_text': raw,
          'amount': extract.amount,
          'currency_code': extract.currencyCode ?? 'PKR',
          'txn_date': extract.txnDate,
          'txn_time_text': extract.txnTimeText,
          'sender_name': extract.senderName,
          'receiver_name': extract.receiverName,
          'sender_account_mask': extract.senderAccountMask,
          'receiver_account_mask': extract.receiverAccountMask,
          'bank_reference': extract.bankReference,
          'provider_name': extract.providerName,
          'printed_status': extract.printedStatus,
          'uncertain_fields': extract.uncertainFields,
          'extracted_json': {
            ...extract.toJson(),
            'processing': 'in_browser_wasm',
            'engine': SlipOcrEngine.engineId,
          },
          'description': PakBankSlipParser.buildDescription(extract),
          'attachment_id': _attachmentId,
          'ocr_engine': SlipOcrEngine.engineId,
          'status': 'draft',
        });
        setState(() {
          _ready = true;
          _ocrProgress = null;
          _phase = _SlipPhase.review;
        });
      } catch (e) {
        setState(() {
          _ocrError = e.toString();
          _ocrProgress = null;
          _ready = true;
          _phase = _SlipPhase.review;
        });
        await ref.read(slipImportRepositoryProvider).upsertDraft({
          'client_operation_id': _clientOp,
          'ocr_error': e.toString(),
          'attachment_id': _attachmentId,
          'status': 'draft',
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyExtract(SlipOcrExtract e, {bool onlyEmpty = false}) {
    void put(TextEditingController c, String? v) {
      if (v == null || v.isEmpty) return;
      if (onlyEmpty && c.text.trim().isNotEmpty) return;
      c.text = v;
    }

    put(_amountCtrl, e.amount?.toString());
    put(_dateCtrl, e.txnDate);
    put(_timeCtrl, e.txnTimeText);
    put(_refCtrl, e.bankReference);
    put(_senderCtrl, e.senderName);
    put(_receiverCtrl, e.receiverName);
    if (!onlyEmpty || _rawCtrl.text.trim().isEmpty) {
      _rawCtrl.text = e.rawText;
    }
    if (!onlyEmpty || _currency.isEmpty) {
      _currency = e.currencyCode ?? _currency;
    }
    _printedStatus = e.printedStatus ?? _printedStatus;
    _uncertain = List.of(e.uncertainFields);
    if (!onlyEmpty || _descCtrl.text.trim().isEmpty) {
      _descCtrl.text = PakBankSlipParser.buildDescription(e);
    }
  }

  Future<void> _confirm() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (_importId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload a slip first')),
      );
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a positive amount')),
      );
      return;
    }
    if (_cashAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select cash/bank account')),
      );
      return;
    }
    if (_classification == 'unsupported' ||
        _partyFlow == 'agent_to_beneficiary') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kept as draft — unsupported / agent-to-beneficiary does not post to our bank.',
          ),
        ),
      );
      return;
    }
    if (_classification == 'internal_transfer') {
      if (_destinationAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select destination cash/bank account')),
        );
        return;
      }
      if (_destinationAccountId == _cashAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source and destination must differ')),
        );
        return;
      }
    } else if (_partyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select counterparty')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(slipImportRepositoryProvider).updateFields(
            importId: _importId!,
            fields: {
              'amount': amount,
              'currency_code': _currency,
              'txn_date':
                  _dateCtrl.text.trim().isEmpty ? null : _dateCtrl.text.trim(),
              'txn_time_text':
                  _timeCtrl.text.trim().isEmpty ? null : _timeCtrl.text.trim(),
              'sender_name': _senderCtrl.text.trim().isEmpty
                  ? null
                  : _senderCtrl.text.trim(),
              'receiver_name': _receiverCtrl.text.trim().isEmpty
                  ? null
                  : _receiverCtrl.text.trim(),
              'bank_reference':
                  _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
              'printed_status': _printedStatus,
              'raw_text': _rawCtrl.text,
              'description': _descCtrl.text.trim(),
              'classification': _classification,
              'party_flow': _partyFlow,
              'cash_account_id': _cashAccountId,
              'destination_account_id': _destinationAccountId,
              'counterparty_party_id': _partyId,
              'deal_id': widget.dealId,
              'attachment_id': _attachmentId,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          );

      final opId = await ClientOperationId.begin(
        'slip_import_confirm',
        '$_importId:$amount:$_cashAccountId:${_destinationAccountId ?? _partyId}',
      );
      final txId = await ref.read(slipImportRepositoryProvider).confirm(
            importId: _importId!,
            clientOperationId: opId,
          );
      if (!mounted) return;
      context.go('/transactions/$txId');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('DUPLICATE_TRANSFER') &&
          _duplicates.isNotEmpty &&
          _duplicates.first['resulting_tx_id'] != null &&
          mounted) {
        final existingTx = _duplicates.first['resulting_tx_id'] as String;
        final attach = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Duplicate transfer'),
            content: const Text(
              'Same reference/amount/account already confirmed. '
              'Attach this slip as extra evidence without posting again?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Attach only'),
              ),
            ],
          ),
        );
        if (attach == true) {
          final txId = await ref.read(slipImportRepositoryProvider).attachToExisting(
                importId: _importId!,
                transactionId: existingTx,
              );
          if (mounted) context.go('/transactions/$txId');
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Confirm failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final title = switch (_phase) {
      _SlipPhase.capture => 'Scan slip',
      _SlipPhase.review => 'Review extracted data',
      _SlipPhase.action => 'Choose action',
    };

    final leave = widget.returnTo == 'money'
        ? '/transactions/money${widget.moneyMode != null ? '?mode=${widget.moneyMode}' : ''}'
        : ImportPaymentSlipScreen.leaveFallback;

    return FxPremiumScaffold(
      title: Text(title),
      fallbackRoute: leave,
      backgroundColor: fx.background,
      actions: [
        IconButton(
          tooltip: 'Help',
          onPressed: () => setState(() => _showHelp = !_showHelp),
          icon: const Icon(Icons.help_outline),
        ),
      ],
      body: FxContentContainer(
        formWidth: true,
        padding: EdgeInsets.zero,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            _phaseIndicator(fx),
            const SizedBox(height: 12),
            Text(
              'OCR creates a draft only. Scanning never posts money.',
              style: AppTypography.bodySm(fx.onSurfaceVariant, context: context),
            ),
            if (_showHelp) ...[
              const SizedBox(height: 8),
              Text(
                'JPEG/PNG/WebP OCR on web. PDF attaches without full OCR. '
                'HEIC is unsupported — convert first. A printed “Pending/Failed” '
                'status is not proof that funds settled. Bank names on slips '
                'never auto-select an internal account.',
                style: AppTypography.bodySm(fx.onSurfaceVariant, context: context),
              ),
            ],
            const SizedBox(height: 16),
            if (_phase == _SlipPhase.capture) _buildCapture(fx),
            if (_phase == _SlipPhase.review) _buildReview(fx),
            if (_phase == _SlipPhase.action) _buildAction(fx),
          ],
        ),
      ),
    );
  }

  Widget _phaseIndicator(FxColors fx) {
    Widget step(String label, bool active, bool done) {
      return Expanded(
        child: Column(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: done || active ? fx.primary : fx.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.bodySm(
                active ? fx.primary : fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontWeight: active ? FontWeight.w600 : FontWeight.w400),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        step('Capture', _phase == _SlipPhase.capture, _phase != _SlipPhase.capture),
        const SizedBox(width: 8),
        step(
          'Review',
          _phase == _SlipPhase.review,
          _phase == _SlipPhase.action,
        ),
        const SizedBox(width: 8),
        step('Action', _phase == _SlipPhase.action, false),
      ],
    );
  }

  Widget _buildCapture(FxColors fx) {
    final clipboardImageSupported = kIsWeb; // honest: web paste image is limited
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: context.fxAccentSurface(FxAccent.scan),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fx.outlineVariant),
          ),
          child: Column(
            children: [
              Icon(
                Icons.document_scanner_outlined,
                size: 48,
                color: context.fxAccent(FxAccent.scan),
              ),
              const SizedBox(height: 12),
              Text(
                'Upload or capture a payment slip',
                textAlign: TextAlign.center,
                style: AppTypography.headlineSm(fx.onSurface, context: context),
              ),
              const SizedBox(height: 8),
              Text(
                'JPEG, PNG or WebP preferred. Nothing posts until you confirm.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm(
                  fx.onSurfaceVariant,
                  context: context,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file),
                label: Text(_busy ? 'Working…' : 'Upload slip'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera / file picker'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pasteText,
          icon: const Icon(Icons.content_paste),
          label: const Text('Paste slip text'),
        ),
        const SizedBox(height: 8),
        if (clipboardImageSupported)
          OutlinedButton.icon(
            onPressed: _busy ? null : _pasteClipboardImage,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Paste clipboard image'),
          )
        else
          Text(
            'Clipboard image paste is unavailable on this platform.',
            style: AppTypography.bodySm(fx.onSurfaceVariant, context: context),
          ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          if (_ocrProgress != null) ...[
            const SizedBox(height: 8),
            Text('Extracting: $_ocrProgress'),
          ],
        ],
        if (_fileName != null && _busy) ...[
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _bytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _bytes!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.attach_file),
                    ),
                  )
                : const Icon(Icons.attach_file),
            title: Text(_fileName!),
            subtitle: const Text('Uploading & extracting…'),
          ),
        ],
      ],
    );
  }

  Widget _buildReview(FxColors fx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_fileName != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _bytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _bytes!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.attach_file),
                    ),
                  )
                : const Icon(Icons.attach_file),
            title: Text(_fileName!),
            subtitle: Text(
              _originalBytes == null
                  ? 'Attached'
                  : '${ImageCompressor.formatBytes(_originalBytes!)}'
                      '${_keptOriginal ? '' : ' → compressed'}',
            ),
            trailing: TextButton(
              onPressed: _busy ? null : _resetCapture,
              child: const Text('Replace'),
            ),
          ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        if (_ocrError != null) ...[
          const SizedBox(height: 8),
          Material(
            color: fx.warningContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'OCR note: $_ocrError\nDraft kept — correct fields or retry.',
                style: AppTypography.bodySm(fx.onSurface, context: context),
              ),
            ),
          ),
        ],
        if (_printedStatus != null) ...[
          const SizedBox(height: 8),
          Text(
            'Printed status: $_printedStatus — not bank-verified settlement.',
            style: AppTypography.bodySm(fx.onSurfaceVariant, context: context)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
        if (_duplicates.isNotEmpty) ...[
          const SizedBox(height: 8),
          Material(
            color: fx.warningContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Possible duplicates:'),
                  ..._duplicates.map(
                    (d) => Text(
                      '• ${d['match_reason']} / ${d['status']} / '
                      'tx=${d['resulting_tx_id'] ?? '—'}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_uncertain.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Uncertain: ${_uncertain.join(', ')} — verify before posting',
            style: AppTypography.bodySm(fx.error, context: context),
          ),
        ],
        const SizedBox(height: 12),
        FxFormBlock(
          dense: true,
          title: 'Extracted fields',
          children: [
            FxAmountEntry(
              controller: _amountCtrl,
              currencyCode: _currency,
              onChanged: (_) => _userTouchedFields = true,
            ),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: const [
                DropdownMenuItem(value: 'PKR', child: Text('PKR')),
                DropdownMenuItem(value: 'USD', child: Text('USD')),
                DropdownMenuItem(value: 'AED', child: Text('AED')),
                DropdownMenuItem(value: 'CNY', child: Text('CNY (RMB)')),
              ],
              onChanged: (v) {
                _userTouchedFields = true;
                setState(() => _currency = v ?? _currency);
              },
            ),
            TextFormField(
              controller: _dateCtrl,
              decoration: const InputDecoration(
                labelText: 'Date YYYY-MM-DD (as on slip)',
              ),
              onChanged: (_) => _userTouchedFields = true,
            ),
            TextFormField(
              controller: _timeCtrl,
              decoration: const InputDecoration(labelText: 'Time as printed'),
              onChanged: (_) => _userTouchedFields = true,
            ),
            TextFormField(
              controller: _refCtrl,
              decoration: const InputDecoration(
                labelText: 'Bank reference / TID (keep leading zeros)',
              ),
              onChanged: (_) => _userTouchedFields = true,
            ),
            TextFormField(
              controller: _senderCtrl,
              decoration: const InputDecoration(labelText: 'Sender name'),
              onChanged: (_) => _userTouchedFields = true,
            ),
            TextFormField(
              controller: _receiverCtrl,
              decoration: const InputDecoration(labelText: 'Receiver name'),
              onChanged: (_) => _userTouchedFields = true,
            ),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (_) => _userTouchedFields = true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          initiallyExpanded: _showRawOcr,
          onExpansionChanged: (v) => setState(() => _showRawOcr = v),
          title: const Text('Raw OCR text'),
          children: [
            TextFormField(
              controller: _rawCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Raw OCR / pasted text',
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Keep higher quality on next upload'),
          value: _keepHighQuality,
          onChanged: _busy ? null : (v) => setState(() => _keepHighQuality = v),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () => setState(() => _phase = _SlipPhase.action),
          child: const Text('Continue — choose action'),
        ),
        TextButton(
          onPressed: _busy ? null : _resetCapture,
          child: const Text('Replace image'),
        ),
      ],
    );
  }

  Widget _buildAction(FxColors fx) {
    final accountsAsync = ref.watch(accountsProvider);
    final partiesAsync = ref.watch(partiesProvider(null));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Identify what this slip means. A bank name from OCR does not '
          'select your internal account.',
          style: AppTypography.bodySm(fx.onSurfaceVariant, context: context),
        ),
        const SizedBox(height: 12),
        FxFormBlock(
          dense: true,
          title: 'Action',
          children: [
            DropdownButtonFormField<String>(
              initialValue: _classification,
              decoration: const InputDecoration(labelText: 'What happened?'),
              items: const [
                DropdownMenuItem(
                  value: 'receive_from_party',
                  child: Text('Receive from party'),
                ),
                DropdownMenuItem(
                  value: 'pay_to_party',
                  child: Text('Pay to party'),
                ),
                DropdownMenuItem(
                  value: 'internal_transfer',
                  child: Text('Internal transfer'),
                ),
                DropdownMenuItem(
                  value: 'unsupported',
                  child: Text('Unsupported / draft only'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _classification = v ?? _classification),
            ),
            if (_classification != 'internal_transfer')
              DropdownButtonFormField<String>(
                initialValue: _partyFlow,
                decoration: const InputDecoration(
                  labelText: 'Party flow detail',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'unspecified',
                    child: Text('Unspecified'),
                  ),
                  DropdownMenuItem(
                    value: 'customer_receipt',
                    child: Text('Customer receipt'),
                  ),
                  DropdownMenuItem(
                    value: 'supplier_refund',
                    child: Text('Supplier refund (incoming)'),
                  ),
                  DropdownMenuItem(
                    value: 'supplier_payment',
                    child: Text('Supplier payment (outgoing)'),
                  ),
                  DropdownMenuItem(
                    value: 'agent_settlement',
                    child: Text('Agent settlement'),
                  ),
                  DropdownMenuItem(
                    value: 'agent_to_beneficiary',
                    child: Text('Agent→beneficiary (draft only)'),
                  ),
                ],
                onChanged: (v) => setState(() => _partyFlow = v ?? _partyFlow),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FxFormBlock(
          dense: true,
          title: 'Our account',
          children: [
            accountsAsync.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Text('Accounts error: $e'),
              data: (accounts) {
                final cash = accounts
                    .where(
                      (a) =>
                          CashBankAccountRules.isCashVault(a) ||
                          CashBankAccountRules.isBankVault(a),
                    )
                    .toList();
                return Column(
                  children: [
                    FxSearchableSelect<String>(
                      labelText: _classification == 'internal_transfer'
                          ? 'From (source) cash/bank'
                          : 'Cash / bank account',
                      hintText: 'Search our accounts…',
                      value: _cashAccountId,
                      enabled: !_busy,
                      addNewLabel: 'Add account',
                      options: cash
                          .map(
                            (a) => FxSearchableOption(
                              value: a.id,
                              label: '${a.code} ${a.name}',
                              subtitle:
                                  '${CashBankAccountRules.isBankVault(a) ? 'Bank' : 'Cash'} · ${a.currencyCode ?? 'PKR'}',
                              searchText: '${a.code} ${a.name}',
                            ),
                          )
                          .toList(),
                      onSelected: (v) => setState(() => _cashAccountId = v),
                      onAddNew: () async {
                        final id =
                            await context.push<String>('/accounts/new-cash');
                        ref.invalidate(accountsProvider);
                        if (id != null) setState(() => _cashAccountId = id);
                      },
                    ),
                    if (_classification == 'internal_transfer') ...[
                      const SizedBox(height: 8),
                      FxSearchableSelect<String>(
                        labelText: 'To (destination)',
                        hintText: 'Search destination…',
                        value: _destinationAccountId,
                        enabled: !_busy,
                        options: cash
                            .map(
                              (a) => FxSearchableOption(
                                value: a.id,
                                label: '${a.code} ${a.name}',
                                subtitle: a.currencyCode ?? 'PKR',
                              ),
                            )
                            .toList(),
                        onSelected: (v) =>
                            setState(() => _destinationAccountId = v),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
        if (_classification != 'internal_transfer') ...[
          const SizedBox(height: 16),
          FxFormBlock(
            dense: true,
            title: 'Party',
            children: [
              partiesAsync.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (e, _) => Text('Parties error: $e'),
                data: (parties) => FxSearchableSelect<String>(
                  labelText: 'Counterparty',
                  hintText: 'Search party…',
                  value: _partyId,
                  enabled: !_busy,
                  addNewLabel: 'Add party',
                  options: parties
                      .map(
                        (p) => FxSearchableOption(
                          value: p.id,
                          label: p.name,
                          subtitle: '${p.code} · ${p.partyType.label}',
                          searchText: '${p.name} ${p.code}',
                        ),
                      )
                      .toList(),
                  onSelected: (v) => setState(() => _partyId = v),
                  onAddNew: () async {
                    final id = await context.push<String>('/parties/new');
                    ref.invalidate(partiesProvider(null));
                    if (id != null) setState(() => _partyId = id);
                  },
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        if (_classification == 'receive_from_party' ||
            _classification == 'pay_to_party')
          FilledButton.icon(
            onPressed: _busy ? null : _openComposerFromReview,
            icon: const Icon(Icons.arrow_forward),
            label: Text(
              _classification == 'receive_from_party'
                  ? 'Continue in Receive composer'
                  : 'Continue in Pay composer',
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _busy || !_ready ? null : _confirm,
          child: Text(_busy ? 'Working…' : 'Confirm & post via slip import'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() => _phase = _SlipPhase.review),
          child: const Text('Back to review'),
        ),
      ],
    );
  }
}
