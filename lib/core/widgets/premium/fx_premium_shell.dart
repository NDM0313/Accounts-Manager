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
    final profile = ref.watch(currentProfileProvider).value;
    final isDemo = ref.watch(isDemoWorkspaceProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = FxLayoutBreakpoints.isDesktop(width);
    final initials = _initials(profile?.fullName ?? profile?.email);

    final topBar = Material(
      color: context.fx.surfaceContainerLowest,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.fx.outlineVariant),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop
              ? AppSpacing.marginDesktop
              : AppSpacing.marginMobile,
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                if (!isDesktop) ...[
                  Icon(
                    Icons.account_balance_wallet,
                    color: context.fx.secondary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'FX Cash Ledger',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineSm(
                        context.fx.primary,
                        context: context,
                      ).copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                const Spacer(),
                const WorkspaceSwitcherButton(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Refresh',
                  icon: Icon(Icons.refresh, color: context.fx.primary),
                  onPressed: () {
                    ref.invalidate(cashBalancesProvider);
                    ref.invalidate(ratesProvider);
                    ref.invalidate(dealsListProvider);
                  },
                ),
                if (profile != null)
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: context.fx.secondaryContainer,
                    child: Text(
                      initials,
                      style: AppTypography.labelCaps(
                        context.fx.onSecondaryContainer,
                        context: context,
                      ).copyWith(fontSize: 10),
                    ),
                  ),
              ],
            ),
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

    if (isDesktop) {
      return Scaffold(
        backgroundColor: context.fx.background,
        body: Row(
          children: [
            _DesktopSidebar(
              selectedIndex: navigationShell.currentIndex,
              onSelect: _goBranch,
            ),
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

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _items = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.handshake_outlined, Icons.handshake, 'Deals'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Ledger'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.fx.surfaceContainerLowest,
      child: Container(
        width: FxLayoutBreakpoints.sidebarWidth,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: context.fx.outlineVariant),
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: context.fx.secondary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'FX Cash Ledger',
                        style: AppTypography.headlineSm(
                          context.fx.primary,
                          context: context,
                        ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < _items.length; i++)
                _SideItem(
                  icon: selectedIndex == i ? _items[i].$2 : _items[i].$1,
                  label: _items[i].$3,
                  selected: selectedIndex == i,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected
            ? context.fx.secondary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? context.fx.secondary
                      : context.fx.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: AppTypography.bodyMd(
                    selected ? context.fx.secondary : context.fx.onSurface,
                    context: context,
                  ).copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    return FxContentContainer(
      padding: padding,
      child: child,
    );
  }
}
