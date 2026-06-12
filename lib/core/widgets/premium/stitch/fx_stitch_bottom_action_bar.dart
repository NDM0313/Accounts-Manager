import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxStitchBottomAction {
  const FxStitchBottomAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
}

/// Stitch fixed bottom action bar (statement, deal detail).
class FxStitchBottomActionBar extends StatelessWidget {
  const FxStitchBottomActionBar({super.key, required this.actions});

  final List<FxStitchBottomAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLowest,
        border: Border(top: BorderSide(color: context.fx.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: actions[i].primary
                    ? FilledButton.icon(
                        onPressed: actions[i].onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: context.fx.primaryContainer,
                          foregroundColor: context.fx.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: Icon(actions[i].icon, size: 18),
                        label: Text(actions[i].label),
                      )
                    : TextButton.icon(
                        onPressed: actions[i].onTap,
                        icon: Icon(
                          actions[i].icon,
                          size: 20,
                          color: context.fx.secondary,
                        ),
                        label: Text(
                          actions[i].label,
                          style: AppTypography.labelCaps(
                            context.fx.onSurface,
                            context: context,
                          ).copyWith(fontSize: 9),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
