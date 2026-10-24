import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/app/theme/fx_design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One route inventory for desktop sidebar and tablet rail, including details.
class FxWorkspaceNavigation extends StatelessWidget {
  const FxWorkspaceNavigation({super.key, required this.compact});
  final bool compact;

  static const destinations = <(String, String, IconData)>[
    ('/', 'Home', Icons.home_outlined),
    ('/deals', 'Deals', Icons.receipt_long_outlined),
    ('/parties', 'Parties', Icons.people_outline),
    ('/accounts-hub', 'Accounts', Icons.account_balance_wallet_outlined),
    ('/reports/roznamcha', 'Daily book', Icons.menu_book_outlined),
    ('/expenses', 'Expenses', Icons.receipt_outlined),
    ('/reports', 'Reports', Icons.bar_chart_outlined),
    ('/messages', 'Team', Icons.chat_bubble_outline),
    ('/audit', 'Audit', Icons.verified_user_outlined),
    ('/settings', 'Settings', Icons.tune),
  ];

  static String selectedDestination(String path) {
    if (path.startsWith('/accounts') ||
        path.startsWith('/ledger') ||
        path.startsWith('/opening-balances') ||
        path.startsWith('/journal')) {
      return '/accounts-hub';
    }
    final ordered = [...destinations]
      ..sort((a, b) => b.$1.length.compareTo(a.$1.length));
    for (final item in ordered) {
      if (path == item.$1 ||
          (item.$1 != '/' && path.startsWith('${item.$1}/'))) {
        return item.$1;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedDestination(GoRouterState.of(context).uri.path);
    return Material(
      color: context.fxNavigation,
      child: SizedBox(
        width: compact ? 80 : FxLayoutBreakpoints.sidebarWidth,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 20,
              vertical: 24,
            ),
            children: [
              Text(
                compact ? 'FX' : 'FX / LEDGER',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: AppTypography.headlineSm(Colors.white),
              ),
              const SizedBox(height: 24),
              for (final item in destinations) ...[
                Tooltip(
                  message: item.$2,
                  child: Semantics(
                    label: item.$2,
                    selected: selected == item.$1,
                    button: true,
                    child: Material(
                      color: selected == item.$1
                          ? const Color(0xFF2563EB)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => context.go(item.$1),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: compact
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                Icon(
                                  item.$3,
                                  size: 20,
                                  color: context.fxNavigationText,
                                ),
                                if (!compact) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.$2,
                                      style: AppTypography.bodySm(Colors.white),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
