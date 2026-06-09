import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_ledger_card.dart';
import 'package:flutter/material.dart';

enum FxLedgerFilter { active, draft, voided, all }

class FxFilterChipRow extends StatelessWidget {
  const FxFilterChipRow({
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
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(context, theme, 'ACTIVE ONLY', FxLedgerFilter.active, filled: selected == FxLedgerFilter.active),
          const SizedBox(width: 8),
          _chip(context, theme, 'DRAFTS', FxLedgerFilter.draft, filled: selected == FxLedgerFilter.draft),
          const SizedBox(width: 8),
          _chip(context, theme, 'VOIDED', FxLedgerFilter.voided, filled: selected == FxLedgerFilter.voided),
          const SizedBox(width: 8),
          _chip(context, theme, 'ALL', FxLedgerFilter.all, filled: selected == FxLedgerFilter.all),
          if (showLast30Days && onLast30DaysChanged != null) ...[
            const SizedBox(width: 8),
            _toggleChip(
              context,
              theme,
              'LAST 30 DAYS',
              selected: last30DaysOnly,
              onSelected: onLast30DaysChanged!,
            ),
          ],
          if (showCurrencyAndMore && onCurrencyTap != null) ...[
            const SizedBox(width: 8),
            _toggleChip(
              context,
              theme,
              selectedCurrencyCode ?? 'CURRENCY',
              selected: selectedCurrencyCode != null,
              onSelected: (_) => onCurrencyTap!(),
              icon: Icons.payments_outlined,
            ),
          ],
          if (showCurrencyAndMore && onSortChanged != null) ...[
            const SizedBox(width: 8),
            PopupMenuButton<FxLedgerSortOrder>(
              onSelected: onSortChanged,
              color: context.fx.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                side: BorderSide(color: context.fx.outlineVariant),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: FxLedgerSortOrder.newest,
                  child: Text(
                    'Newest first',
                    style: AppTypography.bodyMd(
                      sortOrder == FxLedgerSortOrder.newest ? context.fx.tertiary : context.fx.onSurface, context: context),
                  ),
                ),
                PopupMenuItem(
                  value: FxLedgerSortOrder.oldest,
                  child: Text(
                    'Oldest first',
                    style: AppTypography.bodyMd(
                      sortOrder == FxLedgerSortOrder.oldest ? context.fx.tertiary : context.fx.onSurface, context: context),
                  ),
                ),
              ],
              child: _chipShell(
                context,
                theme,
                label: 'MORE',
                filled: false,
                icon: Icons.tune,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, ThemeData theme, String label, FxLedgerFilter value, {required bool filled}) {
    return FilterChip(
      label: Text(
        label,
        style: AppTypography.labelCaps(filled ? context.fx.onTertiary : theme.colorScheme.onSurfaceVariant, context: context)
            .copyWith(fontSize: 11),
      ),
      selected: filled,
      onSelected: (_) => onChanged(value),
      showCheckmark: false,
      selectedColor: theme.colorScheme.tertiary,
      backgroundColor: context.fx.surfaceContainerLow,
      side: BorderSide(color: filled ? theme.colorScheme.tertiary : context.fx.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _toggleChip(
    BuildContext context,
    ThemeData theme,
    String label, {
    required bool selected,
    required ValueChanged<bool> onSelected,
    IconData? icon,
  }) {
    return FilterChip(
      avatar: icon != null
          ? Icon(icon, size: 16, color: selected ? context.fx.onTertiary : theme.colorScheme.onSurfaceVariant)
          : null,
      label: Text(
        label,
        style: AppTypography.labelCaps(selected ? context.fx.onTertiary : theme.colorScheme.onSurfaceVariant, context: context)
            .copyWith(fontSize: 11),
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: theme.colorScheme.tertiary,
      backgroundColor: context.fx.surfaceContainerLow,
      side: BorderSide(color: selected ? theme.colorScheme.tertiary : context.fx.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _chipShell(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required bool filled,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? theme.colorScheme.tertiary : context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? theme.colorScheme.tertiary : context.fx.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.labelCaps(theme.colorScheme.onSurfaceVariant, context: context).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
