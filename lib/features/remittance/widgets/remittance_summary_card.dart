import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/core/widgets/premium/fx_status_badge.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RemittanceSummaryCard extends StatelessWidget {
  const RemittanceSummaryCard({super.key, required this.remittance, required this.fmt});

  final FxRemittance remittance;
  final NumberFormat fmt;

  static final _dtFmt = DateFormat('dd MMM yyyy, HH:mm');

  @override
  Widget build(BuildContext context) {
    return FxObsidianReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  remittance.remittanceNo ?? remittance.trackingId,
                  style: AppTypography.headlineSm(context.fx.onSurface, context: context),
                ),
              ),
              FxStatusBadge(label: remittance.status.label),
            ],
          ),
          if (remittance.trackingId != remittance.remittanceNo)
            Text('Tracking: ${remittance.trackingId}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
          const SizedBox(height: 12),
          _meta(context, 'Sender', remittance.senderName ?? '—'),
          _meta(context, 'Receiver', remittance.receiverName),
          if (remittance.receiverPhone != null) _meta(context, 'Receiver phone', remittance.receiverPhone!),
          _meta(context, 'Payout agent', remittance.payoutAgentName ?? 'Not assigned'),
          _meta(context, 'Branch', remittance.branchName ?? '—'),
          _meta(context, 'Created by', remittance.createdByName ?? '—'),
          if (remittance.createdAt != null) _meta(context, 'Created', _dtFmt.format(remittance.createdAt!.toLocal())),
          if (remittance.updatedAt != null) _meta(context, 'Last updated', _dtFmt.format(remittance.updatedAt!.toLocal())),
          if (remittance.payoutCode != null) _meta(context, 'Payout code', remittance.payoutCode!),
          const Divider(height: 24),
          _row(context, 'Receive', '${remittance.receiveCurrency} ${fmt.format(remittance.receiveAmount)}'),
          _row(context, 'Payout', '${remittance.payoutCurrency} ${fmt.format(remittance.payoutAmount)}'),
          _row(context, 'Commission', fmt.format(remittance.commissionAmount)),
          Text(remittance.commissionMode.label, style: AppTypography.bodyMd(context.fx.primary, context: context).copyWith(fontSize: 11)),
          const SizedBox(height: 8),
          _row(context, 'Total payable', fmt.format(remittance.totalPayable)),
          _row(context, 'Paid', fmt.format(remittance.paidAmount)),
          _row(context, 'Balance due', fmt.format(remittance.balanceDue), highlight: remittance.balanceDue > 0),
          _row(context, 'Settlement', remittance.settlementStatus.label),
          if (remittance.payoutMethod != null) _row(context, 'Payout method', remittance.payoutMethod!),
          if (remittance.payoutConfirmedAt != null)
            _row(context, 'Payout confirmed', RemittanceSummaryCard._dtFmt.format(remittance.payoutConfirmedAt!.toLocal())),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12))),
          Expanded(child: Text(value, style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
          Text(
            value,
            style: AppTypography.bodyMd(highlight ? context.fx.error : context.fx.onSurface, context: context)
                .copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
