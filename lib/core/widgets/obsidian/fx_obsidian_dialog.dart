import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:flutter/material.dart';

Future<bool?> showFxObsidianConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Confirm',
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (ctx) => _FxObsidianDialogShell(
      title: title,
      message: message,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      destructive: false,
      onConfirm: () => Navigator.pop(ctx, true),
    ),
  );
}

/// Returns trimmed reason, or null if cancelled / empty reason.
Future<String?> showFxDeleteTransactionDialog(
  BuildContext context, {
  bool isDraft = false,
}) {
  final reasonCtrl = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (ctx) => _FxObsidianDialogShell(
      title: isDraft ? 'Delete draft?' : 'Delete transaction?',
      message: isDraft
          ? 'This draft will be permanently removed.'
          : 'This will remove it from normal reports and update balances.\nThis action will be saved in audit history.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
      destructive: true,
      reasonField: reasonCtrl,
      reasonLabel: 'Reason for delete',
      onConfirm: () {
        final reason = reasonCtrl.text.trim();
        if (reason.isEmpty) return;
        Navigator.pop(ctx, reason);
      },
    ),
  ).whenComplete(reasonCtrl.dispose);
}

class _FxObsidianDialogShell extends StatelessWidget {
  const _FxObsidianDialogShell({
    required this.title,
    this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.destructive,
    required this.onConfirm,
    this.reasonField,
    this.reasonLabel,
  });

  final String title;
  final String? message;
  final String cancelLabel;
  final String confirmLabel;
  final bool destructive;
  final VoidCallback onConfirm;
  final TextEditingController? reasonField;
  final String? reasonLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.fx.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        side: BorderSide(color: context.fx.outlineVariant),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: AppTypography.headlineMd(
                  destructive ? context.fx.error : context.fx.onSurface,
                  context: context,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              ],
              if (reasonField != null) ...[
                const SizedBox(height: 16),
                FxObsidianFormField(
                  label: reasonLabel ?? 'Reason',
                  controller: reasonField!,
                  maxLines: 2,
                  accentTertiary: destructive,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.fx.onSurfaceVariant,
                        side: BorderSide(color: context.fx.outlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: destructive
                            ? const Color(0xFFEF4444)
                            : context.fx.primary,
                        foregroundColor: destructive
                            ? Colors.white
                            : context.fx.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
