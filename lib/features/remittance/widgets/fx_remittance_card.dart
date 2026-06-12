import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_status_badge.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Premium list row for branch and agent remittance inboxes.
class FxRemittanceCard extends StatelessWidget {
  const FxRemittanceCard({
    super.key,
    required this.remittance,
    required this.fmt,
    this.onTap,
    this.subtitle,
    this.showBalanceDue = false,
  });

  final FxRemittance remittance;
  final NumberFormat fmt;
  final VoidCallback? onTap;
  final String? subtitle;
  final bool showBalanceDue;

  String? get _pendingAction {
    if (remittance.status == FxRemittanceStatus.booked &&
        remittance.balanceDue > 0) {
      return 'Receive payment';
    }
    if (remittance.status == FxRemittanceStatus.customerPaid &&
        remittance.isFullyPaid) {
      return 'Send to agent';
    }
    if (remittance.status == FxRemittanceStatus.sentToAgent ||
        remittance.status == FxRemittanceStatus.readyForPayout) {
      return 'Confirm payout';
    }
    if (remittance.status == FxRemittanceStatus.paidOut) {
      return 'Mark settled';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingAction;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FxPremiumCard(
        padding: const EdgeInsets.all(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      remittance.remittanceNo ?? remittance.trackingId,
                      style: AppTypography.headlineSm(
                        context.fx.onSurface,
                        context: context,
                      ).copyWith(fontSize: 14),
                    ),
                  ),
                  FxStatusBadge(
                    label: remittance.status.label,
                    tone: FxStatusBadge.fromString(remittance.status.dbValue),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle ?? 'To: ${remittance.receiverName}',
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '${remittance.receiveCurrency} ${fmt.format(remittance.receiveAmount)} → ${remittance.payoutCurrency} ${fmt.format(remittance.payoutAmount)}',
                style: AppTypography.dataMd(
                  context.fx.onSurface,
                  context: context,
                ).copyWith(fontSize: 12),
              ),
              if (showBalanceDue && remittance.balanceDue > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Balance due: ${remittance.receiveCurrency} ${fmt.format(remittance.balanceDue)}',
                  style: AppTypography.bodyMd(
                    context.fx.error,
                    context: context,
                  ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
              if (pending != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.pending_actions_outlined,
                      size: 14,
                      color: context.fx.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pending,
                      style: AppTypography.bodyMd(
                        context.fx.secondary,
                        context: context,
                      ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
