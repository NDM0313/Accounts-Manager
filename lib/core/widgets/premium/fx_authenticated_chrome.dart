import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/premium/fx_main_nav_bar.dart';
import 'package:flutter/material.dart';

/// Bottom-nav chrome for flat (non-IndexedStack) authenticated routes.
///
/// Does not draw a second AppBar — child screens keep their own scaffold.
/// Desktop (≥900) hides the bar to match [FxPremiumShell].
class FxAuthenticatedChrome extends StatelessWidget {
  const FxAuthenticatedChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: context.fx.background,
      body: child,
      bottomNavigationBar: isDesktop
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
