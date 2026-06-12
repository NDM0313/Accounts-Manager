import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_hub_tile.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_responsive_hub_grid.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReportsHubScreen extends StatefulWidget {
  const ReportsHubScreen({super.key});

  static const reports = [
    (
      'Chart of Accounts',
      'Read-only COA from fx_accounts',
      Icons.account_tree_outlined,
      '/accounts',
    ),
    (
      'General Ledger',
      'Posted journal entries',
      Icons.menu_book_outlined,
      '/reports/general-ledger',
    ),
    (
      'Trial Balance',
      'Account balances as of date',
      Icons.balance_outlined,
      '/reports/trial-balance',
    ),
    (
      'Profit & Loss',
      'Income and expenses',
      Icons.trending_up_outlined,
      '/reports/profit-loss',
    ),
    (
      'Balance Sheet',
      'Assets, liabilities, equity',
      Icons.account_balance_outlined,
      '/reports/balance-sheet',
    ),
    (
      'Currency Position',
      'Foreign currency exposure',
      Icons.public_outlined,
      '/reports/currency-position',
    ),
    (
      'Manual Journal',
      'Post balanced journal entry',
      Icons.edit_note_outlined,
      '/journal/new',
    ),
    (
      'Parties',
      'Customers, agents, settlements',
      Icons.people_outline,
      '/parties',
    ),
    (
      'Agent Ledger',
      'Settlement agents',
      Icons.support_agent_outlined,
      '/parties/agents',
    ),
    (
      'Daily Closing',
      'Close the day\'s session',
      Icons.lock_clock_outlined,
      '/closing',
    ),
    (
      'Remittance',
      'Hawala / payout orders',
      Icons.public_outlined,
      '/remittance',
    ),
    (
      'Team Messages',
      'Internal staff chat',
      Icons.chat_bubble_outline,
      '/messages',
    ),
    (
      'Audit Log',
      'Change history',
      Icons.history_outlined,
      '/reports/audit-log',
    ),
  ];

  @override
  State<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends State<ReportsHubScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final horizontal = isDesktop
        ? AppSpacing.marginDesktop
        : AppSpacing.marginMobile;

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: context.fx.background,
      ),
      body: isDesktop ? _desktopLayout(horizontal) : _mobileLayout(horizontal),
    );
  }

  Widget _desktopLayout(double horizontal) {
    final (title, subtitle, icon, _) = ReportsHubScreen.reports[_selectedIndex];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 280,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: context.fx.outlineVariant)),
          ),
          child: ListView(
            padding: EdgeInsets.fromLTRB(horizontal, 24, 16, 24),
            children: [
              Text(
                'Reports',
                style: AppTypography.headlineMd(
                  context.fx.onSurface,
                  context: context,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Financial reports and daily closing.',
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 12),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < ReportsHubScreen.reports.length; i++)
                _sidebarItem(i),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(32, 24, horizontal, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.fx.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.headlineMd(
                              context.fx.onSurface,
                              context: context,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: AppTypography.bodyMd(
                              context.fx.onSurfaceVariant,
                              context: context,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () => context.push(
                        ReportsHubScreen.reports[_selectedIndex].$4,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.fx.primary,
                        foregroundColor: context.fx.onPrimary,
                      ),
                      child: const Text('Open report'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Expanded(child: _reportGrid(crossCount: 2)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sidebarItem(int index) {
    final (title, _, icon, route) = ReportsHubScreen.reports[index];
    final selected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? context.fx.surfaceContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          onHover: (hover) {},
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: selected ? context.fx.outline : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? context.fx.primary
                      : context.fx.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style:
                        AppTypography.bodyMd(
                          selected
                              ? context.fx.onSurface
                              : context.fx.onSurfaceVariant,
                          context: context,
                        ).copyWith(
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                  ),
                ),
                if (selected)
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    color: context.fx.primary,
                    onPressed: () => context.push(route),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileLayout(double horizontal) {
    return ListView(
      padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
      children: [
        Text(
          'Financial reports and daily closing for your branch.',
          style: AppTypography.bodyMd(
            context.fx.onSurfaceVariant,
            context: context,
          ),
        ),
        const SizedBox(height: 24),
        _reportGrid(
          crossCount: MediaQuery.sizeOf(context).width >= 720 ? 2 : 1,
        ),
      ],
    );
  }

  Widget _reportGrid({required int crossCount}) {
    return FxResponsiveHubGrid(
      itemCount: ReportsHubScreen.reports.length,
      mainAxisExtent: crossCount == 2 ? 132 : 120,
      itemBuilder: (context, i) {
        final (title, subtitle, icon, route) = ReportsHubScreen.reports[i];
        return FxHubTile(
          title: title,
          subtitle: subtitle,
          icon: icon,
          onTap: () => context.push(route),
          compact: true,
        );
      },
    );
  }
}
