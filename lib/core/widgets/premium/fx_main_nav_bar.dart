import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum PremiumNav { home, deals, ledger, reports, settings }

/// Shared 5-tab destinations for shell IndexedStack and flat-route chrome.
class FxMainNavDestinations {
  FxMainNavDestinations._();

  static const tabs = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.sync_alt, Icons.sync_alt, 'Deals'),
    (
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
      'Ledger',
    ),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  static const paths = <String>[
    '/',
    '/deals',
    '/ledger',
    '/reports',
    '/settings',
  ];

  static void goTab(BuildContext context, int index) {
    if (index < 0 || index >= paths.length) return;
    context.go(paths[index]);
  }
}

/// Bottom tab bar used by [FxPremiumShell] and [FxAuthenticatedChrome].
class FxMainNavBar extends StatelessWidget {
  const FxMainNavBar({
    super.key,
    required this.onDestinationSelected,
    this.selectedIndex,
  });

  /// When null, no tab is highlighted (flat deep-link stack outside shell).
  final int? selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final tabs = FxMainNavDestinations.tabs;
    return Container(
      decoration: BoxDecoration(
        color: context.fx.surface,
        border: Border(top: BorderSide(color: context.fx.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final active = selectedIndex == i;
              return Expanded(
                child: InkWell(
                  onTap: () => onDestinationSelected(i),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: active
                              ? context.fx.secondary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          active ? tab.$2 : tab.$1,
                          size: 22,
                          color: active
                              ? context.fx.secondary
                              : context.fx.onSurfaceVariant,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab.$3.toUpperCase(),
                          style: AppTypography.labelCaps(
                            active
                                ? context.fx.secondary
                                : context.fx.onSurfaceVariant,
                            context: context,
                          ).copyWith(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
