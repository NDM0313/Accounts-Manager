import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:flutter/material.dart';

/// Exchange rates card with spread badge (new customer deal).
class FxStitchExchangeRatesCard extends StatelessWidget {
  const FxStitchExchangeRatesCard({
    super.key,
    required this.referenceRate,
    required this.dealRate,
    this.spreadLabel,
  });

  final String referenceRate;
  final String dealRate;
  final String? spreadLabel;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Exchange Rates',
                style: AppTypography.headlineSm(
                  context.fx.onSurface,
                  context: context,
                ),
              ),
              const Spacer(),
              if (spreadLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.fx.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    spreadLabel!,
                    style: AppTypography.labelCaps(
                      context.fx.secondary,
                      context: context,
                    ).copyWith(fontSize: 9),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.fx.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reference Rate',
                  style: AppTypography.labelCaps(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ).copyWith(fontSize: 9),
                ),
                Text(
                  referenceRate,
                  style: AppTypography.dataLg(
                    context.fx.onSurface,
                    context: context,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.fx.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: context.fx.secondary, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deal Rate',
                  style: AppTypography.labelCaps(
                    context.fx.secondary,
                    context: context,
                  ).copyWith(fontSize: 9),
                ),
                Text(
                  dealRate,
                  style: AppTypography.dataLg(
                    context.fx.secondary,
                    context: context,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Navy total payable summary card.
class FxStitchTotalPayableCard extends StatelessWidget {
  const FxStitchTotalPayableCard({
    super.key,
    required this.amountLabel,
    this.footer = 'Inclusive of all service spreads',
  });

  final String amountLabel;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.fx.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL PAYABLE (PKR)',
            style: AppTypography.labelCaps(
              context.fx.onPrimaryContainer,
              context: context,
            ).copyWith(fontSize: 10),
          ),
          const SizedBox(height: 8),
          Text(
            amountLabel,
            style: AppTypography.headlineMd(
              Colors.white,
              context: context,
            ).copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: context.fx.onPrimaryContainer),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  footer,
                  style: AppTypography.bodySm(
                    context.fx.onPrimaryContainer,
                    context: context,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "What happens next?" info card.
class FxStitchWhatHappensNextCard extends StatelessWidget {
  const FxStitchWhatHappensNextCard({super.key, required this.bullets});

  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      color: context.fx.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What happens next?',
            style: AppTypography.headlineSm(
              context.fx.primary,
              context: context,
            ),
          ),
          const SizedBox(height: 12),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: context.fx.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b,
                      style: AppTypography.bodySm(
                        context.fx.onSurface,
                        context: context,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Delivery method 3-segment control.
class FxStitchDeliverySegments extends StatelessWidget {
  const FxStitchDeliverySegments({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final selected = i == selectedIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < labels.length - 1 ? 6 : 0),
            child: Material(
              color: selected
                  ? context.fx.primaryContainer
                  : context.fx.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: selected
                          ? context.fx.primaryContainer
                          : context.fx.outlineVariant,
                    ),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm(
                      selected ? Colors.white : context.fx.onSurfaceVariant,
                      context: context,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
