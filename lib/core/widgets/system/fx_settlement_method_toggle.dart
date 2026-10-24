import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxSettlementMethodToggle extends StatelessWidget {
  const FxSettlementMethodToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.showThirdParty = false,
  });

  /// `bank`, `cash`, or `third_party` (customer pays agent external — no owned bank).
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool showThirdParty;

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
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? fx.primary : fx.outlineVariant,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? fx.primary : fx.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm(
                      selected ? fx.primary : fx.onSurface,
                      context: context,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final label = switch (value) {
      'cash' => 'Cash',
      'third_party' => 'Agent external',
      _ => 'Bank',
    };

    return Semantics(
      label: 'Settlement method $label',
      child: Row(
        children: [
          chip(
            method: 'bank',
            label: 'Bank',
            icon: Icons.account_balance_outlined,
          ),
          const SizedBox(width: 8),
          chip(
            method: 'cash',
            label: 'Cash',
            icon: Icons.payments_outlined,
          ),
          if (showThirdParty) ...[
            const SizedBox(width: 8),
            chip(
              method: 'third_party',
              label: 'Agent\nexternal',
              icon: Icons.handshake_outlined,
            ),
          ],
        ],
      ),
    );
  }
}
