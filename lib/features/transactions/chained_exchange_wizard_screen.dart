import 'dart:math';

import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_shell.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/core/widgets/rates/fx_rate_valuation_section.dart';
import 'package:accounts_manager/domain/models/fx_currency.dart';
import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/domain/services/rate_suggestion_service.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

String _newExchangeGroupId() {
  final r = Random();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
      '${hex(bytes[4])}${hex(bytes[5])}-'
      '${hex(bytes[6])}${hex(bytes[7])}-'
      '${hex(bytes[8])}${hex(bytes[9])}-'
      '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
}

class ChainedExchangeWizardScreen extends ConsumerStatefulWidget {
  const ChainedExchangeWizardScreen({super.key});

  @override
  ConsumerState<ChainedExchangeWizardScreen> createState() => _ChainedExchangeWizardScreenState();
}

class _ChainedExchangeWizardScreenState extends ConsumerState<ChainedExchangeWizardScreen> {
  int _step = 0;
  bool _busy = false;

  final _pkrAmountCtrl = TextEditingController();
  final _buyRateCtrl = TextEditingController(text: '280');
  final _usdAmountCtrl = TextEditingController();
  final _crossRateCtrl = TextEditingController(text: '3.67');
  final _aedAmountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String? _intermediateCurrency;
  String? _toCurrency;
  DateTime? _transactionDate;

  String? _buyDraftId;
  String? _crossDraftId;
  String? _groupId;

