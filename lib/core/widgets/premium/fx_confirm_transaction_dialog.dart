import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Stitch transaction_confirmation modal.
class FxConfirmTransactionDialog extends StatelessWidget {
  const FxConfirmTransactionDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.operationLabel,
    required this.operationValue,
    required this.rateLabel,
    required this.rateValue,
    required this.lines,
    required this.totalLabel,
    required this.totalValue,
    required this.disclaimer,
    required this.onConfirm,
    this.confirmLabel = 'Confirm & Post',
  });

  final String title;
  final String subtitle;
  final String operationLabel;
  final String operationValue;
  final String rateLabel;
  final String rateValue;
  final List<(String label, String value)> lines;
  final String totalLabel;
  final String totalValue;
  final String disclaimer;
  final VoidCallback onConfirm;
  final String confirmLabel;

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String operationLabel,
    required String operationValue,
    required String rateLabel,
    required String rateValue,
    required List<(String label, String value)> lines,
    required String totalLabel,
    required String totalValue,
    required String disclaimer,
    String confirmLabel = 'Confirm & Post',
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: context.fx.onSurface.withValues(alpha: 0.2),
      builder: (ctx) => FxConfirmTransactionDialog(
        title: title,
        subtitle: subtitle,
        operationLabel: operationLabel,
        operationValue: operationValue,
        rateLabel: rateLabel,
        rateValue: rateValue,
        lines: lines,
        totalLabel: totalLabel,
        totalValue: totalValue,
        disclaimer: disclaimer,
        confirmLabel: confirmLabel,
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.fx.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        side: BorderSide(color: context.fx.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.fx.secondary.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: context.fx.secondaryContainer
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            size: 48,
                            color: context.fx.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: AppTypography.headlineMd(
                      context.fx.primary,
                      context: context,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: AppTypography.bodyMd(
                      context.fx.onSurfaceVariant,
                      context: context,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.fx.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: context.fx.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCol(
                            label: operationLabel,
                            value: operationValue,
                            alignEnd: false,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: context.fx.outlineVariant,
                        ),
                        Expanded(
                          child: _SummaryCol(
                            label: rateLabel,
                            value: rateValue,
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Divider(
                        height: 1,
                        color: context.fx.outlineVariant,
                      ),
                    ),
                    ...lines.map(
                      (l) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l.$1,
                              style: AppTypography.bodySm(
                                context.fx.onSurfaceVariant,
                                context: context,
                              ),
                            ),
                            Text(
                              l.$2,
                              style: AppTypography.dataMd(
                                context.fx.onSurface,
                                context: context,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            totalLabel,
                            style: AppTypography.bodyMd(
                              context.fx.onSurface,
                              context: context,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            totalValue,
                            textAlign: TextAlign.end,
                            style: AppTypography.dataLg(
                              context.fx.secondary,
                              context: context,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: context.fx.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      disclaimer,
                      style: AppTypography.bodySm(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: FilledButton(
                      onPressed: onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: context.fx.secondary,
                        foregroundColor: context.fx.onSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        ),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.fx.onSurfaceVariant,
                        side: BorderSide(color: context.fx.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.fx.secondary,
                    AppColors.lightPrimaryContainer,
                    context.fx.secondary,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCol extends StatelessWidget {
  const _SummaryCol({
    required this.label,
    required this.value,
    required this.alignEnd,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelCaps(
            context.fx.outline,
            context: context,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.bodyLg(
            context.fx.primary,
            context: context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
