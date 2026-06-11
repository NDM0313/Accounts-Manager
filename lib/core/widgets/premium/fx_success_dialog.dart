import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxSuccessDialog extends StatelessWidget {
  const FxSuccessDialog({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel = 'Done',
    this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String actionLabel = 'Done',
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => FxSuccessDialog(
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(Icons.check_circle, color: context.fx.tertiary, size: 48),
      title: Text(title, style: AppTypography.headlineSm(context.fx.onSurface, context: context)),
      content: Text(message, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
      actions: [
        FilledButton(
          onPressed: onAction ?? () => Navigator.of(context).pop(),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}
