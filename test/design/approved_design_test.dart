import 'package:accounts_manager/app/theme/app_theme.dart';
import 'package:accounts_manager/app/theme/fx_design_tokens.dart';
import 'package:accounts_manager/core/widgets/system/fx_confirmation_emblem.dart';
import 'package:accounts_manager/core/widgets/system/fx_form_section.dart';
import 'package:accounts_manager/core/widgets/system/fx_workspace_navigation.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('most specific navigation destination wins', () {
    expect(
      FxWorkspaceNavigation.selectedDestination('/reports/roznamcha'),
      '/reports/roznamcha',
    );
    expect(
      FxWorkspaceNavigation.selectedDestination('/reports/general-ledger'),
      '/reports',
    );
    expect(
      FxWorkspaceNavigation.selectedDestination('/parties/123/ledger'),
      '/parties',
    );
    expect(
      FxWorkspaceNavigation.selectedDestination('/accounts/new-cash'),
      '/accounts-hub',
    );
  });
  test('appearance preference survives a new provider container', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    first.read(themeModeProvider.notifier).set(ThemeMode.dark);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(first.read(themeModeProvider), ThemeMode.dark);
    first.dispose();
    final second = ProviderContainer();
    second.read(themeModeProvider);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(second.read(themeModeProvider), ThemeMode.dark);
    second.dispose();
  });
  for (final dark in [false, true]) {
    for (final width in [390.0, 834.0, 1440.0]) {
      testWidgets('form renders at $width / dark=$dark with readable accents', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  for (final accent in FxAccent.values) {
                    final a = context.fxAccent(accent).computeLuminance();
                    final b = context
                        .fxAccentSurface(accent)
                        .computeLuminance();
                    final contrast =
                        (a > b ? a + .05 : b + .05) /
                        (a > b ? b + .05 : a + .05);
                    expect(contrast, greaterThanOrEqualTo(4.5));
                  }
                  return const Center(
                    child: SizedBox(
                      width: 740,
                      child: FxFormSection(
                        title: 'Who is paying you?',
                        children: [
                          TextField(
                            decoration: InputDecoration(labelText: 'Customer'),
                          ),
                          TextField(
                            decoration: InputDecoration(labelText: 'Amount'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Who is paying you?'), findsOneWidget);
      });
    }
  }
  testWidgets('confirmation respects reduced motion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: FxConfirmationEmblem(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
