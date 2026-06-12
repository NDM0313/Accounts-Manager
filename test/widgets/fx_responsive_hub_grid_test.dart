import 'package:accounts_manager/core/widgets/obsidian/fx_responsive_hub_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('crossAxisCountForWidth returns 2 on mobile', () {
    expect(FxResponsiveHubGrid.crossAxisCountForWidth(390), 2);
    expect(FxResponsiveHubGrid.crossAxisCountForWidth(719), 2);
  });

  test('crossAxisCountForWidth returns 3 on tablet', () {
    expect(FxResponsiveHubGrid.crossAxisCountForWidth(900), 3);
  });

  test('crossAxisCountForWidth returns 4 on desktop', () {
    expect(FxResponsiveHubGrid.crossAxisCountForWidth(1280), 4);
  });

  testWidgets('grid uses 2 columns at 390px width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: FxResponsiveHubGrid(
              itemCount: 4,
              mainAxisExtent: 132,
              itemBuilder: (_, i) => Container(key: Key('tile_$i')),
            ),
          ),
        ),
      ),
    );

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(delegate.mainAxisExtent, 132);
  });
}
