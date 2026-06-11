import 'package:flutter/material.dart';

class FxResponsiveGrid extends StatelessWidget {
  const FxResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 160,
    this.spacing = 12,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var columns = (width / minTileWidth).floor().clamp(1, maxColumns);
        if (width >= 900 && columns < 2) columns = 2;
        final tileWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}
