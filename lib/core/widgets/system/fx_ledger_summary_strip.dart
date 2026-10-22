import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/core/widgets/system/fx_money_label.dart';
import 'package:flutter/material.dart';

/// Compact Opening | Debits | Credits | Closing strip (content height ~90–120px).
class FxLedgerSummaryStrip extends StatelessWidget {
  const FxLedgerSummaryStrip({
    super.key,
    required this.opening,
    required this.periodDebits,
    required this.periodCredits,
    required this.closing,
    this.currencyCode = 'PKR',
    this.periodLabel,
  });

  final double opening;
  final double periodDebits;
  final double periodCredits;
  final double closing;
  final String currencyCode;
  final String? periodLabel;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= FxLayoutBreakpoints.compact;
    final cells = [
      _cell(context, 'Opening', opening),
      _cell(context, 'Period debits', periodDebits),
      _cell(context, 'Period credits', periodCredits),
      _cell(context, 'Closing', closing, bold: true),
    ];

    return FxStitchCard(
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (periodLabel != null) ...[
            Text(
              periodLabel!,
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.stackSm),
          ],
          if (wide)
            Row(
              children: [
                for (var i = 0; i < cells.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 40,
                      color: context.fx.outlineVariant,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  Expanded(child: cells[i]),
                ],
              ],
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.stackSm,
              crossAxisSpacing: AppSpacing.stackSm,
              childAspectRatio: 2.6,
              children: cells,
            ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    String label,
    double amount, {
    bool bold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.bodyMd(
            context.fx.onSurfaceVariant,
            context: context,
          ).copyWith(fontSize: 12),
        ),
        const SizedBox(height: 4),
        FxMoneyLabel(
          amount: amount,
          currencyCode: currencyCode,
          bold: bold,
          fontSize: 14,
          align: TextAlign.start,
        ),
      ],
    );
  }
}
