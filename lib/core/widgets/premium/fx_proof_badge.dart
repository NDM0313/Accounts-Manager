import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxProofBadge extends StatelessWidget {
  const FxProofBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.fx.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file, size: 12, color: context.fx.secondary),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: AppTypography.labelCaps(
              context.fx.secondary,
              context: context,
            ).copyWith(fontSize: 8),
          ),
        ],
      ),
    );
  }
}
