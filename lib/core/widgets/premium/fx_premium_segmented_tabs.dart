import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxPremiumSegmentedTabs extends StatelessWidget {
  const FxPremiumSegmentedTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: _tab(context, i, tabs[i])),
          ],
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, int index, String label) {
    final selected = selectedIndex == index;
    return Material(
      color: selected ? context.fx.surface : Colors.transparent,
      elevation: selected ? 1 : 0,
      shadowColor: context.fx.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
      child: InkWell(
        onTap: () => onChanged(index),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                AppTypography.bodyMd(
                  selected ? context.fx.primary : context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12,
                ),
          ),
        ),
      ),
    );
  }
}
