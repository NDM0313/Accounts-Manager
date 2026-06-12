import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxObsidianActionBar extends StatelessWidget {
  const FxObsidianActionBar({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.cancelLabel = 'Cancel',
    this.saveLabel = 'Save Changes',
    this.busy = false,
  });

  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final String cancelLabel;
  final String saveLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        12,
        AppSpacing.marginMobile,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: context.fx.surface,
        border: Border(top: BorderSide(color: context.fx.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: busy ? null : onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.fx.onSurfaceVariant,
              side: BorderSide(color: context.fx.outlineVariant),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(cancelLabel),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: busy || onSave == null ? null : onSave,
            style: FilledButton.styleFrom(
              backgroundColor: context.fx.primary,
              foregroundColor: context.fx.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 4,
            ),
            child: busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    saveLabel,
                    style: AppTypography.labelCaps(
                      context.fx.onPrimary,
                      context: context,
                    ).copyWith(fontSize: 12),
                  ),
          ),
        ],
      ),
    );
  }
}
