import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_success_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FxSuccessFeedback shows snackbar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [FxColors.dark]),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () =>
                  FxSuccessFeedback.showSnack(context, 'Draft saved'),
              child: const Text('Trigger'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Trigger'));
    await tester.pump();
    expect(find.text('Draft saved'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
