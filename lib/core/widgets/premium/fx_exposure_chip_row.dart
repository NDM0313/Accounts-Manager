import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxExposureItem {
  const FxExposureItem({
    required this.currencyCode,
    required this.amountLabel,
  });

  final String currencyCode;
  final String amountLabel;
}

/// Stitch customer_statement horizontal exposure chips.
class FxExposureChipRow extends StatelessWidget {
  const FxExposureChipRow({super.key, required this.items});

  final List<FxExposureItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.gutter),
        itemBuilder: (context, i) {
          final item = items[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.fx.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: context.fx.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.fx.surfaceContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.currencyCode.substring(0, 2),
                    style: AppTypography.labelCaps(
                      context.fx.primary,
                      context: context,
                    ).copyWith(fontSize: 9),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.currencyCode,
                      style: AppTypography.dataMd(
                        context.fx.primary,
                        context: context,
                      ),
                    ),
                    Text(
                      item.amountLabel,
                      style: AppTypography.bodySm(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ),
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
