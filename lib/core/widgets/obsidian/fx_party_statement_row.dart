import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_ledger_table.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FxPartyStatementRow extends StatelessWidget {
  const FxPartyStatementRow({
    super.key,
    required this.line,
    required this.onTap,
  });

  final PartyStatementLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('d MMM yyyy');

    return Material(
      color: context.fx.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dateFmt.format(line.transactionDate),
                      style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11),
                    ),
                  ),
                  Text(
                    line.transactionNo ?? line.transactionId.substring(0, 8),
                    style: AppTypography.labelMono(context.fx.onSurface, context: context).copyWith(fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(status: line.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FxTypeBadge(type: line.transactionType, compact: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${fmt.format(line.foreignAmount)} ${line.currencyCode}',
                      style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (line.hasAttachment)
                    Icon(Icons.attach_file, size: 16, color: context.fx.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dr ${fmt.format(line.debitPkr)}',
                      style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Cr ${fmt.format(line.creditPkr)}',
                      style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Bal ${fmt.format(line.runningBalancePkr)}',
                      textAlign: TextAlign.end,
                      style: AppTypography.labelMono(context.fx.onSurface, context: context).copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Rate ${fmt.format(line.rateUsed)} · PKR ${fmt.format(line.pkrEquivalent)}',
                style: AppTypography.bodyMd(context.fx.outline, context: context).copyWith(fontSize: 10),
              ),
              if (line.description != null && line.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  line.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 10),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'posted' => context.fx.tertiary,
      'draft' => context.fx.onSurfaceVariant,
      'voided' => context.fx.error,
      _ => context.fx.outline,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: AppTypography.labelCaps(color, context: context).copyWith(fontSize: 8),
      ),
    );
  }
}

class FxPartySummaryCard extends StatelessWidget {
  const FxPartySummaryCard({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelCaps(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 9)),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
