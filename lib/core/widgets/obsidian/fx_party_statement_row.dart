import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_ledger_table.dart';
import 'package:accounts_manager/core/widgets/premium/fx_proof_badge.dart';
import 'package:accounts_manager/core/widgets/premium/fx_status_badge.dart';
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
                      style: AppTypography.bodyMd(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ).copyWith(fontSize: 11),
                    ),
                  ),
                  Text(
                    line.transactionNo ?? line.transactionId.substring(0, 8),
                    style: AppTypography.labelMono(
                      context.fx.onSurface,
                      context: context,
                    ).copyWith(fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  FxStatusBadge(
                    label: line.status,
                    tone: FxStatusBadge.fromString(line.status),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FxTypeBadge(type: line.transactionType, compact: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line.narrative,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.dataMd(
                        context.fx.onSurface,
                        context: context,
                      ),
                    ),
                  ),
                  if (line.attachmentCount > 0)
                    FxProofBadge(count: line.attachmentCount),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dr ${fmt.format(line.debitPkr)}',
                      style: AppTypography.dataMd(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ).copyWith(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Cr ${fmt.format(line.creditPkr)}',
                      style: AppTypography.dataMd(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ).copyWith(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Bal ${fmt.format(line.runningBalancePkr)}',
                      textAlign: TextAlign.end,
                      style: AppTypography.dataMd(
                        context.fx.onSurface,
                        context: context,
                      ).copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FxPartySummaryCard extends StatelessWidget {
  const FxPartySummaryCard({
    super.key,
    required this.label,
    required this.value,
  });

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
          Text(
            label,
            style: AppTypography.labelCaps(
              context.fx.onSurfaceVariant,
              context: context,
            ).copyWith(fontSize: 9),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.bodyMd(
              context.fx.onSurface,
              context: context,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
