import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

class FxBottomActionBar extends StatelessWidget {
  const FxBottomActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryEnabled = true,
    this.isLoading = false,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool primaryEnabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: context.fx.surface,
          border: Border(top: BorderSide(color: context.fx.outlineVariant)),
        ),
        child: Row(
          children: [
            if (secondaryLabel != null && onSecondary != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : onSecondary,
                  child: Text(secondaryLabel!),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: secondaryLabel != null ? 2 : 1,
              child: FilledButton(
                onPressed: primaryEnabled && !isLoading ? onPrimary : null,
                child: isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(primaryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