  bool _ratesPrefilled = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _transactionDate = DateTime(now.year, now.month, now.day);
    _pkrAmountCtrl.addListener(_recalcUsd);
    _buyRateCtrl.addListener(_recalcUsd);
    _usdAmountCtrl.addListener(_recalcAed);
    _crossRateCtrl.addListener(_recalcAed);
  }

  void _prefillRates(List<FxRate> rates) {
    if (_ratesPrefilled || rates.isEmpty) return;
    const svc = RateSuggestionService();
    final usd = _intermediateCurrency ?? 'USD';
    final to = _toCurrency ?? 'AED';
    final buyQuote = svc.pkrQuote(rates, usd, side: RateSide.buy);
    if (buyQuote.isAvailable && _buyRateCtrl.text == '280') {
      _buyRateCtrl.text = buyQuote.rate.toStringAsFixed(4);
    }
    final crossQuote = svc.resolvePair(rates, usd, to);
    if (crossQuote.isAvailable && _crossRateCtrl.text == '3.67') {
      _crossRateCtrl.text = crossQuote.rate.toStringAsFixed(4);
    }
    _ratesPrefilled = true;
    _recalcUsd();
    _recalcAed();
  }

  @override
  void dispose() {
    _pkrAmountCtrl.dispose();
    _buyRateCtrl.dispose();
    _usdAmountCtrl.dispose();
    _crossRateCtrl.dispose();
    _aedAmountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _recalcUsd() {
    final pkr = double.tryParse(_pkrAmountCtrl.text) ?? 0;
    final rate = double.tryParse(_buyRateCtrl.text) ?? 0;
    if (rate > 0) {
      _usdAmountCtrl.text = (pkr / rate).toStringAsFixed(4);
    }
    setState(() {});
  }

  void _recalcAed() {
    final usd = double.tryParse(_usdAmountCtrl.text) ?? 0;
    final rate = double.tryParse(_crossRateCtrl.text) ?? 0;
    if (rate > 0) {
      _aedAmountCtrl.text = (usd * rate).toStringAsFixed(4);
    }
    setState(() {});
  }

  double get _pkrAmount => double.tryParse(_pkrAmountCtrl.text) ?? 0;
  double get _buyRate => double.tryParse(_buyRateCtrl.text) ?? 0;
  double get _usdAmount => double.tryParse(_usdAmountCtrl.text) ?? 0;
  double get _aedAmount => double.tryParse(_aedAmountCtrl.text) ?? 0;

  Future<void> _saveDrafts() async {
    if (_transactionDate == null) return;
    if (_intermediateCurrency == null || _toCurrency == null) return;
    if (_pkrAmount <= 0 || _buyRate <= 0 || _usdAmount <= 0 || _aedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid amounts and rates.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final profile = await ref.read(currentProfileProvider.future);
      final accounts = await ref.read(accountsProvider.future);
      if (profile == null) throw StateError('Profile not configured');

      final repo = ref.read(transactionRepositoryProvider);
      _groupId ??= _newExchangeGroupId();
      final description = _descriptionCtrl.text.trim().isEmpty
          ? 'Chained exchange PKR → $_intermediateCurrency → $_toCurrency'
          : _descriptionCtrl.text.trim();

      final buyTx = await repo.createDraft(
        companyId: profile.companyId,
        branchId: profile.branchId,
        type: FxTransactionType.currencyBuy,
        currencyCode: _intermediateCurrency!,
        foreignAmount: _usdAmount,
        rateUsed: _buyRate,
        baseAmountPkr: _pkrAmount,
        accounts: accounts,
        description: '$description (leg 1: buy)',
        transactionDate: _transactionDate,
        exchangeGroupId: _groupId,
      );

      final toRate = _pkrAmount / (_aedAmount == 0 ? 1 : _aedAmount);
      final crossTx = await repo.createDraft(
        companyId: profile.companyId,
        branchId: profile.branchId,
        type: FxTransactionType.crossCurrency,
        currencyCode: _intermediateCurrency!,
        foreignAmount: _usdAmount,
        rateUsed: _buyRate,
        baseAmountPkr: _pkrAmount,
        accounts: accounts,
        description: '$description (leg 2: cross)',
        transactionDate: _transactionDate,
        toCurrencyCode: _toCurrency,
        toForeignAmount: _aedAmount,
        toRateUsed: toRate > 0 ? toRate : 75,
        exchangeGroupId: _groupId,
      );

      setState(() {
        _buyDraftId = buyTx.id;
        _crossDraftId = crossTx.id;
        _step = 2;
      });
      ref.invalidate(draftTransactionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Both drafts saved. Post each to ledger.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _postBoth() async {
    if (_buyDraftId == null || _crossDraftId == null) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.postTransaction(_buyDraftId!);
      await repo.postTransaction(_crossDraftId!);
      ref.invalidate(draftTransactionsProvider);
      ref.invalidate(todayTransactionsProvider);
      ref.invalidate(cashBalancesProvider);
      if (mounted) {
        context.pushReplacement('/transactions/$_crossDraftId/complete');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currenciesAsync = ref.watch(currenciesProvider);
    final ratesAsync = ref.watch(ratesProvider);

    ratesAsync.whenData((rates) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prefillRates(rates);
      });
    });

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        title: const Text('Chained Exchange'),
        backgroundColor: context.fx.background,
      ),
      body: currenciesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (currencies) {
          final foreign = currencies.where((c) => !c.isBase).toList();
          _intermediateCurrency ??= foreign.where((c) => c.code == 'USD').firstOrNull?.code ?? foreign.firstOrNull?.code;
          _toCurrency ??= foreign.where((c) => c.code == 'AED').firstOrNull?.code ??
              foreign.where((c) => c.code != _intermediateCurrency).firstOrNull?.code;

          return FxObsidianPage(
            child: Column(
              children: [
                _StepIndicator(current: _step),
                Expanded(
                  child: ListView(
                    children: [
                      if (_step == 0) _buildStep1(foreign),
                      if (_step == 1) _buildStep2(foreign),
                      if (_step == 2) _buildReview(),
                    ],
                  ),
                ),
                _buildActions(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStep1(List<FxCurrency> foreign) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.fx.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FxSectionLabel(label: 'Step 1 — PKR → foreign (Buy)'),
          const SizedBox(height: 12),
          _dateField(),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _intermediateCurrency,
            decoration: const InputDecoration(labelText: 'Buy currency'),
            items: foreign.map((c) => DropdownMenuItem(value: c.code, child: Text(c.code))).toList(),
            onChanged: _busy ? null : (v) => setState(() => _intermediateCurrency = v),
          ),
          const SizedBox(height: 12),
          FxObsidianFormField(
            label: 'PKR amount (pay)',
            controller: _pkrAmountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: !_busy,
          ),
          if (_intermediateCurrency != null) ...[
            const SizedBox(height: 8),
            FxRateValuationSection(
              fromCurrency: _intermediateCurrency!,
              toCurrency: 'PKR',
              dealRateController: _buyRateCtrl,
              receiveAmount: _usdAmount > 0 ? _usdAmount : null,
              rateSide: RateSide.buy,
              asOfDate: _transactionDate,
              dealRateLabel: 'Buy rate (PKR per unit)',
              showPkrEquivalent: false,
            ),
          ] else
            FxObsidianFormField(
              label: 'Buy rate (PKR per unit)',
              controller: _buyRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_busy,
            ),
          const SizedBox(height: 12),
          FxObsidianFormField(
            label: 'Foreign amount (receive)',
            controller: _usdAmountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: !_busy,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(List<FxCurrency> foreign) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.fx.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FxSectionLabel(label: 'Step 2 — Cross to destination'),
          const SizedBox(height: 12),
          Text(
            'Exchange $_intermediateCurrency received in step 1.',
            style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _toCurrency,
            decoration: const InputDecoration(labelText: 'To currency'),
            items: foreign
                .where((c) => c.code != _intermediateCurrency)
                .map((c) => DropdownMenuItem(value: c.code, child: Text(c.code)))
                .toList(),
            onChanged: _busy ? null : (v) => setState(() => _toCurrency = v),
          ),
          const SizedBox(height: 12),
          FxObsidianFormField(
            label: 'From amount ($_intermediateCurrency)',
            controller: _usdAmountCtrl,
            enabled: false,
          ),
          const SizedBox(height: 12),
          if (_intermediateCurrency != null && _toCurrency != null) ...[
            FxRateValuationSection(
              fromCurrency: _intermediateCurrency!,
              toCurrency: _toCurrency!,
              dealRateController: _crossRateCtrl,
              receiveAmount: _usdAmount,
              payAmountController: _aedAmountCtrl,
              rateSide: RateSide.reference,
              asOfDate: _transactionDate,
              dealRateLabel: 'Cross rate (${_intermediateCurrency!} per ${_toCurrency!} unit)',
            ),
          ] else
            FxObsidianFormField(
              label: 'Cross rate',
              controller: _crossRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_busy,
            ),
          const SizedBox(height: 12),
          FxObsidianFormField(
            label: 'To amount ($_toCurrency)',
            controller: _aedAmountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: !_busy,
          ),
          const SizedBox(height: 12),
          FxObsidianFormField(
            label: 'Description (optional)',
            controller: _descriptionCtrl,
            maxLines: 2,
            enabled: !_busy,
          ),
        ],
      ),
    );
  }

  Widget _buildReview() {
    final fmt = NumberFormat('#,##0.00');
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.fx.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(color: context.fx.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FxSectionLabel(label: 'Review linked drafts'),
              const SizedBox(height: 12),
              _ReviewCard(
                title: 'Leg 1 — Currency Buy',
                subtitle: '${fmt.format(_usdAmount)} $_intermediateCurrency for PKR ${fmt.format(_pkrAmount)}',
                draftId: _buyDraftId,
                onTap: _buyDraftId != null ? () => context.push('/transactions/$_buyDraftId') : null,
              ),
              const SizedBox(height: 12),
              _ReviewCard(
                title: 'Leg 2 — Cross Currency',
                subtitle: '${fmt.format(_usdAmount)} $_intermediateCurrency → ${fmt.format(_aedAmount)} $_toCurrency',
                draftId: _crossDraftId,
                onTap: _crossDraftId != null ? () => context.push('/transactions/$_crossDraftId') : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dateField() {
    final label = _transactionDate != null
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
                const FxSectionLabel(label: 'Transaction date'),
                Text(label, style: AppTypography.bodyMd(context.fx.onSurface, context: context)),
              ],
            ),
          ),
          Icon(Icons.calendar_today_outlined, color: context.fx.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: context.fx.surface,
        border: Border(top: BorderSide(color: context.fx.outlineVariant)),
      ),
      child: Row(
        children: [
          if (_step > 0 && _step < 2)
            TextButton(
              onPressed: _busy ? null : () => setState(() => _step--),
              child: const Text('Back'),
            ),
          const Spacer(),
          if (_step < 2)
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (_step == 0) {
                        if (_pkrAmount <= 0 || _buyRate <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Enter PKR amount and buy rate.')),
                          );
                          return;
                        }
                        setState(() => _step = 1);
                      } else {
                        _saveDrafts();
                      }
                    },
              child: Text(_step == 0 ? 'Next' : (_busy ? 'Saving…' : 'Save drafts')),
            ),
          if (_step == 2) ...[
            OutlinedButton(
              onPressed: _busy ? null : () => context.pop(),
              child: const Text('Done'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy ? null : _postBoth,
              child: const Text('Post both'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) Expanded(child: Container(height: 2, color: i <= current ? context.fx.primary : context.fx.outlineVariant)),
            CircleAvatar(
              radius: 14,
              backgroundColor: i <= current ? context.fx.primary : context.fx.surfaceContainerHighest,
              child: Text(
                '${i + 1}',
                style: AppTypography.bodyMd(
                  i <= current ? context.fx.onPrimary : context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 12),
              ),
            ),
            if (i < 2) Expanded(child: Container(height: 2, color: i < current ? context.fx.primary : context.fx.outlineVariant)),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.subtitle,
    this.draftId,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String? draftId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.fx.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600)),
                    Text(subtitle, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
                  ],
                ),
              ),
              if (draftId != null)
                Icon(Icons.link, color: context.fx.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
