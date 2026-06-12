import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

enum FxStatusTone { pending, completed, draft, voided, warning, neutral }

class FxStatusBadge extends StatelessWidget {
  const FxStatusBadge({
    super.key,
    required this.label,
    this.tone = FxStatusTone.neutral,
  });

  final String label;
  final FxStatusTone tone;

  static FxStatusTone fromString(String status) {
    return switch (status.toLowerCase()) {
      'posted' || 'completed' || 'done' => FxStatusTone.completed,
      'draft' => FxStatusTone.draft,
      'voided' || 'void' => FxStatusTone.voided,
      'pending' => FxStatusTone.pending,
      'warning' => FxStatusTone.warning,
      _ => FxStatusTone.neutral,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      FxStatusTone.completed => context.fx.tertiary,
      FxStatusTone.pending => context.fx.secondary,
      FxStatusTone.draft => context.fx.onSurfaceVariant,
      FxStatusTone.voided => context.fx.error,
      FxStatusTone.warning => context.fx.warning,
      FxStatusTone.neutral => context.fx.outline,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelCaps(
          color,
          context: context,
        ).copyWith(fontSize: 9),
      ),
    );
  }
}
