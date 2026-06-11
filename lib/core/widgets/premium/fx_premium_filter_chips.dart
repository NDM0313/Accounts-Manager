import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_ledger_card.dart';
import 'package:flutter/material.dart';

class FxPremiumFilterChips extends StatelessWidget {
  const FxPremiumFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
    this.showLast30Days = false,
    this.last30DaysOnly = false,
    this.onLast30DaysChanged,
    this.showCurrencyAndMore = false,
    this.selectedCurrencyCode,
    this.onCurrencyTap,
    this.sortOrder = FxLedgerSortOrder.newest,
    this.onSortChanged,
  });

  final FxLedgerFilter selected;
  final ValueChanged<FxLedgerFilter> onChanged;
  final bool showLast30Days;
  final bool last30DaysOnly;
  final ValueChanged<bool>? onLast30DaysChanged;
  final bool showCurrencyAndMore;
  final String? selectedCurrencyCode;
  final VoidCallback? onCurrencyTap;
  final FxLedgerSortOrder sortOrder;
  final ValueChanged<FxLedgerSortOrder>? onSortChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(context, 'Active', FxLedgerFilter.active),
          const SizedBox(width: 6),
          _chip(context, 'Drafts', FxLedgerFilter.draft),
          const SizedBox(width: 6),
          _chip(context, 'Voided', FxLedgerFilter.voided),
          const SizedBox(width: 6),
          _chip(context, 'All', FxLedgerFilter.all),
          if (showLast30Days && onLast30DaysChanged != null) ...[
            const SizedBox(width: 6),
            _toggleChip(context, 'Last 30 days', selected: last30DaysOnly, onSelected: onLast30DaysChanged!),
          ],
          if (showCurrencyAndMore && onCurrencyTap != null) ...[
            const SizedBox(width: 6),
            _toggleChip(
              context,
              selectedCurrencyCode ?? 'Currency',
              selected: selectedCurrencyCode != null,
              onSelected: (_) => onCurrencyTap!(),
              icon: Icons.payments_outlined,
            ),
          ],
          if (showCurrencyAndMore && onSortChanged != null) ...[
            const SizedBox(width: 6),
            PopupMenuButton<FxLedgerSortOrder>(
              onSelected: onSortChanged,
              color: context.fx.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                side: BorderSide(color: context.fx.outlineVariant),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(value: FxLedgerSortOrder.newest, child: const Text('Newest first')),
                PopupMenuItem(value: FxLedgerSortOrder.oldest, child: const Text('Oldest first')),
              ],
              child: _chipShell(context, label: 'Sort', selected: false, icon: Icons.tune),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, FxLedgerFilter value) {
    final selected = this.selected == value;
    return _chipShell(context, label: label, selected: selected, onTap: () => onChanged(value));
  }

  Widget _toggleChip(
    BuildContext context,
    String label, {
    required bool selected,
    required ValueChanged<bool> onSelected,
    IconData? icon,
  }) {
    return _chipShell(context, label: label, selected: selected, icon: icon, onTap: () => onSelected(!selected));
  }

  Widget _chipShell(
    BuildContext context, {
    required String label,
    required bool selected,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    final bg = selected ? context.fx.primary.withValues(alpha: 0.12) : context.fx.surface;
    final border = selected ? context.fx.primary : context.fx.outlineVariant;
    final fg = selected ? context.fx.primary : context.fx.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: AppTypography.labelCaps(fg, context: context).copyWith(fontSize: 10, letterSpacing: 0.04),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
