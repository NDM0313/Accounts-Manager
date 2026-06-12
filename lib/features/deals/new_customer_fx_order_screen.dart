import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_deal_form_widgets.dart';
import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_currency.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
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
  final _searchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _paidCtrl = TextEditingController(text: '0');

  String? _customerId;
  String? _currencyCode;
  DateTime? _bookingDate;
  int _deliveryIndex = 1;
  bool _busy = false;
  double? _referenceRate;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountCtrl.text.replaceAll(',', ''));
  double? get _rate => double.tryParse(_rateCtrl.text.replaceAll(',', ''));
  double? get _paid => double.tryParse(_paidCtrl.text.replaceAll(',', ''));
  double get _payable => (_amount ?? 0) * (_rate ?? 0);

  FxDeliveryMethod get _deliveryMethod => switch (_deliveryIndex) {
        0 => FxDeliveryMethod.ownBalance,
        1 => FxDeliveryMethod.agent,
        _ => FxDeliveryMethod.later,
      };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    _bookingDate ??= DateTime(now.year, now.month, now.day);
    final customerChoicesAsync = ref.watch(customerOrderPartyChoicesProvider);
    final currenciesAsync = ref.watch(currenciesProvider);
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: const Text('New Customer Deal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Text(
              'Customer',
              style: AppTypography.headlineSm(
                context.fx.primary,
                context: context,
              ),
            ),
            const SizedBox(height: 8),
            customerChoicesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (choices) {
                if (choices.parties.isEmpty) {
                  return OutlinedButton.icon(
                    onPressed: _busy ? null : () => context.push('/parties/new'),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Add customer'),
                  );
                }
                return DropdownButtonFormField<String>(
                  initialValue: _customerId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'Search or select customer…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: context.fx.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                  ),
                  hint: const Text('Select customer'),
                  items: choices.parties
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.code} · ${p.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: _busy ? null : (v) => setState(() => _customerId = v),
                  validator: (v) => v == null ? 'Select customer' : null,
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Currency & Amount',
              style: AppTypography.headlineSm(
                context.fx.primary,
                context: context,
              ),
            ),
            const SizedBox(height: 8),
            currenciesAsync.when(
              loading: () => const SizedBox.shrink(),
              data: (List<FxCurrency> currencies) {
                final active = currencies.where((c) => !c.isBase).toList();
                if (_currencyCode == null && active.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _currencyCode == null) {
                      setState(() => _currencyCode = active.first.code);
                      _loadReferenceRate();
                    }
                  });
                }
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _currencyCode,
                        decoration: InputDecoration(
                          labelText: 'Currency pair',
                          filled: true,
                          fillColor: context.fx.surfaceContainerLowest,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusLg),
                          ),
                        ),
                        items: active
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.code,
                                child: Text(
                                  '${displayCurrencyCode(c.code)} / PKR',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _currencyCode = v != null
                                ? normalizeFxCurrencyCode(v)
                                : null;
                          });
                          _loadReferenceRate();
                        },
                        validator: (v) => v == null ? 'Select currency' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: _busy ? null : () => _pickDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Booking date',
                            filled: true,
                            fillColor: context.fx.surfaceContainerLowest,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusLg),
                            ),
                          ),
                          child: Text(
                            _bookingDate != null
                                ? DateFormat.yMMMd().format(_bookingDate!)
                                : 'Today',
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTypography.headlineMd(
                context.fx.onSurface,
                context: context,
              ).copyWith(fontSize: 32),
              decoration: InputDecoration(
                hintText: '0.00',
                filled: true,
                fillColor: context.fx.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => (_amount ?? 0) <= 0 ? 'Enter amount' : null,
            ),
            const SizedBox(height: 16),
            if (_currencyCode != null) ...[
              FxStitchExchangeRatesCard(
                referenceRate: _referenceRate != null
                    ? fmt.format(_referenceRate)
                    : '—',
                dealRate: _rateCtrl.text.isNotEmpty ? _rateCtrl.text : '—',
                spreadLabel: _spreadLabel(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _rateCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Deal rate (PKR per unit)',
                  filled: true,
                  fillColor: context.fx.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) => (_rate ?? 0) <= 0 ? 'Enter rate' : null,
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Delivery Method',
              style: AppTypography.headlineSm(
                context.fx.primary,
                context: context,
              ),
            ),
            const SizedBox(height: 8),
            FxStitchDeliverySegments(
              labels: const ['Own Balance', 'Agent Source', 'TT Later'],
              selectedIndex: _deliveryIndex,
              onChanged: (i) => setState(() => _deliveryIndex = i),
            ),
            const SizedBox(height: 20),
            FxStitchTotalPayableCard(
              amountLabel: 'PKR ${fmt.format(_payable)}',
            ),
            const SizedBox(height: 12),
            FxStitchWhatHappensNextCard(
              bullets: const [
                'Customer receivable is posted to their ledger.',
                'Currency position is reserved or sourcing is created.',
                'Deal workflow opens for agent source and delivery steps.',
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _paidCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Customer paid now (PKR)',
                filled: true,
                fillColor: context.fx.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: context.fx.surfaceContainerLowest,
          border: Border(top: BorderSide(color: context.fx.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: context.fx.primaryContainer,
              foregroundColor: context.fx.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Deal'),
          ),
        ),
      ),
    );
  }

  String? _spreadLabel() {
    if (_referenceRate == null || _rate == null || _referenceRate == 0) {
      return null;
    }
    final spread = ((_rate! - _referenceRate!) / _referenceRate! * 100);
    return 'SPREAD ${spread >= 0 ? '+' : ''}${spread.toStringAsFixed(2)}%';
  }

  Future<void> _loadReferenceRate() async {
    if (_currencyCode == null) return;
    try {
      final asOf = _bookingDate ?? DateTime.now();
      final rates = await ref.read(rateRepositoryProvider).fetchRatesAsOf(asOf);
      final svc = ref.read(rateSuggestionServiceProvider);
      final quote = svc.pkrQuote(rates, _currencyCode!, side: RateSide.sell);
      if (mounted) {
        setState(() {
          _referenceRate = quote.referenceRate;
          if (_rateCtrl.text.isEmpty && quote.rate > 0) {
            _rateCtrl.text = quote.rate.toStringAsFixed(4);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _bookingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _bookingDate = picked);
      _loadReferenceRate();
    }
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
      final dealId = await ref.read(dealRepositoryProvider).bookCustomerDeal(
            branchId: profile.branchId,
            customerPartyId: _customerId!,
            sellCurrencyCode: _currencyCode!,
            sellAmount: _amount!,
            saleRatePkr: _rate!,
            customerPaidNowPkr: _paid ?? 0,
            deliveryMethod: _deliveryMethod,
            autoSource: true,
            rateSnapshot: rateSnapshot,
          );
      ref.read(dealsRefreshProvider.notifier).refresh();
      if (mounted) context.go('/deals/$dealId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
