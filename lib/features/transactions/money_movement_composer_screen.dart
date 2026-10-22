import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
import 'package:accounts_manager/domain/models/cash_bank_account.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/models/transaction_draft_mode.dart';
import 'package:accounts_manager/domain/services/money_movement_description.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Shared Receive Money / Pay Money composer — one form, review, then post.
class MoneyMovementComposerScreen extends ConsumerStatefulWidget {
  const MoneyMovementComposerScreen({
    super.key,
    required this.mode,
    this.forceReceive,
    this.initialPartyId,
    this.initialAmount,
    this.initialCurrency,
    this.initialAccountCode,
    this.initialMethod,
    this.initialReference,
    this.initialDescription,
    this.initialDate,
    this.attachmentImportId,
  });

  final TransactionDraftMode mode;
  /// When [mode] is standard, explicitly choose receive vs pay.
  final bool? forceReceive;
  final String? initialPartyId;
  final double? initialAmount;
  final String? initialCurrency;
  final String? initialAccountCode;
  final String? initialMethod; // bank | cash
  final String? initialReference;
  final String? initialDescription;
  final DateTime? initialDate;
  final String? attachmentImportId;

  static const leaveFallback = '/accounts-hub';

  @override
  ConsumerState<MoneyMovementComposerScreen> createState() =>
      _MoneyMovementComposerScreenState();
}

