import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_attachments_section.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_currency.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/models/fx_user_profile.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DraftTransactionScreen extends ConsumerStatefulWidget {
  const DraftTransactionScreen({
    super.key,
    this.type = FxTransactionType.currencyBuy,
    this.initialCurrency,
    this.suggestedRate,
    this.initialPartyId,
    this.editDraftId,
  });

  final FxTransactionType type;
  final String? initialCurrency;
  final double? suggestedRate;
  final String? initialPartyId;
  final String? editDraftId;

  @override
  ConsumerState<DraftTransactionScreen> createState() => _DraftTransactionScreenState();
}

class _DraftTransactionScreenState extends ConsumerState<DraftTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _foreignAmountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '1');
  final _toForeignAmountCtrl = TextEditingController();
  final _toRateCtrl = TextEditingController(text: '1');
  final _descriptionCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  String? _currencyCode;
  String? _toCurrencyCode;
  String? _fromAccountCode;
  String? _toAccountCode;
  String? _expenseAccountCode;
  String? _settlementAccountCode;
  String? _partyId;
  DateTime? _transactionDate;
  bool _busy = false;
  String? _draftId;
  bool _rateInitialized = false;
  bool _loadedEdit = false;
  bool _editLoadFailed = false;
  String? _editLoadError;
  FxTransactionType? _editType;
  bool _isPostedEdit = false;

  @override
  void initState() {
    super.initState();
    _partyId = widget.initialPartyId;
    if (widget.editDraftId == null) {
      final now = DateTime.now();
      _transactionDate = DateTime(now.year, now.month, now.day);
    }
    if (widget.editDraftId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadEditDraft());
    }
  }

  Future<void> _loadEditDraft() async {
    try {
      final tx = await ref.read(transactionRepositoryProvider).fetchTransactionWithLines(widget.editDraftId!);
      if (!mounted) return;
      setState(() {
        if (tx.isPosted) {
          _isPostedEdit = true;
          _applyPosted(tx);
        } else if (tx.isDraft) {
          _applyDraft(tx);
        } else {
          _editLoadFailed = true;
          _editLoadError = 'Only draft or posted transactions can be edited.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _editLoadFailed = true;
          _editLoadError = e.toString();
        });
      }
    }
  }

  void _applyPosted(FxTransaction tx) {
    _loadedEdit = true;
    _editType = tx.transactionType;
    _draftId = tx.id;
    _currencyCode = tx.currencyCode;
    _foreignAmountCtrl.text = tx.totalForeignAmount.toString();
    _rateCtrl.text = tx.rateUsed.toString();
    _descriptionCtrl.text = tx.description ?? '';
    _transactionDate = tx.transactionDate;
    _rateInitialized = true;
  }

  @override
  void dispose() {
    _foreignAmountCtrl.dispose();
    _rateCtrl.dispose();
    _toForeignAmountCtrl.dispose();
    _toRateCtrl.dispose();
    _descriptionCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  double get _foreignAmount => double.tryParse(_foreignAmountCtrl.text) ?? 0;
  double get _rateUsed => double.tryParse(_rateCtrl.text) ?? 1;
  double get _toForeignAmount => double.tryParse(_toForeignAmountCtrl.text) ?? 0;
  double get _toRateUsed => double.tryParse(_toRateCtrl.text) ?? 1;

  double get _baseAmountPkr {
    final type = _editType ?? widget.type;
    return switch (type) {
      FxTransactionType.currencyBuy || FxTransactionType.currencySell => _foreignAmount * _rateUsed,
      FxTransactionType.crossCurrency => _foreignAmount * _rateUsed,
      FxTransactionType.revaluation || FxTransactionType.dailyClosingAdjustment => _foreignAmount,
      FxTransactionType.openingBalance =>
        _currencyCode == 'PKR' ? _foreignAmount : _foreignAmount * _rateUsed,
      _ => _foreignAmount,
    };
  }

  bool get _allowsSignedAmount {
    final type = _editType ?? widget.type;
    return type == FxTransactionType.dailyClosingAdjustment ||
        type == FxTransactionType.revaluation;
  }

  bool _ensureTransactionDate(BuildContext context) {
    if (_transactionDate != null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select transaction date.')),
    );
    return false;
  }

  Widget _buildTransactionDateField() {
    final dateLabel = _transactionDate != null
        ? DateFormat('d MMM yyyy').format(_transactionDate!)
        : 'Select date';

    return InkWell(
      onTap: _busy
          ? null
          : () async {
              final picked = await FxObsidianPickers.showDate(
                context,
                initialDate: _transactionDate ?? DateTime.now(),
              );
              if (picked != null) setState(() => _transactionDate = picked);
            },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FxSectionLabel(label: 'Transaction date'),
                Text(dateLabel, style: AppTypography.bodyMd(context.fx.onSurface, context: context)),
              ],
            ),
          ),
          Icon(Icons.calendar_today_outlined, color: context.fx.onSurfaceVariant),
        ],
      ),
    );
  }

  void _applySuggestedRate(List<dynamic> rates) {
    if (_rateInitialized || widget.type == FxTransactionType.openingBalance) return;
    if (widget.suggestedRate != null) {
      _rateCtrl.text = widget.suggestedRate!.toString();
      _rateInitialized = true;
      return;
    }
    if (_currencyCode == null) return;
    for (final r in rates) {
      if (r.currencyCode == _currencyCode) {
        final rate = widget.type == FxTransactionType.currencyBuy ? r.buyRate : r.sellRate;
        _rateCtrl.text = rate.toString();
        _rateInitialized = true;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPostedEdit && _loadedEdit) {
      return _buildPostedEditScaffold(context);
    }

    final profileAsync = ref.watch(currentProfileProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final currenciesAsync = ref.watch(currenciesProvider);
    final ratesAsync = ref.watch(ratesProvider);

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        title: Text(
          widget.editDraftId != null
              ? 'Edit Transaction'
              : 'New ${widget.type.label}',
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Profile error: $e')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('Profile not configured.'));
          if (widget.editDraftId != null && !_loadedEdit && !_editLoadFailed) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_editLoadFailed) {
            return Center(child: Text(_editLoadError ?? 'Unable to load.'));
          }
          return accountsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Unable to load accounts: $e')),
            data: (accounts) => currenciesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Unable to load currencies: $e')),
              data: (currencies) => ratesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Unable to load rates: $e')),
                data: (rates) {
                  _currencyCode ??= widget.initialCurrency ??
                      (widget.type == FxTransactionType.openingBalance
                          ? currencies.firstOrNull?.code
                          : currencies.where((c) => !c.isBase).firstOrNull?.code) ??
                      currencies.firstOrNull?.code;
                  _fromAccountCode ??= switch (widget.type) {
                    FxTransactionType.expense => '1110',
                    FxTransactionType.settlementSend ||
                    FxTransactionType.settlementReceive ||
                    FxTransactionType.dailyClosingAdjustment ||
                    FxTransactionType.revaluation =>
                      accounts.where((a) => a.code == '1110').firstOrNull?.code,
                    _ => null,
                  };
                  _expenseAccountCode ??= widget.type == FxTransactionType.expense ? '5800' : null;
                  _settlementAccountCode ??= switch (widget.type) {
                    FxTransactionType.settlementSend => '2100',
                    FxTransactionType.settlementReceive => '1180',
                    _ => null,
                  };
                  _toCurrencyCode ??= widget.type == FxTransactionType.crossCurrency
                      ? currencies.where((c) => c.code != _currencyCode && !c.isBase).firstOrNull?.code ??
                          currencies.where((c) => !c.isBase).firstOrNull?.code
                      : null;
                  if (widget.editDraftId == null) {
                    _applySuggestedRate(rates);
                  } else if (_loadedEdit && !_rateInitialized) {
                    _applySuggestedRate(rates);
                  }
                  return _buildDraftForm(context, profile, accounts, currencies, type: _editType ?? widget.type);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostedEditScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        title: const Text('Edit Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
                  16,
                  MediaQuery.sizeOf(context).width >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
                  16,
                ),
                children: [
                  _warningBanner(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.fx.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                      border: Border.all(color: context.fx.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTransactionDateField(),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: FxObsidianFormField(
                                label: 'Amount',
                                controller: _foreignAmountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                enabled: !_busy,
                                textAlign: TextAlign.end,
                                style: AppTypography.currencyDisplay(color: context.fx.onSurface, mobile: true, context: context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: context.fx.tertiaryContainer,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              ),
                              child: Text(
                                _currencyCode ?? '',
                                style: AppTypography.labelMono(context.fx.onTertiary, context: context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FxObsidianFormField(
                          label: 'Rate (PKR)',
                          controller: _rateCtrl,
                          enabled: !_busy,
                          textAlign: TextAlign.end,
                        ),
                        const SizedBox(height: 16),
                        FxObsidianFormField(
                          label: 'Notes',
                          controller: _descriptionCtrl,
                          maxLines: 3,
                          enabled: !_busy,
                        ),
                        const SizedBox(height: 16),
                        Consumer(
                          builder: (context, ref, _) {
                            final profile = ref.watch(currentProfileProvider).value;
                            if (profile == null) return const SizedBox.shrink();
                            return _attachmentsSection(profile);
                          },
                        ),
                        const SizedBox(height: 16),
                        FxObsidianFormField(
                          label: 'Reason for edit',
                          controller: _reasonCtrl,
                          maxLines: 2,
                          accentTertiary: true,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Reason is required' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            FxObsidianActionBar(
              busy: _busy,
              onCancel: () => context.pop(),
              onSave: _savePostedEdit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: context.fx.tertiary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completed Transaction',
                  style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'This change will update ledger and reports. Reason is required.',
                  style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentsSection(FxUserProfile profile) {
    if (_draftId == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FxSectionLabel(label: 'Attachment / Proof'),
          const SizedBox(height: 8),
          Text(
            'Save draft first to attach files.',
            style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
          ),
        ],
      );
    }
    return FxAttachmentsSection(
      transactionId: _draftId!,
      branchId: profile.branchId,
      enabled: !_busy,
    );
  }

  Widget _buildDraftForm(
    BuildContext context,
    FxUserProfile profile,
    List<FxAccount> accounts,
    List<FxCurrency> currencies, {
    required FxTransactionType type,
  }) {
    final cashAccounts = accounts.where((a) => a.code.startsWith('11')).toList();
    final expenseAccounts = accounts.where((a) => a.accountType == 'expense').toList();
    final settlementAccounts = accounts
        .where((a) => ['1180', '1190', '2100', '2200'].contains(a.code))
        .toList();

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
                16,
                MediaQuery.sizeOf(context).width >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
                16,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.fx.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    border: Border.all(color: context.fx.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTransactionDateField(),
                      const SizedBox(height: 16),
                      FxSectionLabel(label: 'Amount & rate'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_currencyCode),
                        initialValue: _currencyCode,
                        decoration: const InputDecoration(labelText: 'Currency'),
                        items: currencies.map((c) => DropdownMenuItem(value: c.code, child: Text(c.code))).toList(),
                        onChanged: _busy ? null : (v) => setState(() { _currencyCode = v; _rateInitialized = false; }),
                      ),
                      const SizedBox(height: 12),
                      FxObsidianFormField(
                        label: _allowsSignedAmount ? 'Amount (PKR, signed)' : 'Amount',
                        controller: _foreignAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        enabled: !_busy,
                        textAlign: TextAlign.end,
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n == 0) {
                            return _allowsSignedAmount ? 'Enter a non-zero amount' : 'Enter a positive amount';
                          }
                          if (!_allowsSignedAmount && n <= 0) return 'Enter a positive amount';
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      if (type == FxTransactionType.currencyBuy ||
                          type == FxTransactionType.currencySell ||
                          type == FxTransactionType.crossCurrency ||
                          (type == FxTransactionType.openingBalance && _currencyCode != 'PKR')) ...[
                        const SizedBox(height: 12),
                        FxObsidianFormField(
                          label: 'Rate (PKR per unit)',
                          controller: _rateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          enabled: !_busy,
                          textAlign: TextAlign.end,
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Enter a valid rate';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      if (type == FxTransactionType.accountTransfer) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_fromAccountCode),
                          initialValue: _fromAccountCode,
                          decoration: const InputDecoration(labelText: 'From account'),
                          items: cashAccounts.map((a) => DropdownMenuItem(value: a.code, child: Text('${a.code} · ${a.name}'))).toList(),
                          onChanged: _busy ? null : (v) => setState(() => _fromAccountCode = v),
                          validator: (v) => v == null ? 'Select source account' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_toAccountCode),
                          initialValue: _toAccountCode,
                          decoration: const InputDecoration(labelText: 'To account'),
                          items: cashAccounts.map((a) => DropdownMenuItem(value: a.code, child: Text('${a.code} · ${a.name}'))).toList(),
                          onChanged: _busy ? null : (v) => setState(() => _toAccountCode = v),
                          validator: (v) => v == null ? 'Select destination account' : null,
                        ),
                      ],
                      if (type == FxTransactionType.crossCurrency) ...[
                        const SizedBox(height: 16),
                        FxSectionLabel(label: 'Receive leg'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_toCurrencyCode),
                          initialValue: _toCurrencyCode,
                          decoration: const InputDecoration(labelText: 'To currency'),
                          items: currencies
                              .where((c) => !c.isBase)
                              .map((c) => DropdownMenuItem(value: c.code, child: Text(c.code)))
                              .toList(),
                          onChanged: _busy ? null : (v) => setState(() => _toCurrencyCode = v),
                          validator: (v) => v == null ? 'Select to currency' : null,
                        ),
                        const SizedBox(height: 12),
                        FxObsidianFormField(
                          label: 'To amount',
                          controller: _toForeignAmountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          enabled: !_busy,
                          textAlign: TextAlign.end,
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Enter a positive amount';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        FxObsidianFormField(
                          label: 'To rate (PKR per unit)',
                          controller: _toRateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          enabled: !_busy,
                          textAlign: TextAlign.end,
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Enter a valid rate';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      if (type.isSettlement) ...[
                        const SizedBox(height: 12),
                        Consumer(
                          builder: (context, ref, _) {
                            final partiesAsync = ref.watch(partiesProvider(null));
                            return partiesAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (_, __) => const SizedBox.shrink(),
                              data: (parties) {
                                if (parties.isEmpty) {
                                  return Text(
                                    'No parties yet. Create one under Reports → Parties.',
                                    style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                                  );
                                }
                                final sorted = [...parties]
                                  ..sort((a, b) {
                                    int rank(FxPartyType t) => switch (t) {
                                          FxPartyType.agent => 0,
                                          FxPartyType.settlement => 1,
                                          FxPartyType.customer => 2,
                                        };
                                    final r = rank(a.partyType).compareTo(rank(b.partyType));
                                    if (r != 0) return r;
                                    return a.name.compareTo(b.name);
                                  });
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      key: ValueKey(_partyId),
                                      initialValue: _partyId,
                                      decoration: const InputDecoration(labelText: 'Party (recommended)'),
                                      items: [
                                        const DropdownMenuItem<String>(value: null, child: Text('—')),
                                        ...sorted.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.code} · ${p.name}'))),
                                      ],
                                      onChanged: _busy ? null : (v) => setState(() => _partyId = v),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Select a party to show this transaction on the party ledger.',
                                      style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_settlementAccountCode),
                          initialValue: _settlementAccountCode,
                          decoration: const InputDecoration(labelText: 'Settlement account'),
                          items: settlementAccounts
                              .map((a) => DropdownMenuItem(value: a.code, child: Text('${a.code} · ${a.name}')))
                              .toList(),
                          onChanged: _busy ? null : (v) => setState(() => _settlementAccountCode = v),
                          validator: (v) => v == null ? 'Select settlement account' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_fromAccountCode),
                          initialValue: _fromAccountCode,
                          decoration: InputDecoration(
                            labelText: type == FxTransactionType.settlementSend ? 'Pay from (cash)' : 'Receive to (cash)',
                          ),
                          items: cashAccounts
                              .map((a) => DropdownMenuItem(value: a.code, child: Text('${a.code} · ${a.name}')))
                              .toList(),
                          onChanged: _busy ? null : (v) => setState(() => _fromAccountCode = v),
                          validator: (v) => v == null ? 'Select cash account' : null,
                        ),
                      ],
                      if (type == FxTransactionType.dailyClosingAdjustment ||
                          type == FxTransactionType.revaluation) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_fromAccountCode),
                          initialValue: _fromAccountCode,
                          decoration: const InputDecoration(labelText: 'Cash account'),
                          items: cashAccounts
                              .map((a) => DropdownMenuItem(value: a.code, child: Text('${a.code} · ${a.name}')))
                              .toList(),
                          onChanged: _busy ? null : (v) => setState(() => _fromAccountCode = v),
                          validator: (v) => v == null ? 'Select cash account' : null,
                        ),
                      ],
                      if (type == FxTransactionType.expense) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_expenseAccountCode),
                          initialValue: _expenseAccountCode,
                          decoration: const InputDecoration(labelText: 'Expense account'),
                          items: expenseAccounts.map((a) => DropdownMenuItem(value: a.code, child: Text('${a.code} · ${a.name}'))).toList(),
                          onChanged: _busy ? null : (v) => setState(() => _expenseAccountCode = v),
                          validator: (v) => v == null ? 'Select expense account' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_fromAccountCode),
                          initialValue: _fromAccountCode,
                          decoration: const InputDecoration(labelText: 'Pay from (cash)'),
                          items: cashAccounts.map((a) => DropdownMenuItem(value: a.code, child: Text('${a.code} · ${a.name}'))).toList(),
                          onChanged: _busy ? null : (v) => setState(() => _fromAccountCode = v),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FxObsidianFormField(
                        label: 'Description',
                        controller: _descriptionCtrl,
                        maxLines: 2,
                        enabled: !_busy,
                      ),
                      const SizedBox(height: 16),
                      _attachmentsSection(profile),
                      const SizedBox(height: 12),
                      Text(
                        'PKR equivalent: ${_baseAmountPkr.toStringAsFixed(2)}',
                        style: AppTypography.headlineMd(context.fx.onSurface, context: context).copyWith(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          FxObsidianActionBar(
            busy: _busy,
            saveLabel: widget.editDraftId != null || _draftId != null ? 'Save Changes' : 'Save draft',
            onCancel: () => context.pop(),
            onSave: () => _saveDraft(profile, accounts),
          ),
          if (_draftId != null && widget.editDraftId == null)
            Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.marginMobile, 0, AppSpacing.marginMobile, MediaQuery.paddingOf(context).bottom + 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: _busy ? null : _postDraft,
                  child: const Text('Post to ledger'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _applyDraft(FxTransaction tx) {
    _loadedEdit = true;
    _editType = tx.transactionType;
    _draftId = tx.id;
    _currencyCode = tx.currencyCode;
    _foreignAmountCtrl.text = tx.totalForeignAmount.toString();
    _rateCtrl.text = tx.rateUsed.toString();
    _descriptionCtrl.text = tx.description ?? '';
    _transactionDate = tx.transactionDate;
    _rateInitialized = true;
    _partyId = tx.partyId;

    final creditLine = tx.lines.where((l) => l.creditPkr > 0).toList();
    final debitLine = tx.lines.where((l) => l.debitPkr > 0).toList();

    switch (tx.transactionType) {
      case FxTransactionType.accountTransfer:
        _fromAccountCode = creditLine.firstOrNull?.accountCode;
        _toAccountCode = debitLine.firstOrNull?.accountCode;
      case FxTransactionType.expense:
        _fromAccountCode = creditLine.firstOrNull?.accountCode;
        _expenseAccountCode = debitLine.firstOrNull?.accountCode;
      case FxTransactionType.openingBalance:
        _fromAccountCode = debitLine.firstOrNull?.accountCode;
      case FxTransactionType.settlementSend:
        _settlementAccountCode = debitLine.firstOrNull?.accountCode;
        _fromAccountCode = creditLine.firstOrNull?.accountCode;
      case FxTransactionType.settlementReceive:
        _settlementAccountCode = creditLine.firstOrNull?.accountCode;
        _fromAccountCode = debitLine.firstOrNull?.accountCode;
      case FxTransactionType.dailyClosingAdjustment:
      case FxTransactionType.revaluation:
        _fromAccountCode = debitLine.firstOrNull?.accountCode ?? creditLine.firstOrNull?.accountCode;
      case FxTransactionType.crossCurrency:
        final toLine = debitLine.where((l) => l.accountCode != null && l.accountCode!.startsWith('11')).firstOrNull;
        if (toLine != null) {
          _toCurrencyCode = toLine.currencyCode;
          _toForeignAmountCtrl.text = toLine.foreignAmount.toString();
          _toRateCtrl.text = toLine.rateUsed.toString();
        }
      default:
        break;
    }
  }

  Future<void> _savePostedEdit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_reasonCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final accounts = await ref.read(accountsProvider.future);
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw StateError('Profile not configured');

      final type = _editType!;
      final revaluationDelta = type == FxTransactionType.revaluation ? _foreignAmount : null;
      final foreignAmount = type == FxTransactionType.revaluation ||
              type == FxTransactionType.dailyClosingAdjustment
          ? _foreignAmount.abs()
          : _foreignAmount;
      final basePkr = type == FxTransactionType.revaluation ||
              type == FxTransactionType.dailyClosingAdjustment
          ? _foreignAmount
          : _baseAmountPkr;

      final originalTx = await repo.fetchTransactionWithLines(widget.editDraftId!);
      final amountsChanged = originalTx.totalForeignAmount != foreignAmount ||
          originalTx.rateUsed != _rateUsed ||
          originalTx.currencyCode != _currencyCode;

      if (amountsChanged) {
        await repo.repostTransaction(
          transactionId: widget.editDraftId!,
          reason: _reasonCtrl.text.trim(),
          type: type,
          currencyCode: _currencyCode!,
          foreignAmount: foreignAmount,
          rateUsed: _rateUsed,
          baseAmountPkr: basePkr,
          accounts: accounts,
          description: _descriptionCtrl.text.trim(),
          fromAccountCode: _fromAccountCode,
          toAccountCode: _toAccountCode,
          expenseAccountCode: _expenseAccountCode,
          partyId: _partyId,
          settlementAccountCode: _settlementAccountCode,
          toCurrencyCode: _toCurrencyCode,
          toForeignAmount: type == FxTransactionType.crossCurrency ? _toForeignAmount : null,
          toRateUsed: type == FxTransactionType.crossCurrency ? _toRateUsed : null,
          revaluationDeltaPkr: revaluationDelta,
        );
      } else {
        await repo.editTransaction(
          transactionId: widget.editDraftId!,
          reason: _reasonCtrl.text.trim(),
          transactionDate: _transactionDate,
          description: _descriptionCtrl.text.trim(),
        );
      }
      ref.invalidate(transactionDetailProvider(widget.editDraftId!));
      ref.invalidate(auditLogsProvider);
      ref.invalidate(auditLogsForEntityProvider(widget.editDraftId!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction updated.')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDraft(FxUserProfile profile, List<FxAccount> accounts) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_ensureTransactionDate(context)) return;
    setState(() => _busy = true);
    try {
      final type = _editType ?? widget.type;
      final repo = ref.read(transactionRepositoryProvider);
      final wasUpdate = _draftId != null;
      final revaluationDelta = type == FxTransactionType.revaluation ? _foreignAmount : null;
      final foreignAmount = type == FxTransactionType.revaluation ||
              type == FxTransactionType.dailyClosingAdjustment
          ? _foreignAmount.abs()
          : _foreignAmount;
      final basePkr = type == FxTransactionType.revaluation ||
              type == FxTransactionType.dailyClosingAdjustment
          ? _foreignAmount
          : _baseAmountPkr;
      final description = _descriptionCtrl.text.isEmpty ? null : _descriptionCtrl.text;
      final FxTransaction tx;
      if (_draftId != null) {
        tx = await repo.updateDraft(
          transactionId: _draftId!,
          type: type,
          currencyCode: _currencyCode!,
          foreignAmount: foreignAmount,
          rateUsed: _rateUsed,
          baseAmountPkr: basePkr,
          accounts: accounts,
          description: description,
          transactionDate: _transactionDate,
          fromAccountCode: _fromAccountCode,
          toAccountCode: _toAccountCode,
          expenseAccountCode: _expenseAccountCode,
          partyId: _partyId,
          settlementAccountCode: _settlementAccountCode,
          toCurrencyCode: _toCurrencyCode,
          toForeignAmount: type == FxTransactionType.crossCurrency ? _toForeignAmount : null,
          toRateUsed: type == FxTransactionType.crossCurrency ? _toRateUsed : null,
          revaluationDeltaPkr: revaluationDelta,
        );
      } else {
        tx = await repo.createDraft(
          companyId: profile.companyId,
          branchId: profile.branchId,
          type: type,
          currencyCode: _currencyCode!,
          foreignAmount: foreignAmount,
          rateUsed: _rateUsed,
          baseAmountPkr: basePkr,
          accounts: accounts,
          description: description,
          transactionDate: _transactionDate,
          fromAccountCode: _fromAccountCode,
          toAccountCode: _toAccountCode,
          expenseAccountCode: _expenseAccountCode,
          partyId: _partyId,
          settlementAccountCode: _settlementAccountCode,
          toCurrencyCode: _toCurrencyCode,
          toForeignAmount: type == FxTransactionType.crossCurrency ? _toForeignAmount : null,
          toRateUsed: type == FxTransactionType.crossCurrency ? _toRateUsed : null,
          revaluationDeltaPkr: revaluationDelta,
        );
      }
      setState(() => _draftId = tx.id);
      ref.invalidate(draftTransactionsProvider);
      if (widget.editDraftId != null) {
        ref.invalidate(transactionDetailProvider(widget.editDraftId!));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(wasUpdate ? 'Draft updated.' : 'Draft saved.')),
        );
        if (widget.editDraftId != null) context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _postDraft() async {
    if (!_ensureTransactionDate(context)) return;
    setState(() => _busy = true);
    try {
      await ref.read(transactionRepositoryProvider).postTransaction(_draftId!);
      ref.invalidate(draftTransactionsProvider);
      ref.invalidate(todayTransactionsProvider);
      ref.invalidate(cashBalancesProvider);
      if (mounted) {
        context.pushReplacement('/transactions/$_draftId/complete');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
