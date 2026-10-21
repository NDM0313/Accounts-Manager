import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/utils/client_operation_id.dart';
import 'package:accounts_manager/core/utils/image_compressor.dart';
import 'package:accounts_manager/data/repositories/slip_import_repository.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/slip_import/ocr/pak_bank_slip_parser.dart';
import 'package:accounts_manager/features/slip_import/ocr/slip_ocr_engine.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

final slipImportRepositoryProvider = Provider((_) => SlipImportRepository());

/// Import Payment Slip → OCR draft → human review → explicit confirm post.
class ImportPaymentSlipScreen extends ConsumerStatefulWidget {
  const ImportPaymentSlipScreen({super.key, this.dealId});

  final String? dealId;

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
  String? _partyId;
  String _currency = 'PKR';
  String _classification = 'receive_from_party';
  List<String> _uncertain = [];
  List<Map<String, dynamic>> _duplicates = [];
  String? _ocrError;
  String? _printedStatus;
  bool _busy = false;
  bool _keepHighQuality = false;
  bool _ready = false;

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
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
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
              'Clipboard image paste varies by browser. Upload a file, or paste OCR text here.',
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
        });
        return;
      }

      if (!SlipOcrEngine.isSupported) {
        setState(() {
          _ocrError = 'OCR needs Flutter web. Fields remain editable.';
          _ready = true;
        });
        return;
      }

      try {
        final raw = await SlipOcrEngine.recognizeImageBytes(
          bytes,
          mimeType: mime ?? 'image/jpeg',
        );
        final extract = PakBankSlipParser.parse(raw);
        _applyExtract(extract);
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
          'extracted_json': extract.toJson(),
          'description': PakBankSlipParser.buildDescription(extract),
          'attachment_id': _attachmentId,
          'ocr_engine': SlipOcrEngine.engineId,
          'status': 'draft',
        });
        setState(() => _ready = true);
      } catch (e) {
        setState(() {
          _ocrError = e.toString();
          _ready = true;
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

  void _applyExtract(SlipOcrExtract e) {
    _amountCtrl.text = e.amount?.toString() ?? '';
    _dateCtrl.text = e.txnDate ?? '';
    _timeCtrl.text = e.txnTimeText ?? '';
    _refCtrl.text = e.bankReference ?? '';
    _senderCtrl.text = e.senderName ?? '';
    _receiverCtrl.text = e.receiverName ?? '';
    _rawCtrl.text = e.rawText;
    _currency = e.currencyCode ?? 'PKR';
    _printedStatus = e.printedStatus;
    _uncertain = List.of(e.uncertainFields);
    _descCtrl.text = PakBankSlipParser.buildDescription(e);
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
    if (_classification == 'unsupported') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unsupported — kept as draft only')),
      );
      return;
    }
    if (_classification == 'internal_transfer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use the Transfer transaction workflow for own-account moves.',
          ),
        ),
      );
      return;
    }
    if (_partyId == null) {
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
              'cash_account_id': _cashAccountId,
              'counterparty_party_id': _partyId,
              'deal_id': widget.dealId,
              'attachment_id': _attachmentId,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          );

      final opId = await ClientOperationId.begin(
        'slip_import_confirm',
        '$_importId:$amount:$_cashAccountId:$_partyId',
      );
      final txId = await ref.read(slipImportRepositoryProvider).confirm(
            importId: _importId!,
            clientOperationId: opId,
          );
      if (!mounted) return;
      context.go('/transactions/$txId');
    } catch (e) {
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
    final accountsAsync = ref.watch(accountsProvider);
    final partiesAsync = ref.watch(partiesProvider(null));

    return Scaffold(
      backgroundColor: fx.background,
      appBar: AppBar(
        title: const Text('Import Payment Slip'),
        backgroundColor: fx.background,
        actions: [
          TextButton(onPressed: _busy ? null : _pick, child: const Text('Upload')),
          TextButton(
            onPressed: _busy ? null : _pasteText,
            child: const Text('Paste text'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'OCR creates a DRAFT only. Nothing posts until you confirm.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (_fileName == null)
            FilledButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload slip image or PDF'),
            )
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_file),
              title: Text(_fileName!),
              subtitle: Text(
                _originalBytes == null
                    ? 'Attached'
                    : 'Original ${ImageCompressor.formatBytes(_originalBytes!)}'
                        ' → stored ${ImageCompressor.formatBytes(_storedBytes ?? _originalBytes!)}'
                        '${_keptOriginal ? ' (original kept)' : ' (compressed; not byte-identical)'}',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep higher quality on next upload'),
              value: _keepHighQuality,
              onChanged: _busy ? null : (v) => setState(() => _keepHighQuality = v),
            ),
          ],
          if (_busy) const LinearProgressIndicator(),
          if (_ocrError != null) ...[
            const SizedBox(height: 8),
            Material(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('OCR note: $_ocrError'),
              ),
            ),
          ],
          if (_printedStatus != null)
            Text(
              'Printed status: $_printedStatus (not bank-verified)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_duplicates.isNotEmpty) ...[
            const SizedBox(height: 8),
            Material(
              color: Colors.amber.shade50,
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
          if (_uncertain.isNotEmpty)
            Text(
              'Uncertain: ${_uncertain.join(', ')} — verify before posting',
              style: TextStyle(color: Colors.deepOrange.shade700),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _classification,
            decoration: const InputDecoration(labelText: 'Classification'),
            items: const [
              DropdownMenuItem(
                value: 'receive_from_party',
                child: Text('Money received from party'),
              ),
              DropdownMenuItem(
                value: 'pay_to_party',
                child: Text('Money paid to party'),
              ),
              DropdownMenuItem(
                value: 'internal_transfer',
                child: Text('Own-account transfer (use Transfer form)'),
              ),
              DropdownMenuItem(
                value: 'unsupported',
                child: Text('Unsupported / draft only'),
              ),
            ],
            onChanged: (v) =>
                setState(() => _classification = v ?? _classification),
          ),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
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
            onChanged: (v) => setState(() => _currency = v ?? _currency),
          ),
          TextFormField(
            controller: _dateCtrl,
            decoration: const InputDecoration(
              labelText: 'Date YYYY-MM-DD (as on slip)',
            ),
          ),
          TextFormField(
            controller: _timeCtrl,
            decoration: const InputDecoration(labelText: 'Time as printed'),
          ),
          TextFormField(
            controller: _refCtrl,
            decoration: const InputDecoration(
              labelText: 'Bank reference / TID (keep leading zeros)',
            ),
          ),
          TextFormField(
            controller: _senderCtrl,
            decoration: const InputDecoration(labelText: 'Sender name'),
          ),
          TextFormField(
            controller: _receiverCtrl,
            decoration: const InputDecoration(labelText: 'Receiver name'),
          ),
          accountsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Accounts error: $e'),
            data: (accounts) {
              final cash = accounts
                  .where(
                    (a) =>
                        a.accountType == 'asset' &&
                        (a.code.startsWith('11') || a.code.startsWith('12')),
                  )
                  .toList();
              return DropdownButtonFormField<String>(
                initialValue: _cashAccountId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Our cash/bank account',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      final id =
                          await context.push<String>('/accounts/new-cash');
                      ref.invalidate(accountsProvider);
                      if (id != null) setState(() => _cashAccountId = id);
                    },
                  ),
                ),
                items: cash
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          '${a.code} ${a.name} (${a.currencyCode ?? 'PKR'})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _cashAccountId = v),
              );
            },
          ),
          partiesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text('Parties error: $e'),
            data: (parties) => DropdownButtonFormField<String>(
              initialValue: _partyId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Counterparty',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.person_add_alt),
                  onPressed: () async {
                    final id = await context.push<String>('/parties/new');
                    ref.invalidate(partiesProvider(null));
                    if (id != null) setState(() => _partyId = id);
                  },
                ),
              ),
              items: parties
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        '${p.name} (${p.partyType.label})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _partyId = v),
            ),
          ),
          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          TextFormField(
            controller: _rawCtrl,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Raw OCR / pasted text'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy || (!_ready && _bytes == null) ? null : _confirm,
            child: Text(_busy ? 'Working…' : 'Confirm & post'),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
