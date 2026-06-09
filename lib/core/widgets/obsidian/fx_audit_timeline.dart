import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/domain/models/fx_audit_log.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FxAuditTimeline extends StatelessWidget {
  const FxAuditTimeline({super.key, required this.items});

  final List<AuditLogRow> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('d MMM, HH:mm');

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text('No audit events yet.', style: AppTypography.bodyMd(theme.colorScheme.onSurfaceVariant, context: context)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Stack(
        children: [
          Positioned(
            left: 11,
            top: 8,
            bottom: 8,
            child: Container(width: 1, color: context.fx.outlineVariant),
          ),
          Column(
            children: items.map((item) => _node(context, item, fmt)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _node(BuildContext context, AuditLogRow item, DateFormat fmt) {
    final theme = Theme.of(context);
    final (label, color, icon) = _actionStyle(item.action, theme);
    final diffs = item.changedFields.toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 32),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -32,
            top: 4,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: context.fx.surface,
                shape: BoxShape.circle,
                border: Border.all(color: context.fx.outlineVariant),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.fx.surfaceContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: context.fx.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _badge(context, label, color),
                    const SizedBox(width: 12),
                    Text(fmt.format(item.createdAt), style: AppTypography.bodyMd(theme.colorScheme.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.entityType} · ${item.action}',
                  style: AppTypography.bodyMd(theme.colorScheme.onSurface, context: context),
                ),
                if (item.reason != null && item.reason!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Reason', style: AppTypography.labelCaps(theme.colorScheme.onSurfaceVariant, context: context)),
                  const SizedBox(height: 4),
                  Text(
                    '"${item.reason!}"',
                    style: AppTypography.bodyMd(theme.colorScheme.onSurface, context: context).copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
                if (diffs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _diffPanel(context, diffs),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diffPanel(BuildContext context, List<MapEntry<String, (dynamic, dynamic)>> diffs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fx.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Field', style: AppTypography.labelCaps(context.fx.outline, context: context).copyWith(fontSize: 10))),
              Text('Change', style: AppTypography.labelCaps(context.fx.outline, context: context).copyWith(fontSize: 10)),
            ],
          ),
          for (final entry in diffs) ...[
            Divider(height: 16, color: context.fx.outlineVariant),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatFieldLabel(entry.key),
                    style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontSize: 13),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entry.value.$1 != null)
                      Text(
                        _formatValue(entry.value.$1),
                        style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    if (entry.value.$1 != null && entry.value.$2 != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 14, color: context.fx.outline),
                      const SizedBox(width: 8),
                    ],
                    if (entry.value.$2 != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.fx.tertiaryContainer.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: context.fx.tertiary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          _formatValue(entry.value.$2),
                          style: AppTypography.labelMono(context.fx.tertiary, context: context).copyWith(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatFieldLabel(String key) {
    return key.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  String _formatValue(dynamic value) {
    if (value == null) return '—';
    if (value is num) return NumberFormat('#,##0.##').format(value);
    return value.toString();
  }

  Widget _badge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: AppTypography.labelCaps(color, context: context).copyWith(fontSize: 10)),
    );
  }

  (String, Color, IconData) _actionStyle(String action, ThemeData theme) {
    final a = action.toLowerCase();
    if (a.contains('post') || a.contains('approv')) {
      return ('Approved', theme.colorScheme.tertiary, Icons.check_circle);
    }
    if (a.contains('edit') || a.contains('update')) {
      return ('Edited', theme.colorScheme.primary, Icons.edit);
    }
    if (a.contains('void') || a.contains('delet')) {
      return ('Voided', theme.colorScheme.error, Icons.delete_outline);
    }
    if (a.contains('clos')) {
      return ('Closed', theme.colorScheme.tertiary, Icons.lock);
    }
    return ('Created', theme.colorScheme.onSurfaceVariant, Icons.add_circle_outline);
  }
}
