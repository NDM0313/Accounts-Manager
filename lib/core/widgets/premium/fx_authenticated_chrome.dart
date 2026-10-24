import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/premium/fx_main_nav_bar.dart';
import 'package:accounts_manager/core/widgets/system/fx_focused_flow.dart';
import 'package:accounts_manager/core/widgets/system/fx_workspace_navigation.dart';
import 'package:flutter/material.dart';

/// Bottom-nav chrome for flat (non-IndexedStack) authenticated routes.
///
/// Does not draw a second AppBar — child screens keep their own scaffold.
/// Desktop hides the bar to match [FxPremiumShell].
/// Focused create/review flows can hide the bottom nav via [FxFocusedFlowScope].
class FxAuthenticatedChrome extends StatelessWidget {
  const FxAuthenticatedChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hasRail = width >= FxLayoutBreakpoints.compact;
    final hideBottom = FxFocusedFlowScope.hidesBottomNav(context);
    return Scaffold(
      backgroundColor: context.fx.background,
      body: hasRail
          ? Row(
              children: [
                FxWorkspaceNavigation(
                  compact: !FxLayoutBreakpoints.isDesktop(width),
                ),
                Expanded(child: child),
              ],
            )
          : child,
      bottomNavigationBar: hasRail || hideBottom
          ? null
          : FxMainNavBar(
              // Flat stack: no tab selected (avoid false "Accounts"/Ledger highlight).
              selectedIndex: null,
              onDestinationSelected: (i) =>
                  FxMainNavDestinations.goTab(context, i),
            ),
    );
  }
}
