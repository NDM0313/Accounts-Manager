import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/utils/client_operation_id.dart';
import 'package:accounts_manager/core/utils/deal_posting_errors.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
import 'package:accounts_manager/domain/models/cash_bank_account.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
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
    this.initialDealId,
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
  final String? initialDealId;
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
  String? _dealId;
  String _dealSearch = '';
  DateTime _date = DateTime.now();
  bool _autoDescription = true;
  bool _reviewing = false;
  bool _busy = false;
  String? _postedTxId;
  String? _partySearch;
  final List<PlatformFile> _pendingFiles = [];

  static const _supportedCodes = ['PKR', 'USD', 'AED', 'CNY'];

  bool get _supportsDealAllocation =>
      FeatureFlags.dealsWorkflowEnabled &&
      _isReceiveFlow &&
      (widget.mode == TransactionDraftMode.customerReceipt ||
          widget.mode == TransactionDraftMode.standard);

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
    _dealId = widget.initialDealId;
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

  String _generatedDescription(
    FxParty? party,
    FxAccount? vault, {
    String? dealLabel,
  }) {
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
      dealLabel: dealLabel,
      extraNotes: _notesCtrl.text,
    );
  }

  String _finalDescription(
    FxParty? party,
    FxAccount? vault, {
    String? dealLabel,
  }) {
    if (_autoDescription) {
      return _generatedDescription(party, vault, dealLabel: dealLabel);
    }
    return _manualDescCtrl.text.trim();
  }

  List<FxDeal> _allocatableDeals(List<FxDeal> all) {
    if (_partyId == null) return const [];
    final q = _dealSearch.trim().toLowerCase();
    return all.where((d) {
      if (d.customerPartyId != _partyId) return false;
      if (!d.status.isOpen) return false;
      if (d.customerReceivablePkr <= 0.005) return false;
      // Deal customer payments are PKR settlement via existing engine.
      if (_currencyCode != 'PKR') return false;
      if (q.isEmpty) return true;
      final no = (d.dealNo ?? '').toLowerCase();
      return no.contains(q) || d.id.toLowerCase().contains(q);
    }).toList();
  }

  String _dealLabel(FxDeal? deal) {
    if (deal == null) return '';
    final no = deal.dealNo ?? deal.id.substring(0, 8);
    return '$no · due PKR ${NumberFormat('#,##0.##').format(deal.customerReceivablePkr)}';
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
    FxDeal? allocatedDeal,
  }) async {
    if (_postedTxId != null) {
      if (!mounted) return;
      context.go('/transactions/$_postedTxId');
      return;
    }
    final dealLabel =
        allocatedDeal == null ? null : _dealLabel(allocatedDeal);
    final desc = _finalDescription(party, vault, dealLabel: dealLabel);
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description cannot be empty')),
      );
      return;
    }
    if (allocatedDeal != null) {
      if (_currencyCode != 'PKR') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deal allocation posts PKR settlement only'),
          ),
        );
        return;
      }
      if (_amount > allocatedDeal.customerReceivablePkr + 0.0000001) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Amount cannot exceed deal outstanding'),
          ),
        );
        return;
      }
    }
    setState(() => _busy = true);
    try {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw StateError('Profile not configured');

      late final String txId;
      if (allocatedDeal != null) {
        // Deal-linked receipt uses the deal payment engine only — no second
        // generic settlement draft.
        final opId = await ClientOperationId.beginAmounted(
          'composer_deal_receipt',
          allocatedDeal.id,
          _amount,
        );
        txId = await ref.read(dealRepositoryProvider).recordCustomerPayment(
              dealId: allocatedDeal.id,
              amountPkr: _amount,
              notes: desc,
              cashAccountId: vault.id,
              clientOperationId: opId,
            );
        await ClientOperationId.completeAmounted(
          'composer_deal_receipt',
          allocatedDeal.id,
        );
        ref.read(dealsRefreshProvider.notifier).refresh();
      } else {
        // Generic settlement has no RPC client_operation_id; guard repeats via
        // [_postedTxId] so Confirm cannot create a second draft after success.
        final repo = ref.read(transactionRepositoryProvider);
        final tx = await repo.createDraft(
          companyId: profile.companyId,
          branchId: profile.branchId,
          type: _txType,
          currencyCode: _currencyCode,
          foreignAmount: _amount,
          rateUsed: 1,
          baseAmountPkr: _amount,
          accounts: accounts,
          description: desc,
          transactionDate: _date,
          fromAccountCode: vault.code,
          partyId: party.id,
          settlementAccountCode: _settlementControlCodeFor(party),
        );
        final posted = await repo.postTransaction(tx.id);
        txId = posted.id;
      }

      for (final f in _pendingFiles) {
        if (f.bytes == null) continue;
        try {
          await ref.read(attachmentRepositoryProvider).upload(
                companyId: profile.companyId,
                branchId: profile.branchId,
                transactionId: txId,
                fileName: f.name,
                bytes: f.bytes!,
                attachmentType: 'proof',
              );
        } catch (_) {
          // Keep posting; surface attachment failure after success.
        }
      }

      _postedTxId = txId;
      ref.invalidate(partyDirectoryBalancesProvider);
      if (_partyId != null) {
        ref.invalidate(partyStatementProvider(_partyId!));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allocatedDeal == null
                ? widget.mode.successTitle
                : 'Deal receipt posted (no extra settlement)',
          ),
        ),
      );
      context.go('/transactions/$txId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyDealPostingError(e))),
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
    final dealsAsync = _supportsDealAllocation
        ? ref.watch(dealsListProvider)
        : const AsyncValue<List<FxDeal>>.data([]);
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
                  final allDeals = dealsAsync.asData?.value ?? const <FxDeal>[];
                  final deals = _allocatableDeals(allDeals);
                  if (_dealId != null &&
                      !deals.any((d) => d.id == _dealId)) {
                    // Keep selection only while still eligible; otherwise clear.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _dealId != null) {
                        setState(() => _dealId = null);
                      }
                    });
                  }
                  final selectedDeal =
                      deals.where((d) => d.id == _dealId).firstOrNull;

                  if (_reviewing) {
                    return _buildReview(
                      context,
                      party: party,
                      vault: vault,
                      accounts: accounts,
                      allocatedDeal: selectedDeal,
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
                    deals: deals,
                    dealsLoading: dealsAsync.isLoading,
                    dealsError: dealsAsync.hasError,
                    allocatedDeal: selectedDeal,
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
    required List<FxDeal> deals,
    required bool dealsLoading,
    required bool dealsError,
    required FxDeal? allocatedDeal,
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
                  : (v) => setState(() {
                        _partyId = v;
                        _dealId = null;
                      }),
            ),
          ],
        ),
        if (_supportsDealAllocation &&
            party?.partyType == FxPartyType.customer) ...[
          const SizedBox(height: 20),
          FxFormSection(
            title: 'Deal allocation',
            optional: true,
            subtitle:
                'Optional. Allocating posts via the deal payment engine only — '
                'not a second generic settlement. Leave empty for a general '
                'party receipt.',
            children: [
              if (dealsLoading) const LinearProgressIndicator(),
              if (dealsError)
                Text(
                  'Could not load deals. Retry or leave unallocated.',
                  style: AppTypography.bodySm(fx.error, context: context),
                ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search deal number',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _dealSearch = v),
              ),
              DropdownButtonFormField<String?>(
                key: ValueKey('deal-$_partyId-$_dealId'),
                initialValue: _dealId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Allocate to deal (optional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None — general party receipt'),
                  ),
                  ...deals.map(
                    (d) => DropdownMenuItem<String?>(
                      value: d.id,
                      child: Text(_dealLabel(d)),
                    ),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                          _dealId = v;
                          if (v != null && _currencyCode != 'PKR') {
                            _currencyCode = 'PKR';
                            _vaultAccountCode = null;
                          }
                        }),
              ),
              if (allocatedDeal != null)
                Text(
                  'Outstanding PKR ${fmt.format(allocatedDeal.customerReceivablePkr)} '
                  '(paid ${fmt.format(allocatedDeal.customerPaidPkr)} of '
                  '${fmt.format(allocatedDeal.customerPayablePkr)}). '
                  'Partial receipts allowed; overpayment blocked.',
                  style: AppTypography.bodySm(
                    fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
            ],
          ),
        ],
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
                  if (_finalDescription(
                    party,
                    vault,
                    dealLabel: allocatedDeal == null
                        ? null
                        : _dealLabel(allocatedDeal),
                  ).isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Description cannot be empty'),
                      ),
                    );
                    return;
                  }
                  if (allocatedDeal != null &&
                      _amount > allocatedDeal.customerReceivablePkr + 0.0000001) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Amount cannot exceed deal outstanding'),
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
            child: _sideSummary(
              party: party,
              vault: vault,
              allocatedDeal: allocatedDeal,
              fmt: fmt,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sideSummary({
    required FxParty? party,
    required FxAccount? vault,
    required FxDeal? allocatedDeal,
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
          const SizedBox(height: 8),
          Text(
            allocatedDeal == null
                ? 'Type: general party receipt'
                : 'Type: deal allocation — ${_dealLabel(allocatedDeal)}',
            style: AppTypography.bodySm(fx.onSurfaceVariant, context: context),
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
    required FxDeal? allocatedDeal,
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
    final dealLabel =
        allocatedDeal == null ? null : _dealLabel(allocatedDeal);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(sentence, style: AppTypography.headlineSm(fx.onSurface, context: context)),
        const SizedBox(height: 12),
        Text(
          allocatedDeal == null
              ? 'General party receipt (not allocated to a deal).'
              : 'Deal-allocated receipt — posts once via deal payment engine.',
          style: AppTypography.bodyMd(fx.onSurfaceVariant, context: context),
        ),
        if (dealLabel != null) ...[
          const SizedBox(height: 8),
          Text('Deal: $dealLabel'),
        ],
        const SizedBox(height: 16),
        Text('Description', style: AppTypography.headlineSm(fx.onSurface, context: context)),
        const SizedBox(height: 8),
        Text(
          _finalDescription(party, vault, dealLabel: dealLabel),
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
                          allocatedDeal: allocatedDeal,
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
