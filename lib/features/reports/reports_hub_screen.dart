import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_reports_hub_widgets.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ReportsHubScreen extends ConsumerStatefulWidget {
  const ReportsHubScreen({super.key});

  static const reports = [
    (
      'Trial Balance',
      'Comprehensive listing of all ledger balances for audit reconciliation.',
      Icons.account_balance,
      '/reports/trial-balance',
      false,
    ),
    (
      'Profit & Loss',
      'Summary of revenues, costs, and expenses during a specific period.',
      Icons.trending_up,
      '/reports/profit-loss',
      true,
    ),
    (
      'Balance Sheet',
      'Financial position including assets, liabilities, and equity.',
      Icons.account_balance_wallet,
      '/reports/balance-sheet',
      false,
    ),
    (
      'General Ledger',
      'Detailed record of all transactions categorized by account.',
      Icons.menu_book,
      '/reports/general-ledger',
      false,
    ),
    (
      'Customer Statements',
      'Transaction history and outstanding balances for key accounts.',
      Icons.person,
      '/parties',
      false,
    ),
    (
      'Agent Statements',
      'Detailed breakdown of agent commissions and deal volume.',
      Icons.support_agent,
      '/parties/agents',
      false,
    ),
    (
      'Currency Position',
      'Real-time exposure and balances across all active FX currencies.',
      Icons.currency_exchange,
      '/reports/currency-position',
      false,
    ),
    (
      'Chart of Accounts',
      'Read-only chart of accounts from branch ledger.',
      Icons.account_tree_outlined,
      '/accounts',
      false,
    ),
    (
      'Manual Journal',
      'Post a balanced journal entry.',
      Icons.edit_note_outlined,
      '/journal/new',
      false,
    ),
    (
      'Daily Closing',
      'End-of-day summary and automated ledger reconciliation checks.',
      Icons.event_available,
      '/closing',
      true,
    ),
    (
      'Remittance',
      'Hawala / payout orders and settlement tracking.',
      Icons.public_outlined,
      '/remittance',
      false,
    ),
    (
      'Team Messages',
      'Internal staff chat and deal coordination.',
      Icons.chat_bubble_outline,
      '/messages',
      false,
    ),
    (
      'Audit Log',
      'Change history and compliance trail.',
      Icons.history_outlined,
      '/reports/audit-log',
      false,
    ),
  ];

  @override
  ConsumerState<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends ConsumerState<ReportsHubScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final horizontal = MediaQuery.sizeOf(context).width >= 900
        ? AppSpacing.marginDesktop
        : AppSpacing.marginMobile;

    final filtered = ReportsHubScreen.reports
        .where(
          (r) =>
              _query.isEmpty ||
              r.$1.toLowerCase().contains(_query.toLowerCase()) ||
              r.$2.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.surface,
        foregroundColor: context.fx.primary,
        title: Text(
          'Reports',
          style: AppTypography.headlineSm(
            context.fx.primary,
            context: context,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: profileAsync.when(
              loading: () => const SizedBox(width: 32, height: 32),
              error: (_, _) => const SizedBox.shrink(),
              data: (profile) {
                final name = profile?.fullName ?? 'U';
                final initials = name
                    .split(' ')
                    .map((p) => p.isNotEmpty ? p[0] : '')
                    .take(2)
                    .join()
                    .toUpperCase();
                return CircleAvatar(
                  radius: 16,
                  backgroundColor: context.fx.secondaryContainer,
                  child: Text(
                    initials,
                    style: AppTypography.labelCaps(
                      context.fx.onSecondaryContainer,
                      context: context,
                    ).copyWith(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: FxStitchScaffold(
        padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FxStitchReportsHero(
              searchController: _searchCtrl,
              onSearchChanged: (v) => setState(() => _query = v.trim()),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 900
                    ? 3
                    : c.maxWidth >= 600
                        ? 2
                        : 1;
                final gap = 12.0;
                final w = (c.maxWidth - (cols - 1) * gap) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final r in filtered)
                      SizedBox(
                        width: cols == 1 ? c.maxWidth : w,
                        child: FxStitchReportHubCard(
                          title: r.$1,
                          subtitle: r.$2,
                          icon: r.$3,
                          iconBackground: r.$5
                              ? context.fx.tertiaryContainer
                              : r.$1 == 'Daily Closing'
                                  ? context.fx.errorContainer
                                  : context.fx.surfaceContainerHigh,
                          iconColor: r.$5
                              ? context.fx.tertiaryFixedDim
                              : r.$1 == 'Daily Closing'
                                  ? context.fx.error
                                  : context.fx.secondary,
                          onTap: () => context.push(r.$4),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const FxStitchReportsCustomAnalyticsBanner(),
          ],
        ),
      ),
    );
  }
}
