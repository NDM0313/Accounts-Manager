import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:flutter/material.dart';

/// Stitch statement 2x2 balance summary grid.
class FxStitchBalanceGrid extends StatelessWidget {
  const FxStitchBalanceGrid({
    super.key,
    required this.cells,
  });

  final List<FxStitchBalanceCell> cells;

  @override
  Widget build(BuildContext context) {
    assert(cells.length == 4);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: cells.map((c) => _Cell(cell: c)).toList(),
    );
  }
}

class FxStitchBalanceCell {
  const FxStitchBalanceCell({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell});

  final FxStitchBalanceCell cell;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            cell.label.toUpperCase(),
            style: AppTypography.labelCaps(
              context.fx.onSurfaceVariant,
              context: context,
            ).copyWith(fontSize: 9),
          ),
          const SizedBox(height: 6),
          Text(
            cell.value,
            style: AppTypography.headlineSm(
              cell.valueColor ?? context.fx.onSurface,
              context: context,
            ).copyWith(fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
