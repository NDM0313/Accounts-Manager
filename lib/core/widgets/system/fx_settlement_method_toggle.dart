import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Bank / Cash method toggle that drives account filtering.
class FxSettlementMethodToggle extends StatelessWidget {
  const FxSettlementMethodToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  /// `bank` or `cash`.
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    Widget chip({
      required String method,
      required String label,
      required IconData icon,
    }) {
      final selected = value == method;
      return Expanded(
        child: Material(
          color: selected
              ? fx.primary.withValues(alpha: 0.12)
              : fx.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled
                ? () {
                    if (value != method) onChanged(method);
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? fx.primary : fx.outlineVariant,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? fx.primary : fx.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTypography.bodyMd(
                      selected ? fx.primary : fx.onSurface,
                      context: context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Settlement method ${value == 'bank' ? 'Bank' : 'Cash'}',
      child: Row(
        children: [
          chip(
            method: 'bank',
            label: 'Bank',
            icon: Icons.account_balance_outlined,
          ),
          const SizedBox(width: 10),
          chip(
            method: 'cash',
            label: 'Cash',
            icon: Icons.payments_outlined,
          ),
        ],
      ),
    );
  }
}
