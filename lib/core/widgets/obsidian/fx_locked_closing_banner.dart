import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxLockedClosingBanner extends StatelessWidget {
  const FxLockedClosingBanner({super.key, this.onRequestEdit, this.onRequestDelete});

  final VoidCallback? onRequestEdit;
  final VoidCallback? onRequestDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fx.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.fx.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: context.fx.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This day is already closed.',
                  style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Edit/Delete requires admin approval.',
            style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
          ),
          if (onRequestEdit != null || onRequestDelete != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onRequestEdit != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRequestEdit,
                      child: const Text('Request Edit'),
                    ),
                  ),
                if (onRequestEdit != null && onRequestDelete != null) const SizedBox(width: 8),
                if (onRequestDelete != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRequestDelete,
                      style: OutlinedButton.styleFrom(foregroundColor: context.fx.error),
                      child: const Text('Request Delete'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
