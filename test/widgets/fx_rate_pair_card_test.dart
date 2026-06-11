import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/rates/fx_rate_pair_card.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rate pair card fits narrow width without overflow', (tester) async {
    final pair = RateBoardPair(
      pairLabel: 'USD/PKR',
      fromCurrency: 'USD',
      toCurrency: 'PKR',
      referenceRate: 280,
      buyRate: 278,
      sellRate: 280,
      source: 'manual_reference_rate_with_long_label',
      effectiveAt: DateTime(2026, 6, 10, 16, 15),
      lookupMethod: RateLookupMethod.directPkr,
    );

    await tester.binding.setSurfaceSize(const Size(180, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [FxColors.dark]),
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: FxRatePairCard(pair: pair, compact: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
