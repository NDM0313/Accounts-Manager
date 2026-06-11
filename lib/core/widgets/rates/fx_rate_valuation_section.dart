import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/domain/services/rate_suggestion_service.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Reusable "Rate & Valuation" block for transaction and deal forms.
class FxRateValuationSection extends ConsumerStatefulWidget {
  const FxRateValuationSection({
    super.key,
    required this.fromCurrency,
    required this.toCurrency,
    required this.dealRateController,
    this.receiveAmount,
    this.payAmountController,
    this.rateSide = RateSide.reference,
    this.asOfDate,
    this.onDealRateChanged,
    this.onSuggestedPayAmount,
    this.dealRateLabel = 'Deal rate',
    this.showPkrEquivalent = true,
    this.validator,
  });

  final String fromCurrency;
  final String toCurrency;
  final TextEditingController dealRateController;
  final double? receiveAmount;
  final TextEditingController? payAmountController;
  final RateSide rateSide;
  final DateTime? asOfDate;
  final ValueChanged<double?>? onDealRateChanged;
  final ValueChanged<double?>? onSuggestedPayAmount;
  final String dealRateLabel;
  final bool showPkrEquivalent;
  final String? Function(String?)? validator;

  @override
  ConsumerState<FxRateValuationSection> createState() => _FxRateValuationSectionState();
}

class _FxRateValuationSectionState extends ConsumerState<FxRateValuationSection> {
  bool _dealRateTouched = false;
  bool _forcePrefill = false;

  @override
  void initState() {
    super.initState();
    widget.dealRateController.addListener(_onDealRateChanged);
  }

  @override
  void didUpdateWidget(covariant FxRateValuationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fromCurrency != widget.fromCurrency ||
        oldWidget.toCurrency != widget.toCurrency ||
        oldWidget.rateSide != widget.rateSide) {
      _dealRateTouched = false;
      _forcePrefill = true;
    }
  }

  @override
  void dispose() {
    widget.dealRateController.removeListener(_onDealRateChanged);
    super.dispose();
  }

  void _onDealRateChanged() {
    widget.onDealRateChanged?.call(double.tryParse(widget.dealRateController.text));
    setState(() {});
  }

  void _applySuggestedRate(RatePairQuote quote, {bool force = false}) {
    if (!quote.isAvailable) return;
    if (!force && _dealRateTouched) return;
    final suggested = quote.rate.toStringAsFixed(4);
    if (widget.dealRateController.text != suggested) {
      widget.dealRateController.text = suggested;
    }
  }

  void _updateSuggestedPay(RatePairQuote quote, double? dealRate) {
    if (widget.payAmountController == null || widget.receiveAmount == null) return;
    if (dealRate == null || dealRate <= 0) return;
    final suggested = RatePairQuote.payFromReceive(widget.receiveAmount!, dealRate);
    if (suggested != null && widget.payAmountController!.text.trim().isEmpty) {
      widget.payAmountController!.text = suggested.toStringAsFixed(2);
      widget.onSuggestedPayAmount?.call(suggested);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asOf = widget.asOfDate ?? DateTime.now();
    final ratesAsync = widget.asOfDate != null
        ? ref.watch(ratesAsOfProvider(asOf))
        : ref.watch(ratesProvider);
    final fmt = NumberFormat('#,##0.####');
    final svc = ref.read(rateSuggestionServiceProvider);

    return ratesAsync.when(
      loading: () => const FxSectionLabel(label: 'Rate & Valuation'),
      error: (_, _) => _buildContent(context, svc, [], fmt, asOf),
      data: (rates) => _buildContent(context, svc, rates, fmt, asOf),
    );
  }

  Widget _buildContent(
    BuildContext context,
    RateSuggestionService svc,
    List<FxRate> rates,
    NumberFormat fmt,
    DateTime asOf,
  ) {
    final quote = widget.asOfDate != null
        ? svc.resolvePairAsOf(
            rates,
            widget.fromCurrency,
            widget.toCurrency,
            asOf,
            side: widget.rateSide,
          )
        : svc.resolvePair(
            rates,
            widget.fromCurrency,
            widget.toCurrency,
            side: widget.rateSide,
          );

    if (quote.isAvailable && (!_dealRateTouched || _forcePrefill)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applySuggestedRate(quote, force: _forcePrefill);
        _forcePrefill = false;
        _updateSuggestedPay(quote, double.tryParse(widget.dealRateController.text));
      });
    }

    final dealRate = double.tryParse(widget.dealRateController.text);
    final spread = quote.spreadVsDeal(dealRate);
    final receivePkr = widget.showPkrEquivalent &&
            widget.receiveAmount != null &&
            widget.receiveAmount! > 0
        ? svc.pkrEquivalent(rates, widget.fromCurrency, widget.receiveAmount!)
        : null;
    final payPkr = widget.showPkrEquivalent && widget.payAmountController != null
        ? svc.pkrEquivalent(
            rates,
            widget.toCurrency,
            double.tryParse(widget.payAmountController!.text) ?? 0,
          )
        : null;

    final calculatedPay = (widget.receiveAmount != null && dealRate != null && dealRate > 0)
        ? RatePairQuote.payFromReceive(widget.receiveAmount!, dealRate)
        : null;

    final noRateMessage = widget.asOfDate != null
        ? 'No historical rate found. Enter rate manually.'
        : 'No reference rate found — enter manually';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FxSectionLabel(label: 'Rate & Valuation'),
        const SizedBox(height: 8),
        FxObsidianReportPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reference Rate',
                style: AppTypography.labelCaps(context.fx.outline, context: context),
              ),
              const SizedBox(height: 6),
              if (!quote.isAvailable)
                Text(
                  noRateMessage,
                  style: AppTypography.bodyMd(Colors.orange.shade700, context: context)
                      .copyWith(fontSize: 12),
                )
              else ...[
                Text(
                  quote.pairLabel,
                  style: AppTypography.bodyMd(context.fx.onSurface, context: context),
                ),
                Text(
                  fmt.format(quote.referenceRate),
                  style: AppTypography.headlineMd(context.fx.tertiary, context: context)
                      .copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Source: ${quote.source}',
                      style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)
                          .copyWith(fontSize: 11),
                    ),
                    if (quote.updatedByName != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· ${quote.updatedByName}',
                        style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)
                            .copyWith(fontSize: 11),
                      ),
                    ],
                  ],
                ),
                if (quote.effectiveAt != null)
                  Text(
                    widget.asOfDate != null
                        ? 'As of ${DateFormat.yMMMd().format(asOf)} · effective ${DateFormat.yMMMd().add_jm().format(quote.effectiveAt!.toLocal())}'
                        : 'Updated ${DateFormat.yMMMd().add_jm().format(quote.effectiveAt!.toLocal())}',
                    style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)
                        .copyWith(fontSize: 11),
                  ),
                if (quote.isStale)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Rate may be outdated',
                          style: AppTypography.bodyMd(Colors.orange.shade700, context: context)
                              .copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                if (quote.lookupMethod == RateLookupMethod.crossViaPkr)
                  Text(
                    'Derived via PKR cross rate',
                    style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)
                        .copyWith(fontSize: 10),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        FxObsidianFormField(
          label: widget.dealRateLabel,
          controller: widget.dealRateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          accentTertiary: true,
          validator: widget.validator,
          onChanged: (_) {
            _dealRateTouched = true;
            _onDealRateChanged();
          },
        ),
        if (_dealRateTouched && quote.isAvailable) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _dealRateTouched = false;
                  _applySuggestedRate(quote, force: true);
                });
              },
              child: const Text('Apply suggested rate'),
            ),
          ),
        ],
        if (calculatedPay != null) ...[
          const SizedBox(height: 8),
          FxObsidianReportPanel(
            child: Text(
              'Calculated pay amount: ${fmt.format(calculatedPay)} ${widget.toCurrency}',
              style: AppTypography.bodyMd(context.fx.onSurface, context: context),
            ),
          ),
        ],
        if (widget.showPkrEquivalent) ...[
          const SizedBox(height: 8),
          FxObsidianReportPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PKR Equivalent',
                  style: AppTypography.labelCaps(context.fx.outline, context: context),
                ),
                if (receivePkr != null)
                  Text(
                    'Receive side: PKR ${fmt.format(receivePkr)}',
                    style: AppTypography.bodyMd(context.fx.onSurface, context: context)
                        .copyWith(fontSize: 12),
                  )
                else if (widget.receiveAmount != null && widget.receiveAmount! > 0)
                  Text(
                    'PKR reference not available for ${widget.fromCurrency}',
                    style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)
                        .copyWith(fontSize: 12),
                  ),
                if (payPkr != null && payPkr > 0)
                  Text(
                    'Pay side: PKR ${fmt.format(payPkr)}',
                    style: AppTypography.bodyMd(context.fx.onSurface, context: context)
                        .copyWith(fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
        if (spread != null && quote.isAvailable) ...[
          const SizedBox(height: 8),
          _SpreadBadge(spread: spread, fmt: fmt),
        ],
      ],
    );
  }
}

