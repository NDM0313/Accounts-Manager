import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('fxSafePop pops when navigator can pop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FxPageScaffold(
                    fallbackRoute: '/fallback',
                    title: const Text('Child'),
                    body: ElevatedButton(
                      onPressed: () => fxSafePop(context, fallbackRoute: '/fallback'),
                      child: const Text('Back'),
                    ),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Child'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('FxPageScaffold shows back arrow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FxPageScaffold(
          fallbackRoute: '/deals',
          title: const Text('Deal'),
          body: const Text('Body'),
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('Deal'), findsOneWidget);
  });

  testWidgets('FxPageScaffold back uses go when cannot pop', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox(key: Key('home'))),
        GoRoute(
          path: '/detail',
          builder: (_, _) => FxPageScaffold(
            fallbackRoute: '/',
            title: const Text('Detail'),
            body: const Text('Detail body'),
          ),
        ),
      ],
      initialLocation: '/detail',
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Detail body'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home')), findsOneWidget);
  });
}
