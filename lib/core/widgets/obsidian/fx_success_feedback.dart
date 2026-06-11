import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxResultAction {
  const FxResultAction({required this.label, required this.onPressed, this.filled = false});

  final String label;
  final VoidCallback onPressed;
  final bool filled;
}

/// Reusable success snackbars and result sheets.
abstract final class FxSuccessFeedback {
  static void showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: context.fx.onPrimary, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: context.fx.tertiary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<void> showResultSheet(
    BuildContext context, {
    required String title,
    required String body,
    List<FxResultAction> actions = const [],
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: context.fx.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
            border: Border.all(color: context.fx.outlineVariant),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: context.fx.tertiary, size: 48),
                const SizedBox(height: 12),
                Text(title, style: AppTypography.headlineMd(context.fx.onSurface, context: context)),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ...actions.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: a.filled
                          ? FilledButton(onPressed: a.onPressed, child: Text(a.label))
                          : OutlinedButton(onPressed: a.onPressed, child: Text(a.label)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
