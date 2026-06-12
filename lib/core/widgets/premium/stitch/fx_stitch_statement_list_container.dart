import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// White grouped container for statement activity rows per Stitch mock.
class FxStitchStatementListContainer extends StatelessWidget {
  const FxStitchStatementListContainer({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: context.fx.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}
