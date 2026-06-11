import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/utils/transaction_menu_entries.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Stitch-style grouped new-transaction bottom sheet.
class FxTransactionMenuSheet extends StatelessWidget {
  const FxTransactionMenuSheet({super.key, required this.groups});

  final List<TransactionMenuGroup> groups;

  static Future<void> show(BuildContext context) {
    final groups = buildTransactionMenuGroups();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.88;
        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: context.fx.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: context.fx.outlineVariant),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.fx.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select transaction type',
                        style: AppTypography.headlineSm(context.fx.onSurface, context: context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose an action to record in the ledger',
                        style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: FxTransactionMenuSheet(groups: groups),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              _displayGroupTitle(group.title).toUpperCase(),
              style: AppTypography.labelCaps(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 10),
            ),
          ),
          if (isWide && group.title == 'FX Deals')
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in group.entries)
                  SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 48) / 2,
                    child: _MenuEntry(entry: entry),
                  ),
              ],
            )
          else
            ...group.entries.map((e) => _MenuEntry(entry: e)),
        ],
      ],
    );
  }

  static String _displayGroupTitle(String title) {
    if (title == 'Settlement / Advanced') return 'Advanced';
    return title;
  }
}

class _MenuEntry extends StatelessWidget {
  const _MenuEntry({required this.entry});

  final TransactionMenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            context.push(entry.route);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.fx.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(entry.icon, size: 20, color: context.fx.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: context.fx.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
