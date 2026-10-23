import 'package:accounts_manager/app/theme/fx_design_tokens.dart';
import 'package:accounts_manager/core/widgets/system/fx_appearance_button.dart';
import 'package:accounts_manager/core/widgets/system/fx_workspace_navigation.dart';
import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/demo_workspace_banner.dart';
import 'package:accounts_manager/core/widgets/premium/fx_main_nav_bar.dart';
import 'package:accounts_manager/core/widgets/system/fx_content_container.dart';
import 'package:accounts_manager/core/widgets/workspace_switcher.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

export 'package:accounts_manager/core/widgets/premium/fx_main_nav_bar.dart'
    show PremiumNav;

/// Main app shell: desktop sidebar + compact top bar; mobile bottom nav.
class FxPremiumShell extends ConsumerWidget {
  const FxPremiumShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoWorkspaceProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = FxLayoutBreakpoints.isDesktop(width);
    final topBar = Material(
      color: context.fx.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              Expanded(
                child: Text(
                  [
                    'Home',
                    'Deals',
                    'Accounts',
                    'Reports',
                    'More',
                  ][navigationShell.currentIndex],
                  style: AppTypography.headlineSm(context.fx.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Scan payment slip',
                color: context.fxAccent(FxAccent.scan),
                icon: const Icon(Icons.document_scanner_outlined),
                onPressed: () => context.push('/slips/import'),
              ),
              WorkspaceSwitcherButton(iconOnly: width < 600),
              const FxAppearanceButton(),
            ],
          ),
        ),
      ),
    );

    final content = Column(
      children: [
        if (isDemo) const DemoWorkspaceBanner(),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: FxLayoutBreakpoints.contentMax,
              ),
              child: navigationShell,
            ),
          ),
        ),
      ],
    );

    if (width >= FxLayoutBreakpoints.compact) {
      return Scaffold(
        backgroundColor: context.fx.background,
        body: Row(
          children: [
            FxWorkspaceNavigation(compact: !isDesktop),
            Expanded(
              child: Column(
                children: [
                  topBar,
                  Expanded(child: content),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: topBar,
      ),
      body: content,
      bottomNavigationBar: FxMainNavBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
      ),
    );
  }
}

/// Page content wrapper with max width.
class FxPremiumPage extends StatelessWidget {
  const FxPremiumPage({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return FxContentContainer(padding: padding, child: child);
  }
}
