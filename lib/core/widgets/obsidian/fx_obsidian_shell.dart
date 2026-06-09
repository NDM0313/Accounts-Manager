import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum ObsidianNav { home, ledger, accounts, audit, settings }

class FxObsidianShell extends ConsumerWidget {
  const FxObsidianShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Home'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Ledger'),
    (Icons.account_balance_outlined, Icons.account_balance, 'Accounts'),
    (Icons.history_outlined, Icons.history, 'Audit'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  ObsidianNav get _currentNav => ObsidianNav.values[navigationShell.currentIndex];

  void _goBranch(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  void _goNav(ObsidianNav nav) {
    _goBranch(ObsidianNav.values.indexOf(nav));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final initials = _initials(profile?.fullName ?? profile?.email);

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Material(
          color: context.fx.surface,
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.fx.outlineVariant)),
            ),
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? AppSpacing.marginDesktop : AppSpacing.marginMobile),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Text('FX Ledger', style: AppTypography.headlineMd(context.fx.onSurface, context: context)),
                    if (isDesktop) ...[
                      const SizedBox(width: 48),
                      _navLink(context, ObsidianNav.home, 'DASHBOARD'),
                      const SizedBox(width: 24),
                      _navLink(context, ObsidianNav.ledger, 'LEDGER'),
                      const SizedBox(width: 24),
                      _navLink(context, ObsidianNav.accounts, 'ACCOUNTS'),
                      const SizedBox(width: 24),
                      _navLink(context, ObsidianNav.audit, 'AUDIT'),
                      const SizedBox(width: 24),
                      _navLink(context, ObsidianNav.settings, 'SETTINGS'),
                    ],
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      color: context.fx.onSurfaceVariant,
                      onPressed: () {},
                    ),
                    if (profile != null) ...[
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: context.fx.surfaceContainerHigh,
                        child: Text(initials, style: AppTypography.labelCaps(context.fx.onSurface, context: context).copyWith(fontSize: 11)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: navigationShell,
      bottomNavigationBar: isDesktop
          ? null
          : Container(
              decoration: BoxDecoration(
                color: context.fx.surfaceContainerLowest,
                border: Border(top: BorderSide(color: context.fx.outlineVariant)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(_tabs.length, (i) {
                      final tab = _tabs[i];
                      final active = navigationShell.currentIndex == i;
                      return InkWell(
                        onTap: () => _goBranch(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                active ? tab.$2 : tab.$1,
                                color: active ? context.fx.onSurface : context.fx.onSurfaceVariant,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tab.$3.toUpperCase(),
                                style: AppTypography.labelCaps(
                                  active ? context.fx.onSurface : context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 10, letterSpacing: 0.08),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _navLink(BuildContext context, ObsidianNav nav, String label) {
    final active = _currentNav == nav;
    return InkWell(
      onTap: () => _goNav(nav),
      child: Text(
        label,
        style: AppTypography.labelCaps(
          active ? Theme.of(context).colorScheme.primary : context.fx.onSurfaceVariant, context: context).copyWith(
          letterSpacing: 0.12,
          decoration: active ? TextDecoration.underline : null,
          decorationColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class FxObsidianPage extends StatelessWidget {
  const FxObsidianPage({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final horizontal = w >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.containerMax),
        child: Padding(
          padding: padding ?? EdgeInsets.fromLTRB(horizontal, 24, horizontal, 24),
          child: child,
        ),
      ),
    );
  }
}
