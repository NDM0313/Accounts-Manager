import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Status row: last updated + Manual Reference pill.
class FxStitchRateBoardHeader extends StatelessWidget {
  const FxStitchRateBoardHeader({
    super.key,
    this.lastUpdated,
    this.sourceLabel = 'Manual Reference',
  });

  final DateTime? lastUpdated;
  final String sourceLabel;

  String _relativeTime(DateTime? at) {
    if (at == null) return 'Unknown';
    final diff = DateTime.now().difference(at.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return DateFormat.yMMMd().add_jm().format(at.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.schedule, size: 18, color: context.fx.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          'Last Updated: ${_relativeTime(lastUpdated)}',
          style: AppTypography.bodySm(
            context.fx.onSurfaceVariant,
            context: context,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.fx.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: context.fx.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.fx.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                sourceLabel.toUpperCase(),
                style: AppTypography.labelCaps(
                  context.fx.secondary,
                  context: context,
                ).copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// BUY/SELL bento rate card per `rate_board/code.html`.
class FxStitchRateCard extends StatelessWidget {
  const FxStitchRateCard({
    super.key,
    required this.pairLabel,
    required this.subtitle,
    required this.buyRate,
    required this.sellRate,
    this.onEdit,
    this.isStale = false,
  });

  final String pairLabel;
  final String subtitle;
  final String buyRate;
  final String sellRate;
  final VoidCallback? onEdit;
  final bool isStale;

  static String currencyFromPair(String pairLabel) {
    final parts = pairLabel.split('/');
    return parts.isNotEmpty ? parts.first.trim() : pairLabel;
  }

  @override
  Widget build(BuildContext context) {
    final code = currencyFromPair(pairLabel);

    return FxStitchCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.fx.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.fx.outlineVariant),
                ),
                alignment: Alignment.center,
                child: Text(
                  code,
                  style: AppTypography.labelCaps(
                    context.fx.primary,
                    context: context,
                  ).copyWith(fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pairLabel,
                      style: AppTypography.dataLg(
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
                    if (isStale)
                      Text(
                        'May be outdated',
                        style: AppTypography.bodySm(
                          context.fx.warning,
                          context: context,
                        ),
                      ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: context.fx.secondary),
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RateBox(
                  label: 'BUY',
                  value: buyRate,
                  bg: context.fx.surfaceContainerLow,
                  labelColor: context.fx.onSurfaceVariant,
                  valueColor: context.fx.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RateBox(
                  label: 'SELL',
                  value: sellRate,
                  bg: context.fx.secondaryContainer,
                  labelColor: context.fx.onSecondaryContainer,
                  valueColor: context.fx.onSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RateBox extends StatelessWidget {
  const _RateBox({
    required this.label,
    required this.value,
    required this.bg,
    required this.labelColor,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color bg;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelCaps(labelColor, context: context),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.headlineMd(valueColor, context: context)
                .copyWith(fontSize: 24, height: 1),
          ),
        ],
      ),
    );
  }
}

/// Compact derived cross-rate chip.
class FxStitchDerivedRateChip extends StatelessWidget {
  const FxStitchDerivedRateChip({
    super.key,
    required this.pairLabel,
    required this.rateLabel,
  });

  final String pairLabel;
  final String rateLabel;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pairLabel,
            style: AppTypography.dataMd(
              context.fx.primary,
              context: context,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rateLabel,
            style: AppTypography.dataLg(
              context.fx.onSurface,
              context: context,
            ),
          ),
        ],
      ),
    );
  }
}
