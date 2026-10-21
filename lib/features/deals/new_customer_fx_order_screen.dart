import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/utils/client_operation_id.dart';
import 'package:accounts_manager/core/utils/deal_posting_errors.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_deal_form_widgets.dart';
import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_currency.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/domain/models/rate_reference_snapshot.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum _PaymentMode { later, now }

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
  final _paidCtrl = TextEditingController();
  final _payNotesCtrl = TextEditingController();

  String? _customerId;
  String? _currencyCode;
  String? _cashAccountId;
  DateTime? _bookingDate;
  DateTime? _expectedPayDate;
  int _deliveryIndex = 1;
  _PaymentMode _paymentMode = _PaymentMode.later;
  bool _busy = false;
  double? _referenceRate;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _paidCtrl.dispose();
    _payNotesCtrl.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountCtrl.text.replaceAll(',', ''));
  double? get _rate => double.tryParse(_rateCtrl.text.replaceAll(',', ''));
  double? get _paid => double.tryParse(_paidCtrl.text.replaceAll(',', ''));
  double get _payable => (_amount ?? 0) * (_rate ?? 0);
  double get _receivedNow =>
      _paymentMode == _PaymentMode.now ? (_paid ?? 0) : 0;
  double get _remaining => (_payable - _receivedNow).clamp(0, double.infinity);

  FxDeliveryMethod get _deliveryMethod => switch (_deliveryIndex) {
        0 => FxDeliveryMethod.ownBalance,
        1 => FxDeliveryMethod.agent,
        _ => FxDeliveryMethod.later,
      };

  List<FxAccount> _pkrCashAccounts(List<FxAccount> all) {
    return all
        .where((a) {
          if (!a.isActive || a.accountType != 'asset') return false;
          if (a.code == '1110') return true;
          final isPkrNamed = a.name.toUpperCase().contains('PKR');
          final isPkrCur =
              a.currencyCode == null || a.currencyCode == 'PKR';
          return a.code.startsWith('11') && isPkrCur && isPkrNamed;
        })
        .toList();
  }

  void _setPaymentMode(_PaymentMode mode) {
    setState(() {
      _paymentMode = mode;
      if (mode == _PaymentMode.later) {
        _paidCtrl.clear();
        _cashAccountId = null;
        _payNotesCtrl.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    _bookingDate ??= DateTime(now.year, now.month, now.day);
    final customerChoicesAsync = ref.watch(customerOrderPartyChoicesProvider);
    final currenciesAsync = ref.watch(currenciesProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final fmt = NumberFormat('#,##0.00');
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: const Text('New Customer Deal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 100 + bottomInset),
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
                Future<void> addCustomer() async {
                  final id = await context.push<String>('/parties/new');
                  ref.invalidate(customerOrderPartyChoicesProvider);
                  ref.invalidate(partiesProvider(null));
                  if (id != null && mounted) {
                    setState(() => _customerId = id);
                  }
                }

                if (choices.parties.isEmpty) {
                  return OutlinedButton.icon(
                    onPressed: _busy ? null : addCustomer,
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Add customer'),
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _customerId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Search or select customer…',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: context.fx.surfaceContainerLowest,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusLg),
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
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _customerId = v),
                        validator: (v) => v == null ? 'Select customer' : null,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add customer',
                      onPressed: _busy ? null : addCustomer,
                      icon: const Icon(Icons.person_add_outlined),
                    ),
                  ],
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
                          labelText: 'Currency',
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
                        onTap: _busy ? null : () => _pickBookingDate(context),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppTypography.headlineMd(
                context.fx.onSurface,
                context: context,
              ).copyWith(fontSize: 28),
              decoration: InputDecoration(
                labelText: _currencyCode == null
                    ? 'Quantity'
                    : 'Quantity (${displayCurrencyCode(_currencyCode!)})',
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
              if (_referenceRate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Reference sell rate: ${fmt.format(_referenceRate)}'
                    '${_spreadLabel() != null ? ' · ${_spreadLabel()}' : ''}',
                    style: AppTypography.bodySm(
                      context.fx.onSurfaceVariant,
                      context: context,
                    ),
                  ),
                ),
              TextFormField(
                controller: _rateCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Deal rate (PKR per unit) — authoritative',
                  filled: true,
                  fillColor: context.fx.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    borderSide: BorderSide(
                      color: context.fx.secondary,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    borderSide: BorderSide(
                      color: context.fx.secondary,
                      width: 2,
                    ),
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
            if (_deliveryIndex == 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Agent Source creates a sourcing request only — it does not '
                  'mean currency was already bought or delivered.',
                  style: AppTypography.bodySm(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Customer payment',
              style: AppTypography.headlineSm(
                context.fx.primary,
                context: context,
              ),
            ),
            const SizedBox(height: 8),
            FxStitchDeliverySegments(
              labels: const [
                'Payment later',
                'Receive payment now',
              ],
              selectedIndex: _paymentMode == _PaymentMode.later ? 0 : 1,
              onChanged: (i) => _setPaymentMode(
                i == 0 ? _PaymentMode.later : _PaymentMode.now,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _paymentMode == _PaymentMode.later
                  ? 'Abhi payment nahi mili — deal will be booked with full outstanding.'
                  : 'Abhi payment mili hai — enter amount and receiving cash/bank.',
              style: AppTypography.bodySm(
                context.fx.onSurfaceVariant,
                context: context,
              ),
            ),
            if (_paymentMode == _PaymentMode.later) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: _busy ? null : () => _pickExpectedPayDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Expected payment date (optional)',
                    filled: true,
                    fillColor: context.fx.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                  ),
                  child: Text(
                    _expectedPayDate != null
                        ? DateFormat.yMMMd().format(_expectedPayDate!)
                        : 'Not set',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _payNotesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Payment notes (optional)',
                  filled: true,
                  fillColor: context.fx.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                ),
              ),
            ],
            if (_paymentMode == _PaymentMode.now) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _paidCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Received now (PKR)',
                  filled: true,
                  fillColor: context.fx.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (_paymentMode != _PaymentMode.now) return null;
                  final p = _paid ?? 0;
                  if (p <= 0) return 'Enter amount received';
                  if (p > _payable + 0.0000001) {
                    return 'Cannot exceed deal total';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Accounts: $e'),
                data: (accounts) {
                  final cash = _pkrCashAccounts(accounts);
                  if (cash.isEmpty) {
                    return Text(
                      'No PKR cash/bank account found. Add Cash PKR (1110) first.',
                      style: TextStyle(color: context.fx.error),
                    );
                  }
                  _cashAccountId ??= cash
                      .where((a) => a.code == '1110')
                      .map((a) => a.id)
                      .cast<String?>()
                      .firstWhere((_) => true, orElse: () => cash.first.id);
                  return DropdownButtonFormField<String>(
                    initialValue: _cashAccountId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Receiving cash/bank',
                      filled: true,
                      fillColor: context.fx.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusLg),
                      ),
                    ),
                    items: cash
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.code} · ${a.name}'),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _cashAccountId = v),
                    validator: (v) =>
                        v == null ? 'Select receiving account' : null,
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            FxStitchTotalPayableCard(
              amountLabel: 'PKR ${fmt.format(_payable)}',
              footer: 'Deal total (quantity × rate)',
            ),
            const SizedBox(height: 8),
            _MoneySummaryRow(
              label: 'Received now (PKR)',
              value: fmt.format(_receivedNow),
            ),
            _MoneySummaryRow(
              label: 'Remaining due (PKR)',
              value: fmt.format(_remaining),
              emphasize: true,
            ),
            const SizedBox(height: 12),
            FxStitchWhatHappensNextCard(
              bullets: [
                if (_paymentMode == _PaymentMode.later)
                  'Deal is confirmed with outstanding customer amount; no cash receipt is posted.'
                else
                  'Cash/bank is debited only for the amount received now.',
                'Payment status and delivery/sourcing stay separate.',
                if (_deliveryIndex == 1)
                  'Agent Source opens sourcing steps — not an automatic purchase or delivery.',
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset.clamp(0, 24)),
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
    return 'spread ${spread >= 0 ? '+' : ''}${spread.toStringAsFixed(2)}%';
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

  Future<void> _pickBookingDate(BuildContext context) async {
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

  Future<void> _pickExpectedPayDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedPayDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expectedPayDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paymentMode == _PaymentMode.now &&
        (_cashAccountId == null || _cashAccountId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a receiving cash/bank account.')),
      );
      return;
    }
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) return;
    setState(() => _busy = true);
    final paidNow =
        _paymentMode == _PaymentMode.now ? (_paid ?? 0) : 0.0;
    final opEntity =
        '${profile.branchId}:$_customerId:$_currencyCode:$_amount:$_rate:$paidNow';
    final opId = await ClientOperationId.begin('book_customer_deal', opEntity);
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
            customerPaidNowPkr: paidNow,
            deliveryMethod: _deliveryMethod,
            autoSource: true,
            rateSnapshot: rateSnapshot,
            cashAccountId:
                _paymentMode == _PaymentMode.now ? _cashAccountId : null,
            clientOperationId: opId,
            expectedPaymentDate: _paymentMode == _PaymentMode.later
                ? _expectedPayDate
                : null,
            paymentNotes: _paymentMode == _PaymentMode.now
                ? 'Initial payment on booking'
                : (_payNotesCtrl.text.trim().isEmpty
                    ? null
                    : _payNotesCtrl.text.trim()),
            notes: _paymentMode == _PaymentMode.later &&
                    _payNotesCtrl.text.trim().isNotEmpty
                ? _payNotesCtrl.text.trim()
                : null,
          );
      await ClientOperationId.complete('book_customer_deal', opEntity);
      ref.read(dealsRefreshProvider.notifier).refresh();
      if (mounted) context.go('/deals/$dealId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyDealPostingError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MoneySummaryRow extends StatelessWidget {
  const _MoneySummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMd(
              emphasize ? context.fx.primary : context.fx.onSurface,
              context: context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
