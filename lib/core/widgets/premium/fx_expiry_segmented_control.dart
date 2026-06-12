import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Stitch share_secure_link_configuration expiry picker.
class FxExpirySegmentedControl extends StatelessWidget {
  const FxExpirySegmentedControl({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Row(
        children: List.generate(options.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: Material(
              color: selected
                  ? context.fx.surfaceContainerLowest
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: InkWell(
                onTap: () => onSelected(i),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: selected
                      ? BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                          border: Border.all(color: context.fx.outlineVariant),
                        )
                      : null,
                  child: Text(
                    options[i],
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm(
                      selected
                          ? context.fx.secondary
                          : context.fx.onSurfaceVariant,
                      context: context,
                    ).copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
