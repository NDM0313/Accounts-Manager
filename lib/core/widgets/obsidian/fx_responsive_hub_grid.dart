import 'package:flutter/material.dart';

/// Responsive hub grid: 2 cols mobile, 3 tablet, 4 desktop; fixed compact row height.
class FxResponsiveHubGrid extends StatelessWidget {
  const FxResponsiveHubGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.mainAxisExtent = 132,
    this.spacing = 12,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double mainAxisExtent;
  final double spacing;

  static int crossAxisCountForWidth(double width) {
    if (width >= 1200) return 4;
    if (width >= 720) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = crossAxisCountForWidth(constraints.maxWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: mainAxisExtent,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
