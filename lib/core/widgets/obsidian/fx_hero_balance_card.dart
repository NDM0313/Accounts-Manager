import 'package:accounts_manager/core/widgets/premium/fx_amount_card.dart';
import 'package:flutter/material.dart';

class FxHeroBalanceCard extends StatelessWidget {
  const FxHeroBalanceCard({
    super.key,
    required this.amountLabel,
    this.trendLabel,
    this.onQuickAdd,
    this.onExport,
  });

  final String amountLabel;
  final String? trendLabel;
  final VoidCallback? onQuickAdd;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return FxAmountCard(
      label: 'Total Net Balance (Estimated)',
      amountLabel: amountLabel,
      trendLabel: trendLabel,
      onPrimaryAction: onQuickAdd,
      primaryActionLabel: 'Quick add',
      primaryActionIcon: Icons.add,
      onSecondaryAction: onExport,
      secondaryActionLabel: 'Export',
      secondaryActionIcon: Icons.ios_share,
    );
  }
}
