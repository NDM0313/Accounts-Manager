import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:flutter/material.dart';

/// Horizontal 5-step progress per `opening_balance_wizard/code.html`.
class FxStitchOpeningBalanceStepper extends StatelessWidget {
  const FxStitchOpeningBalanceStepper({
    super.key,
    required this.currentStep,
    this.completedThrough,
  });

  /// Active wizard step index (0–4 maps to Setup…Review).
  final int currentStep;

  /// When set (e.g. post success), all steps show complete.
  final int? completedThrough;

  static const labels = [
    'Setup',
    'Cash & Bank',
    'Currency',
    'Balances',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    final active = completedThrough ?? currentStep;
    final progress = (active / (labels.length - 1)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: context.fx.outlineVariant),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          return SizedBox(
            height: 52,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 11,
                  left: 16,
                  right: 16,
                  child: Container(
                    height: 2,
                    color: context.fx.outlineVariant,
                  ),
                ),
                Positioned(
                  top: 11,
                  left: 16,
                  width: (c.maxWidth - 32) * progress,
                  child: Container(
                    height: 2,
                    color: context.fx.secondary,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      _StepDot(
                        index: i,
                        label: labels[i],
                        isComplete: i < active,
                        isCurrent: i == active && completedThrough == null,
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.isComplete,
    required this.isCurrent,
  });

  final int index;
  final String label;
  final bool isComplete;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final done = isComplete && !isCurrent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || isCurrent
                ? context.fx.secondary
                : context.fx.surfaceContainerHighest,
            border: done || isCurrent
                ? null
                : Border.all(color: context.fx.outlineVariant, width: 2),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: context.fx.surfaceContainerHigh.withValues(alpha: 0.9),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: done
                ? Icon(Icons.check, size: 14, color: context.fx.onSecondary)
                : Text(
                    '${index + 1}',
                    style: AppTypography.dataMd(
                      isCurrent
                          ? context.fx.onSecondary
                          : context.fx.onSurfaceVariant,
                      context: context,
                    ).copyWith(fontSize: 12),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: AppTypography.labelCaps(
            isCurrent ? context.fx.secondary : context.fx.onSurfaceVariant,
            context: context,
          ).copyWith(
            fontSize: 9,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class FxStitchOpeningBalanceWarning extends StatelessWidget {
  const FxStitchOpeningBalanceWarning({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fx.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: context.fx.error.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning,
            color: context.fx.error,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySm(
                context.fx.error,
                context: context,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Currency position line card for opening balance wizard.
class FxStitchOpeningBalanceCurrencyLine extends StatelessWidget {
  const FxStitchOpeningBalanceCurrencyLine({
    super.key,
    required this.currencyCode,
    required this.amountLabel,
    required this.pkrLabel,
    this.locationLabel,
    this.onDelete,
  });

  final String currencyCode;
  final String amountLabel;
  final String pkrLabel;
  final String? locationLabel;
  final VoidCallback? onDelete;

  static String _symbol(String code) => switch (code) {
        'PKR' => '₨',
        'USD' => '\$',
        'AED' => 'د.إ',
        'CNY' => '¥',
        'SAR' => '﷼',
        'EUR' => '€',
        'GBP' => '£',
        _ => code.isNotEmpty ? code[0] : '?',
      };

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.fx.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _symbol(currencyCode),
                  style: AppTypography.dataMd(
                    context.fx.primary,
                    context: context,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currencyCode,
                  style: AppTypography.dataLg(
                    context.fx.primary,
                    context: context,
                  ),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: context.fx.onSurfaceVariant,
                  onPressed: onDelete,
                ),
            ],
          ),
          Divider(color: context.fx.surfaceContainer, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUANTITY',
                style: AppTypography.labelCaps(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
              Text(
                amountLabel,
                style: AppTypography.dataLg(
                  context.fx.onSurface,
                  context: context,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PKR EQUIVALENT',
                style: AppTypography.labelCaps(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
              Text(
                pkrLabel,
                style: AppTypography.dataMd(
                  context.fx.secondary,
                  context: context,
                ),
              ),
            ],
          ),
          if (locationLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              'Location: $locationLabel',
              style: AppTypography.bodySm(
                context.fx.onSurfaceVariant,
                context: context,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Stitch labeled field for opening balance setup steps.
class FxStitchOpeningBalanceField extends StatelessWidget {
  const FxStitchOpeningBalanceField({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelCaps(
            context.fx.onSurfaceVariant,
            context: context,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Summary row for review step.
class FxStitchOpeningBalanceSummaryRow extends StatelessWidget {
  const FxStitchOpeningBalanceSummaryRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMd(
              context.fx.onSurfaceVariant,
              context: context,
            ),
          ),
          Text(
            value,
            style: AppTypography.dataMd(
              context.fx.onSurface,
              context: context,
            ),
          ),
        ],
      ),
    );
  }
}