/// Spread severity tiers for deal rate vs reference.
enum SpreadSeverity { normal, warning, critical }

SpreadSeverity spreadSeverityForPercent(double percentDiff) {
  final abs = percentDiff.abs();
  if (abs > 100) return SpreadSeverity.critical;
  if (abs > 20) return SpreadSeverity.warning;
  return SpreadSeverity.normal;
}

class _SpreadBadge extends StatelessWidget {
  const _SpreadBadge({required this.spread, required this.fmt});

  final RateSpread spread;
  final NumberFormat fmt;

  Color _color(BuildContext context) {
    if (spread.matchesReference) return context.fx.onSurfaceVariant;
    final severity = spreadSeverityForPercent(spread.percentDiff);
    return switch (severity) {
      SpreadSeverity.critical => Colors.red.shade700,
      SpreadSeverity.warning => Colors.orange.shade700,
      SpreadSeverity.normal =>
        spread.isAboveReference ? Colors.orange.shade700 : Colors.green.shade700,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final sign = spread.absoluteDiff >= 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Spread vs reference: $sign${fmt.format(spread.absoluteDiff)} ($sign${spread.percentDiff.toStringAsFixed(2)}%)',
        style: AppTypography.bodyMd(color, context: context).copyWith(fontSize: 12),
      ),
    );
  }
}

/// Applies suggested rate to [controller] when pair changes (for tests and reuse).
void applySuggestedDealRate({
  required TextEditingController controller,
  required RatePairQuote quote,
  required bool dealRateTouched,
  bool force = false,
}) {
  if (!quote.isAvailable) return;
  if (!force && dealRateTouched) return;
  controller.text = quote.rate.toStringAsFixed(4);
}
