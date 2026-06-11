import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum PremiumNav { home, ledger, accounts, audit, settings }

/// Main app shell: top bar + premium bottom navigation with active pill.
class FxPremiumShell extends ConsumerWidget {
  const FxPremiumShell({
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

  PremiumNav get _currentNav => PremiumNav.values[navigationShell.currentIndex];

  void _goBranch(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
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
                    Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      'Executive FX Ledger',
                      style: AppTypography.headlineSm(context.fx.onSurface, context: context).copyWith(fontSize: 17),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 40),
                      _navLink(context, PremiumNav.home, 'Dashboard'),
                      const SizedBox(width: 20),
                      _navLink(context, PremiumNav.ledger, 'Ledger'),
                      const SizedBox(width: 20),
                      _navLink(context, PremiumNav.accounts, 'Accounts'),
                      const SizedBox(width: 20),
                      _navLink(context, PremiumNav.audit, 'Audit'),
                      const SizedBox(width: 20),
                      _navLink(context, PremiumNav.settings, 'Settings'),
                    ],
                    const Spacer(),
                    if (profile != null)
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: context.fx.primary.withValues(alpha: 0.12),
                        child: Text(
                          initials,
                          style: AppTypography.labelCaps(context.fx.primary, context: context).copyWith(fontSize: 10),
                        ),
                      ),
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
                color: context.fx.surface,
                border: Border(top: BorderSide(color: context.fx.outlineVariant)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(_tabs.length, (i) {
                      final tab = _tabs[i];
                      final active = navigationShell.currentIndex == i;
                      return Expanded(
                        child: InkWell(
                          onTap: () => _goBranch(i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: active ? context.fx.primary.withValues(alpha: 0.12) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Icon(
                                  active ? tab.$2 : tab.$1,
                                  size: 22,
                                  color: active ? context.fx.primary : context.fx.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tab.$3,
                                style: AppTypography.bodyMd(
                                  active ? context.fx.primary : context.fx.onSurfaceVariant,
                                  context: context,
                                ).copyWith(fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.w500),
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

  Widget _navLink(BuildContext context, PremiumNav nav, String label) {
    final active = _currentNav == nav;
    return InkWell(
      onTap: () => _goBranch(PremiumNav.values.indexOf(nav)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.bodyMd(
              active ? context.fx.primary : context.fx.onSurfaceVariant,
              context: context,
            ).copyWith(fontWeight: active ? FontWeight.w600 : FontWeight.w500, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: active ? 24 : 0,
            decoration: BoxDecoration(
              color: context.fx.primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
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

/// Page content wrapper with max width.
class FxPremiumPage extends StatelessWidget {
  const FxPremiumPage({super.key, required this.child, this.padding});

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
          padding: padding ?? EdgeInsets.fromLTRB(horizontal, 16, horizontal, 16),
          child: child,
        ),
      ),
    );
  }
}
