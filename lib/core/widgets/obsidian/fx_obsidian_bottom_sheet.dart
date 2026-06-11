import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/utils/transaction_menu_entries.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FxObsidianBottomSheet {
  static void showTransactionTypes(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.85;
        final groups = buildTransactionMenuGroups();
        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: context.fx.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
            border: Border.all(color: context.fx.outlineVariant),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'NEW TRANSACTION',
                      style: AppTypography.labelCaps(context.fx.onSurfaceVariant, context: context),
                    ),
                  ),
                  for (final group in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          group.title.toUpperCase(),
                          style: AppTypography.labelCaps(context.fx.outline, context: context),
                        ),
                      ),
                    ),
                    for (final entry in group.entries)
                      _ActionRow(
                        icon: entry.icon,
                        label: entry.label,
                        onTap: () {
                          Navigator.pop(ctx);
                          context.push(entry.route);
                        },
                      ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.fx.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Icon(icon, color: context.fx.onSurface, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Icon(Icons.chevron_right, color: context.fx.outline),
            ],
          ),
        ),
      ),
    );
  }
}
