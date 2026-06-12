import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:accounts_manager/domain/models/fx_currency.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/core/widgets/rates/fx_rate_valuation_section.dart';
import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/domain/models/rate_reference_snapshot.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class NewCustomerFxOrderScreen extends ConsumerStatefulWidget {
  const NewCustomerFxOrderScreen({super.key});

  @override
  ConsumerState<NewCustomerFxOrderScreen> createState() =>
      _NewCustomerFxOrderScreenState();
}

class _NewCustomerFxOrderScreenState
    extends ConsumerState<NewCustomerFxOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _paidCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  String? _customerId;
  String? _currencyCode;
  DateTime? _bookingDate;
  FxDeliveryMethod _deliveryMethod = FxDeliveryMethod.agent;
  bool _busy = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountCtrl.text.replaceAll(',', ''));
  double? get _rate => double.tryParse(_rateCtrl.text.replaceAll(',', ''));
  double? get _paid => double.tryParse(_paidCtrl.text.replaceAll(',', ''));
  double get _payable => (_amount ?? 0) * (_rate ?? 0);
  double get _receivable => _payable - (_paid ?? 0);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    _bookingDate ??= DateTime(now.year, now.month, now.day);
    final customerChoicesAsync = ref.watch(customerOrderPartyChoicesProvider);
    final currenciesAsync = ref.watch(currenciesProvider);
    final positionAsync = ref.watch(currencyPositionProvider);
    final fmt = NumberFormat('#,##0.00');

    final selectedCurrency = _currencyCode;
    final positionRows = positionAsync.whenOrNull(data: (d) => d) ?? [];
    CurrencyPositionRow? positionRow;
    if (selectedCurrency != null) {
      final norm = normalizeFxCurrencyCode(selectedCurrency);
      for (final r in positionRows) {
        if (r.currencyCode == norm) {
          positionRow = r;
          break;
        }
      }
    }
    final available =
        positionRow?.availableBalance ?? positionRow?.foreignBalance;
    final required = positionRow?.requiredBalance;
    final insufficient =
        _amount != null && available != null && _amount! > available;

    return FxPageScaffold(
      fallbackRoute: '/deals',
      title: const Text('New Customer FX Order'),
      bottomBar: FxObsidianActionBar(
        onCancel: () => fxSafePop(context, fallbackRoute: '/deals'),
        onSave: _busy ? null : _submit,
        saveLabel: 'Book Order',
        busy: _busy,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FxSectionLabel(label: 'Customer'),
            customerChoicesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (choices) {
                if (choices.parties.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'No parties yet. Add a customer to book FX orders.',
                        style: AppTypography.bodyMd(
                          context.fx.onSurfaceVariant,
                          context: context,
                        ).copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => context.push('/parties/new'),
                        icon: const Icon(Icons.person_add_outlined, size: 18),
                        label: const Text('Add customer'),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (choices.isFallback)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'No Customer-type parties found. Showing all parties — add a Customer party for cleaner reporting.',
                          style: AppTypography.bodyMd(
                            context.fx.onSurfaceVariant,
                            context: context,
                          ).copyWith(fontSize: 12),
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      initialValue: _customerId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Select customer'),
                      items: choices.parties
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                choices.isFallback
                                    ? '${p.code} · ${p.name} · ${p.partyType.label}'
                                    : '${p.code} · ${p.name}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _customerId = v),
                      validator: (v) => v == null ? 'Select customer' : null,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const FxSectionLabel(label: 'Currency & amount'),
            currenciesAsync.when(
              loading: () => const SizedBox.shrink(),
              data: (List<FxCurrency> currencies) {
                final active = currencies.where((c) => !c.isBase).toList();
                if (_currencyCode == null && active.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _currencyCode == null) {
                      setState(() => _currencyCode = active.first.code);
                    }
                  });
                }
                return DropdownButtonFormField<String>(
                  initialValue: _currencyCode,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Currency customer wants',
                  ),
                  items: active
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c.code,
                          child: Text(displayCurrencyCode(c.code)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(
                    () => _currencyCode = v != null
                        ? normalizeFxCurrencyCode(v)
                        : null,
                  ),
                  validator: (v) => v == null ? 'Select currency' : null,
                );
              },
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _busy
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _bookingDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _bookingDate = picked);
                    },
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking date',
                          style: AppTypography.labelCaps(
                            context.fx.outline,
                            context: context,
                          ),
                        ),
                        Text(
                          _bookingDate != null
                              ? DateFormat.yMMMd().format(_bookingDate!)
                              : 'Today',
                          style: AppTypography.bodyMd(
                            context.fx.onSurface,
                            context: context,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.calendar_today_outlined,
                    color: context.fx.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FxObsidianFormField(
              controller: _amountCtrl,
              label: 'Amount',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => (_amount ?? 0) <= 0 ? 'Enter amount' : null,
            ),
            if (_currencyCode != null) ...[
              const SizedBox(height: 8),
              FxRateValuationSection(
                key: ValueKey('rate_${_currencyCode}_PKR'),
                fromCurrency: _currencyCode!,
                toCurrency: 'PKR',
                dealRateController: _rateCtrl,
                receiveAmount: _amount,
                rateSide: RateSide.sell,
                asOfDate: _bookingDate,
                dealRateLabel: 'Sale rate (PKR per unit)',
                showPkrEquivalent: false,
                validator: (v) => (_rate ?? 0) <= 0 ? 'Enter rate' : null,
                onDealRateChanged: (_) => setState(() {}),
              ),
            ] else
              FxObsidianFormField(
                controller: _rateCtrl,
                label: 'Sale rate (PKR)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) => (_rate ?? 0) <= 0 ? 'Enter rate' : null,
              ),
            if (selectedCurrency != null && available != null) ...[
              const SizedBox(height: 8),
              FxObsidianReportPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${displayCurrencyCode(selectedCurrency)} position',
                      style: AppTypography.labelCaps(
                        context.fx.outline,
                        context: context,
                      ),
                    ),
                    Text(
                      'Available: ${fmt.format(available)}',
                      style: AppTypography.bodyMd(
                        context.fx.onSurface,
                        context: context,
                      ),
                    ),
                    if (required != null && required > 0)
                      Text(
                        'Required / to source: ${fmt.format(required)}',
                        style: AppTypography.dataMd(
                          context.fx.warning,
                          context: context,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (insufficient) ...[
              const SizedBox(height: 8),
              FxObsidianReportPanel(
                color: context.fx.warningContainer,
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: context.fx.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Insufficient ${displayCurrencyCode(selectedCurrency!)} available. A sourcing requirement will be created automatically.',
                        style: AppTypography.bodyMd(
                          context.fx.warning,
                          context: context,
                        ).copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const FxSectionLabel(label: 'Customer payment'),
            FxObsidianFormField(
              controller: _paidCtrl,
              label: 'Customer paid now (PKR)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            FxObsidianReportPanel(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _amountRow(
                    context,
                    'Total payable',
                    'PKR ${fmt.format(_payable)}',
                    emphasized: true,
                  ),
                  const SizedBox(height: 8),
                  _amountRow(
                    context,
                    'Customer paid now',
                    'PKR ${fmt.format(_paid ?? 0)}',
                  ),
                  const Divider(height: 16),
                  _amountRow(
                    context,
                    'Outstanding receivable',
                    'PKR ${fmt.format(_receivable.clamp(0, double.infinity))}',
                    emphasized: true,
                    accent: context.fx.secondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const FxSectionLabel(label: 'Delivery method'),
            DropdownButtonFormField<FxDeliveryMethod>(
              initialValue: _deliveryMethod,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: FxDeliveryMethod.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _deliveryMethod = v ?? FxDeliveryMethod.agent),
            ),
            const SizedBox(height: 8),
            FxObsidianFormField(
              controller: _notesCtrl,
              label: 'Notes',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasized = false,
    Color? accent,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyMd(
              context.fx.onSurfaceVariant,
              context: context,
            ).copyWith(fontSize: 12),
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.end,
          style: emphasized
              ? AppTypography.dataLg(
                  accent ?? context.fx.onSurface,
                  context: context,
                )
              : AppTypography.dataMd(context.fx.onSurface, context: context),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) return;
    setState(() => _busy = true);
    try {
      final asOf = _bookingDate ?? DateTime.now();
      final rates = await ref.read(rateRepositoryProvider).fetchRatesAsOf(asOf);
      final svc = ref.read(rateSuggestionServiceProvider);
      final rateSnapshot = RateReferenceSnapshot.capture(
        svc: svc,
        rates: rates,
        fromCurrency: _currencyCode!,
        toCurrency: 'PKR',
        dealRate: _rate,
        side: RateSide.sell,
        lockedBy: supabase.auth.currentUser?.id,
      );
      final dealId = await ref
          .read(dealRepositoryProvider)
          .bookCustomerDeal(
            branchId: profile.branchId,
            customerPartyId: _customerId!,
            sellCurrencyCode: _currencyCode!,
            sellAmount: _amount!,
            saleRatePkr: _rate!,
            customerPaidNowPkr: _paid ?? 0,
            deliveryMethod: _deliveryMethod,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            autoSource: true,
            rateSnapshot: rateSnapshot,
          );
      ref.read(dealsRefreshProvider.notifier).refresh();
      if (mounted) context.go('/deals/$dealId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
