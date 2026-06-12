import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_proof_badge.dart';
import 'package:accounts_manager/core/widgets/premium/fx_status_badge.dart';
import 'package:flutter/material.dart';

class FxStatementRow extends StatelessWidget {
  const FxStatementRow({
    super.key,
    required this.dateLabel,
    required this.referenceLabel,
    required this.statusLabel,
    required this.detailLine,
    required this.debitLabel,
    required this.creditLabel,
    required this.balanceLabel,
    this.proofCount = 0,
    this.onTap,
  });

  final String dateLabel;
  final String referenceLabel;
  final String statusLabel;
  final String detailLine;
  final String debitLabel;
  final String creditLabel;
  final String balanceLabel;
  final int proofCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
                      dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ).copyWith(fontSize: 11),
                    ),
                  ),
                  Text(
                    referenceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMono(
                      context.fx.onSurface,
                      context: context,
                    ).copyWith(fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  FxStatusBadge(
                    label: statusLabel,
                    tone: FxStatusBadge.fromString(statusLabel),
                  ),
                  if (proofCount > 0) ...[
                    const SizedBox(width: 6),
                    FxProofBadge(count: proofCount),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                detailLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.dataMd(
                  context.fx.onSurface,
                  context: context,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      debitLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.dataMd(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ).copyWith(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      creditLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.dataMd(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ).copyWith(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      balanceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
