import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:flutter/material.dart';

/// Transaction context card in share_export_options mock.
class FxStitchExportContextCard extends StatelessWidget {
  const FxStitchExportContextCard({
    super.key,
    required this.refLabel,
    this.statusLabel,
    this.summaryLines = const [],
  });

  final String refLabel;
  final String? statusLabel;
  final List<(String label, String value)> summaryLines;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRANSACTION REF',
                    style: AppTypography.labelCaps(
                      context.fx.onSurfaceVariant,
                      context: context,
                    ),
                  ),
                  Text(
                    refLabel,
                    style: AppTypography.dataLg(
                      context.fx.primary,
                      context: context,
                    ),
                  ),
                ],
              ),
              if (statusLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.fx.tertiaryContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: context.fx.tertiary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    statusLabel!,
                    style: AppTypography.bodySm(
                      context.fx.tertiaryFixedDim,
                      context: context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          if (summaryLines.isNotEmpty) ...[
            Divider(color: context.fx.outlineVariant, height: 24),
            ...summaryLines.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l.$1,
                      style: AppTypography.bodyMd(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ),
                    ),
                    Text(
                      l.$2,
                      style: AppTypography.dataMd(
                        context.fx.primary,
                        context: context,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FxStitchExportLifecycleStep {
  const FxStitchExportLifecycleStep({
    required this.title,
    required this.subtitle,
    this.completed = false,
    this.pending = false,
  });

  final String title;
  final String subtitle;
  final bool completed;
  final bool pending;
}

/// Vertical lifecycle timeline per share_export_options mock.
class FxStitchExportLifecycleTimeline extends StatelessWidget {
  const FxStitchExportLifecycleTimeline({super.key, required this.steps});

  final List<FxStitchExportLifecycleStep> steps;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Lifecycle',
            style: AppTypography.headlineSm(
              context.fx.primary,
              context: context,
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              Positioned(
                left: 11,
                top: 8,
                bottom: 8,
                child: Container(
                  width: 2,
                  color: context.fx.outlineVariant,
                ),
              ),
              Column(
                children: [
                  for (final step in steps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: step.completed
                                  ? context.fx.secondary
                                  : context.fx.surfaceContainerHighest,
                              border: step.completed
                                  ? null
                                  : Border.all(
                                      color: context.fx.outlineVariant,
                                      width: 2,
                                    ),
                            ),
                            child: Center(
                              child: step.completed
                                  ? Icon(
                                      Icons.check,
                                      size: 14,
                                      color: context.fx.onSecondary,
                                    )
                                  : Icon(
                                      Icons.pending,
                                      size: 14,
                                      color: context.fx.onSurfaceVariant,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.title,
                                  style: AppTypography.dataMd(
                                    step.pending
                                        ? context.fx.onSurfaceVariant
                                        : context.fx.primary,
                                    context: context,
                                  ),
                                ),
                                Text(
                                  step.subtitle,
                                  style: AppTypography.bodySm(
                                    context.fx.onSurfaceVariant,
                                    context: context,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum FxStitchExportOptionStyle { pdf, print, image, email }

/// Export option row with circular icon per mock.
class FxStitchExportOptionRow extends StatelessWidget {
  const FxStitchExportOptionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.style = FxStitchExportOptionStyle.pdf,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final FxStitchExportOptionStyle style;

  Color _iconBg(BuildContext context) => switch (style) {
        FxStitchExportOptionStyle.pdf =>
          context.fx.surfaceContainerHigh,
        FxStitchExportOptionStyle.print =>
          context.fx.surfaceContainerHighest,
        FxStitchExportOptionStyle.image =>
          context.fx.surfaceContainerHighest,
        FxStitchExportOptionStyle.email => context.fx.secondaryContainer,
      };

  Color _iconFg(BuildContext context) => switch (style) {
        FxStitchExportOptionStyle.email => context.fx.onSecondary,
        _ => context.fx.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _iconBg(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _iconFg(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.dataMd(
                        context.fx.primary,
                        context: context,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.bodySm(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.fx.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sheet header with title + close.
class FxStitchExportSheetHeader extends StatelessWidget {
  const FxStitchExportSheetHeader({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Share & Export',
          style: AppTypography.headlineSm(
            context.fx.primary,
            context: context,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          color: context.fx.primary,
          onPressed: onClose ?? () => Navigator.pop(context),
        ),
      ],
    );
  }
}

/// Copy Transaction Link footer CTA.
class FxStitchExportCopyLinkButton extends StatelessWidget {
  const FxStitchExportCopyLinkButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: context.fx.primary,
          foregroundColor: context.fx.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
        ),
        icon: const Icon(Icons.content_copy, size: 20),
        label: const Text('Copy Transaction Link'),
      ),
    );
  }
}
