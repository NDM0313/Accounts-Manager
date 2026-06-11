import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RemittanceSummaryCard extends StatelessWidget {
  const RemittanceSummaryCard({super.key, required this.remittance, required this.fmt});

  final FxRemittance remittance;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return FxObsidianReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(remittance.status.label, style: AppTypography.labelCaps(context.fx.primary, context: context)),
          const SizedBox(height: 8),
          Text('Receiver: ${remittance.receiverName}', style: AppTypography.headlineSm(context.fx.onSurface, context: context)),
          if (remittance.receiverPhone != null)
            Text(remittance.receiverPhone!, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
          const Divider(height: 20),
          _row(context, 'Receive', '${remittance.receiveCurrency} ${fmt.format(remittance.receiveAmount)}'),
          _row(context, 'Payout', '${remittance.payoutCurrency} ${fmt.format(remittance.payoutAmount)}'),
          _row(context, 'Commission', fmt.format(remittance.commissionAmount)),
          _row(context, 'Total payable', fmt.format(remittance.totalPayable)),
          _row(context, 'Paid', fmt.format(remittance.paidAmount)),
          _row(context, 'Rate', fmt.format(remittance.exchangeRate)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
          Text(value, style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
