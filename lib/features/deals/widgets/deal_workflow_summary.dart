import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/services/deal_workflow_narrative.dart';
import 'package:flutter/material.dart';

class DealWorkflowSummary extends StatelessWidget {
  const DealWorkflowSummary({
    super.key,
    required this.deal,
    required this.legs,
  });

  final FxDeal deal;
  final List<FxDealLeg> legs;

  @override
  Widget build(BuildContext context) {
    final sections = DealWorkflowNarrative.buildSummary(deal: deal, legs: legs);
    final fx = context.fx;

    return FxObsidianReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT HAPPENED?',
            style: AppTypography.labelCaps(fx.primary, context: context),
          ),
          const SizedBox(height: 12),
          ...sections.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: AppTypography.bodyMd(
                      fx.onSurface,
                      context: context,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  ...s.lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 2),
                      child: Text(
                        '• $line',
                        style: AppTypography.bodyMd(
                          fx.onSurfaceVariant,
                          context: context,
                        ).copyWith(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