class _MoneyMovementComposerScreenState
    extends ConsumerState<MoneyMovementComposerScreen> {
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _manualDescCtrl = TextEditingController();
  final _partySearchCtrl = TextEditingController();

  String? _partyId;
  String _currencyCode = 'PKR';
  String _method = 'bank'; // bank | cash
  String? _vaultAccountCode;
  DateTime _date = DateTime.now();
  bool _autoDescription = true;
  bool _reviewing = false;
  bool _busy = false;
  String? _partySearch;
  final List<PlatformFile> _pendingFiles = [];

  static const _supportedCodes = ['PKR', 'USD', 'AED', 'CNY'];

  bool get _isReceiveFlow {
    if (widget.forceReceive != null) return widget.forceReceive!;
    return switch (widget.mode) {
      TransactionDraftMode.customerReceipt ||
      TransactionDraftMode.agentReturn => true,
      TransactionDraftMode.agentPayment ||
      TransactionDraftMode.customerRefund => false,
      TransactionDraftMode.standard => true,
    };
  }

  @override
  void initState() {
    super.initState();
    _partyId = widget.initialPartyId;
    if (widget.initialAmount != null) {
      _amountCtrl.text = widget.initialAmount!.toStringAsFixed(
        widget.initialAmount! == widget.initialAmount!.roundToDouble()
            ? 0
            : 2,
      );
    }
    if (widget.initialCurrency != null &&
        _supportedCodes.contains(widget.initialCurrency!.toUpperCase())) {
      _currencyCode = widget.initialCurrency!.toUpperCase();
    }
    if (widget.initialMethod == 'cash' || widget.initialMethod == 'bank') {
      _method = widget.initialMethod!;
    }
    _vaultAccountCode = widget.initialAccountCode;
    if (widget.initialReference != null) {
      _referenceCtrl.text = widget.initialReference!;
    }
    if (widget.initialDescription != null &&
        widget.initialDescription!.trim().isNotEmpty) {
      _autoDescription = false;
      _manualDescCtrl.text = widget.initialDescription!;
    }
    if (widget.initialDate != null) _date = widget.initialDate!;
    _amountCtrl.addListener(() => setState(() {}));
    _notesCtrl.addListener(() => setState(() {}));
    _manualDescCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    _manualDescCtrl.dispose();
    _partySearchCtrl.dispose();
    super.dispose();
  }

  double get _amount =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;

  FxTransactionType get _txType {
    if (widget.mode != TransactionDraftMode.standard) {
      return widget.mode.transactionType;
    }
    return _isReceiveFlow
        ? FxTransactionType.settlementReceive
        : FxTransactionType.settlementSend;
  }

  String? _settlementControlCodeFor(FxParty? party) {
    final fromMode = widget.mode.defaultSettlementAccount;
    if (fromMode != null) return fromMode;
    if (party == null) return _isReceiveFlow ? '1190' : '2100';
    if (_isReceiveFlow) {
      return party.partyType == FxPartyType.customer ? '1190' : '1180';
    }
    return party.partyType == FxPartyType.customer ? '2200' : '2100';
  }

  List<FxPartyType> get _partyTypes {
    switch (widget.mode) {
      case TransactionDraftMode.customerReceipt:
      case TransactionDraftMode.customerRefund:
        return [FxPartyType.customer];
      case TransactionDraftMode.agentPayment:
      case TransactionDraftMode.agentReturn:
        return [FxPartyType.agent, FxPartyType.settlement];
      case TransactionDraftMode.standard:
        return [
          FxPartyType.customer,
          FxPartyType.agent,
          FxPartyType.settlement,
          FxPartyType.supplier,
        ];
    }
  }

  String get _title {
    if (widget.mode != TransactionDraftMode.standard) {
      return switch (widget.mode) {
        TransactionDraftMode.customerReceipt => 'Receive Money',
        TransactionDraftMode.agentReturn => 'Receive Money',
        TransactionDraftMode.agentPayment => 'Pay Money',
        TransactionDraftMode.customerRefund => 'Pay Money',
        TransactionDraftMode.standard => 'Money movement',
      };
    }
    return _isReceiveFlow ? 'Receive Money' : 'Pay Money';
  }

  String _generatedDescription(FxParty? party, FxAccount? vault) {
    return MoneyMovementDescription.build(
      mode: widget.mode == TransactionDraftMode.standard
          ? (_isReceiveFlow
              ? TransactionDraftMode.customerReceipt
              : TransactionDraftMode.agentPayment)
          : widget.mode,
      currencyCode: _currencyCode,
      amount: _amount,
      partyName: party?.name ?? 'party',
      vaultAccount: vault,
      reference: _referenceCtrl.text,
      extraNotes: _notesCtrl.text,
    );
  }

  String _finalDescription(FxParty? party, FxAccount? vault) {
    if (_autoDescription) return _generatedDescription(party, vault);
    return _manualDescCtrl.text.trim();
  }

  void _invalidateVaultIfNeeded(List<FxAccount> accounts) {
    if (_vaultAccountCode == null) return;
    final eligible = CashBankAccountRules.filterEligible(
      accounts: accounts,
      method: _method,
      currencyCode: _currencyCode,
    );
    if (!eligible.any((a) => a.code == _vaultAccountCode)) {
      _vaultAccountCode = null;
    }
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      for (final f in result.files) {
        if (f.bytes == null) continue;
        _pendingFiles.add(f);
      }
    });
  }

  Future<void> _confirmAndPost({
    required FxParty party,
    required FxAccount vault,
    required List<FxAccount> accounts,
  }) async {
    final desc = _finalDescription(party, vault);
    if (!_autoDescription && desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a description or turn Auto on')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw StateError('Profile not configured');
      final repo = ref.read(transactionRepositoryProvider);
      final tx = await repo.createDraft(
        companyId: profile.companyId,
        branchId: profile.branchId,
        type: _txType,
        currencyCode: _currencyCode,
        foreignAmount: _amount,
        rateUsed: 1,
        baseAmountPkr: _currencyCode == 'PKR' ? _amount : _amount,
        accounts: accounts,
        description: desc,
        transactionDate: _date,
        fromAccountCode: vault.code,
        partyId: party.id,
        settlementAccountCode: _settlementControlCodeFor(party),
      );

      for (final f in _pendingFiles) {
        if (f.bytes == null) continue;
        try {
          await ref.read(attachmentRepositoryProvider).upload(
                companyId: profile.companyId,
                branchId: profile.branchId,
                transactionId: tx.id,
                fileName: f.name,
                bytes: f.bytes!,
                attachmentType: 'proof',
              );
        } catch (_) {
          // Keep posting; surface attachment failure after success.
        }
      }

      final posted = await repo.postTransaction(tx.id);
      ref.invalidate(partyDirectoryBalancesProvider);
      if (_partyId != null) {
        ref.invalidate(partyStatementProvider(_partyId!));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.mode.successTitle)),
      );
      context.go('/transactions/${posted.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Posting failed: $e')),
      );
      setState(() => _reviewing = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final partiesAsync = ref.watch(partiesProvider(null));
    final fmt = NumberFormat('#,##0.##');
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return FxPremiumScaffold(
      title: Text(_reviewing ? 'Review' : _title),
      fallbackRoute: MoneyMovementComposerScreen.leaveFallback,
      actions: [
        IconButton(
          tooltip: 'Scan slip',
          onPressed: _busy
              ? null
              : () => context.push(
                    '/slips/import?returnTo=money&mode=${widget.mode.dbValue}',
                  ),
          icon: const Icon(Icons.document_scanner_outlined),
        ),
      ],
      body: profileAsync.when(
        loading: () => const FxLoadingState(),
        error: (e, _) => FxErrorState(message: '$e'),
        data: (profile) {
          if (profile == null) {
            return const FxErrorState(message: 'Sign in required');
          }
          return accountsAsync.when(
            loading: () => const FxLoadingState(),
            error: (e, _) => FxErrorState(message: '$e'),
            data: (accounts) {
              _invalidateVaultIfNeeded(accounts);
              final eligible = CashBankAccountRules.filterEligible(
                accounts: accounts,
                method: _method,
                currencyCode: _currencyCode,
              );
              final vault = eligible
                  .where((a) => a.code == _vaultAccountCode)
                  .firstOrNull;
              return partiesAsync.when(
                loading: () => const FxLoadingState(),
                error: (e, _) => FxErrorState(message: '$e'),
                data: (allParties) {
                  final parties = allParties
                      .where((p) => _partyTypes.contains(p.partyType))
                      .where((p) {
                        final q = (_partySearch ?? '').trim().toLowerCase();
                        if (q.isEmpty) return true;
                        return p.name.toLowerCase().contains(q) ||
                            p.code.toLowerCase().contains(q);
                      })
                      .toList();
                  final party =
                      allParties.where((p) => p.id == _partyId).firstOrNull;

                  if (_reviewing) {
                    return _buildReview(
                      context,
                      party: party,
                      vault: vault,
                      accounts: accounts,
                      fmt: fmt,
                      isWide: isWide,
                    );
                  }

                  return _buildForm(
                    context,
                    parties: parties,
                    party: party,
                    eligible: eligible,
                    vault: vault,
                    fmt: fmt,
                    isWide: isWide,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildForm(
    BuildContext context, {
    required List<FxParty> parties,
    required FxParty? party,
    required List<FxAccount> eligible,
    required FxAccount? vault,
    required NumberFormat fmt,
    required bool isWide,
  }) {
    final fx = context.fx;
    final form = ListView(
      padding: EdgeInsets.fromLTRB(
        isWide ? 24 : 16,
        16,
        isWide ? 24 : 16,
        32 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        FxFormSection(
          title: _isReceiveFlow ? 'Receive from' : 'Pay to',
          children: [
            TextField(
              controller: _partySearchCtrl,
              decoration: const InputDecoration(
                labelText: 'Search party',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _partySearch = v),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('party-$_partyId'),
              initialValue: _partyId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _isReceiveFlow ? 'Party' : 'Payee',
              ),
              items: parties
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.name} (${p.partyType.name})'),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _partyId = v),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FxFormSection(
          title: 'Amount',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Currency'),
                    child: Text(
                      _currencyCode,
                      style: AppTypography.headlineSm(fx.onSurface, context: context),
                    ),
                  ),
                ),
              ],
            ),
            if (_currencyCode == 'PKR')
              Text(
                'Settlement currency is PKR for this workflow.',
                style: AppTypography.bodySm(fx.onSurfaceVariant, context: context),
              ),
          ],
        ),
        const SizedBox(height: 20),
        FxFormSection(
          title: _isReceiveFlow ? 'Receive into' : 'Pay from',
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'bank', label: Text('Bank'), icon: Icon(Icons.account_balance)),
                ButtonSegment(value: 'cash', label: Text('Cash'), icon: Icon(Icons.payments_outlined)),
              ],
              selected: {_method},
              onSelectionChanged: _busy
                  ? null
                  : (s) => setState(() {
                        _method = s.first;
                        _vaultAccountCode = null;
                      }),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('vault-$_method-$_currencyCode-$_vaultAccountCode'),
              initialValue: _vaultAccountCode,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _method == 'bank' ? 'Bank account' : 'Cash account',
              ),
              items: eligible
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.code,
                      child: Text(CashBankAccountRules.displayLabel(a)),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _vaultAccountCode = v),
            ),
            if (eligible.isEmpty)
              Text(
                'No active ${_method == 'bank' ? 'bank' : 'cash'} accounts '
                'for $_currencyCode. Add an account first.',
                style: AppTypography.bodySm(fx.error, context: context),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => context.push('/accounts/new-cash?kind=$_method'),
                icon: const Icon(Icons.add),
                label: const Text('Add Account'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FxFormSection(
          title: 'Details',
          optional: true,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat.yMMMd().format(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _busy
                  ? null
                  : () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (d != null) setState(() => _date = d);
                    },
            ),
            TextField(
              controller: _referenceCtrl,
              decoration: const InputDecoration(
                labelText: 'Reference (optional)',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FxFormSection(
          title: 'Description',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto description'),
              value: _autoDescription,
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                        if (!v && _manualDescCtrl.text.trim().isEmpty) {
                          _manualDescCtrl.text =
                              _generatedDescription(party, vault);
                        }
                        _autoDescription = v;
                      }),
            ),
            if (_autoDescription) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: fx.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _generatedDescription(party, vault),
                  style: AppTypography.bodyMd(fx.onSurface, context: context),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Additional notes (optional)',
                ),
                maxLines: 2,
              ),
            ] else ...[
              TextField(
                controller: _manualDescCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (required)',
                ),
                maxLines: 3,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _manualDescCtrl.text =
                                _generatedDescription(party, vault);
                          }),
                  child: const Text('Regenerate from details'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        FxFormSection(
          title: 'Attachments',
          optional: true,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _pendingFiles.length; i++)
                  Chip(
                    label: Text(_pendingFiles[i].name),
                    onDeleted: _busy
                        ? null
                        : () => setState(() => _pendingFiles.removeAt(i)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.attach_file, size: 18),
                  label: const Text('Add proof'),
                  onPressed: _busy ? null : _pickAttachments,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _busy
              ? null
              : () {
                  if (_partyId == null || party == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select a party')),
                    );
                    return;
                  }
                  if (_amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid amount')),
                    );
                    return;
                  }
                  if (_vaultAccountCode == null || vault == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Select a ${_method == 'bank' ? 'bank' : 'cash'} account',
                        ),
                      ),
                    );
                    return;
                  }
                  if (!_autoDescription &&
                      _manualDescCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Description is required when Auto is off'),
                      ),
                    );
                    return;
                  }
                  setState(() => _reviewing = true);
                },
          child: Text(
            _isReceiveFlow ? 'Review receipt' : 'Review payment',
          ),
        ),
      ],
    );

    if (!isWide) return form;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: form),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 24, 16),
            child: _sideSummary(party: party, vault: vault, fmt: fmt),
          ),
        ),
      ],
    );
  }

  Widget _sideSummary({
    required FxParty? party,
    required FxAccount? vault,
    required NumberFormat fmt,
  }) {
    final fx = context.fx;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: fx.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Summary',
            style: AppTypography.headlineSm(fx.onSurface, context: context),
          ),
          const SizedBox(height: 12),
          Text(
            MoneyMovementDescription.reviewSentence(
              isReceive: _isReceiveFlow,
              currencyCode: _currencyCode,
              amount: _amount,
              partyName: party?.name ?? '—',
              vaultAccount: vault,
            ),
            style: AppTypography.bodyMd(fx.onSurface, context: context),
          ),
        ],
      ),
    );
  }

  Widget _buildReview(
    BuildContext context, {
    required FxParty? party,
    required FxAccount? vault,
    required List<FxAccount> accounts,
    required NumberFormat fmt,
    required bool isWide,
  }) {
    final fx = context.fx;
    final sentence = MoneyMovementDescription.reviewSentence(
      isReceive: _isReceiveFlow,
      currencyCode: _currencyCode,
      amount: _amount,
      partyName: party?.name ?? '—',
      vaultAccount: vault,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(sentence, style: AppTypography.headlineSm(fx.onSurface, context: context)),
        const SizedBox(height: 16),
        Text('Description', style: AppTypography.headlineSm(fx.onSurface, context: context)),
        const SizedBox(height: 8),
        Text(
          _finalDescription(party, vault),
          style: AppTypography.bodyMd(fx.onSurface, context: context),
        ),
        if (_referenceCtrl.text.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Reference: ${_referenceCtrl.text.trim()}'),
        ],
        if (_pendingFiles.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('${_pendingFiles.length} attachment(s) will upload with this post.'),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            OutlinedButton(
              onPressed: _busy ? null : () => setState(() => _reviewing = false),
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _busy || party == null || vault == null
                    ? null
                    : () => _confirmAndPost(
                          party: party,
                          vault: vault,
                          accounts: accounts,
                        ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _isReceiveFlow ? 'Confirm receipt' : 'Confirm payment',
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
