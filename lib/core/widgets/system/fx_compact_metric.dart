import 'package:accounts_manager/app/theme/fx_design_tokens.dart';
import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/core/widgets/system/fx_money_label.dart';
import 'package:flutter/material.dart';

/// Content-height metric tile — never uses fixed aspect ratios.
class FxCompactMetric extends StatelessWidget {
  const FxCompactMetric({
    super.key,
    required this.label,
    required this.amount,
    this.currencyCode = 'PKR',
    this.subtitle,
    this.valueColor,
    this.onTap,
    this.accent = FxAccent.brand,
  });

  final String label;
  final double? amount;
  final String currencyCode;
  final String? subtitle;
  final Color? valueColor;
  final VoidCallback? onTap;
  final FxAccent accent;

  @override
  Widget build(BuildContext context) {
    final card = FxStitchCard(
      color: context.fxAccentSurface(accent),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.stackMd,
        vertical: 18,
      ),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMd(
              context.fx.onSurfaceVariant,
              context: context,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.chipGap),
          if (amount == null)
            Text(
              '—',
              style: AppTypography.headlineSm(
                context.fx.onSurfaceVariant,
                context: context,
              ),
            )
          else
            FxMoneyLabel(
              amount: amount!,
              currencyCode: currencyCode,
              color: valueColor ?? context.fxAccent(accent),
              bold: true,
              fontSize: 24,
              align: TextAlign.start,
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
    return card;
  }
}
