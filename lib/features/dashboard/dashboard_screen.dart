import 'package:accounts_manager/app/theme/fx_design_tokens.dart';
import 'package:intl/intl.dart';
import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_currency_position_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_marquee_rate_strip.dart';
import 'package:accounts_manager/core/widgets/premium/fx_next_action_row.dart';
import 'package:accounts_manager/core/widgets/premium/fx_responsive_grid.dart';
import 'package:accounts_manager/core/widgets/premium/fx_section_header.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/features/dashboard/dashboard_kpi_row.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesAsync = ref.watch(ratesProvider);
    final kpiAsync = ref.watch(dashboardKpiProvider);
    final todayPlAsync = ref.watch(todayProfitLossProvider);
    final positionAsync = ref.watch(currencyPositionProvider);
    final dealsAsync = ref.watch(dealsListProvider);
    // Desktop content uses shared insets; sidebar lives in FxPremiumShell.
    final horizontal = context.fxHorizontalInset;

    final bottomInset =
        MediaQuery.paddingOf(context).bottom + AppSpacing.shellBottomInset;
    return ColoredBox(
      color: context.fx.background,
      child: ListView(
        padding: EdgeInsets.only(bottom: bottomInset),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your money. Clear.',
                  style: AppTypography.headlineLg(context.fx.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, d MMMM').format(DateTime.now()),
                  style: AppTypography.bodyMd(context.fx.onSurfaceVariant),
                ),
              ],
            ),
          ),
          ratesAsync.when(
            data: (rates) => FxMarqueeRateStrip(rates: rates),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              AppSpacing.stackMd,
              horizontal,
              0,
            ),
            child: DashboardKpiRow(
              kpi: kpiAsync.whenOrNull(data: (v) => v),
              todayPl: todayPlAsync.whenOrNull(data: (v) => v),
            ),
          ),
          const SizedBox(height: AppSpacing.stackMd),
          _quickActions(context, horizontal),
          const SizedBox(height: AppSpacing.stackLg),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            child: _currencyPositionSection(context, positionAsync),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            child: _nextActionsSection(context, dealsAsync),
          ),
          const SizedBox(height: AppSpacing.stackLg),
        ],
      ),
    );
  }

  Widget _quickActions(BuildContext context, double horizontal) {
    final actions = <(String, IconData, FxAccent, String)>[
      (
        'Receive',
        Icons.south_west,
        FxAccent.receive,
        '/transactions/money?direction=receive&mode=customer_receipt',
      ),
      (
        'Pay',
        Icons.north_east,
        FxAccent.pay,
        '/transactions/money?direction=pay&mode=agent_payment',
      ),
      (
        'Buy FX',
        Icons.swap_horiz,
        FxAccent.brand,
        '/transactions/new?type=currency_buy',
      ),
      (
        'Scan slip',
        Icons.document_scanner_outlined,
        FxAccent.scan,
        '/slips/import',
      ),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      child: FxStitchCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quick actions',
              style: AppTypography.headlineSm(context.fx.onSurface),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 680
                    ? 4
                    : constraints.maxWidth >= 270
                    ? 2
                    : 1;
                final tileWidth =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in actions)
                      SizedBox(
                        width: tileWidth,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            foregroundColor: context.fxAccent(item.$3),
                            backgroundColor: context.fxAccentSurface(item.$3),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: () => context.push(item.$4),
                          icon: Icon(item.$2, size: 20),
                          label: Text(item.$1),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _currencyPositionSection(
    BuildContext context,
    AsyncValue<List<CurrencyPositionRow>> positionAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FxSectionHeader(
          label: 'Currency Position',
          trailing: TextButton(
            onPressed: () => context.go('/reports/currency-position'),
            child: Text(
              'VIEW ALL',
              style: AppTypography.labelCaps(
                context.fx.secondary,
                context: context,
              ),
            ),
          ),
        ),
        Text(
          'Actual = vault stock · Committed = open sale commitments · '
          'Required = shortfall (max(0, committed − actual − on-order)). '
          'Negative Actual is shown as-is.',
          style: AppTypography.bodyMd(
            context.fx.onSurfaceVariant,
            context: context,
          ).copyWith(fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.stackSm),
        positionAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.stackLg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Unable to load position: $e'),
          data: (rows) {
            if (rows.isEmpty) {
              return FxStitchCard(
                child: Text(
                  'No currency positions yet.',
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              );
            }
            final preview = rows.take(6).toList();
            return FxResponsiveGrid(
              minTileWidth: 260,
              maxColumns: 3,
              spacing: AppSpacing.gutter,
              children: [
                for (final row in preview) FxCurrencyPositionCard(row: row),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _nextActionsSection(
    BuildContext context,
    AsyncValue<List<FxDeal>> dealsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FxSectionHeader(label: 'Needs your attention'),
        dealsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (deals) {
            final actions = _buildNextActions(context, deals);
            if (actions.isEmpty) {
              return FxStitchCard(
                child: Text(
                  'No pending actions — all caught up.',
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  FxNextActionRow(
                    title: actions[i].title,
                    subtitle: actions[i].subtitle,
                    icon: actions[i].icon,
                    iconBg: actions[i].iconBg,
                    iconFg: actions[i].iconFg,
                    onTap: () => context.push(actions[i].route),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NextActionItem {
  const _NextActionItem({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
    this.iconBg,
    this.iconFg,
  });

  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  final Color? iconBg;
  final Color? iconFg;
}

List<_NextActionItem> _buildNextActions(
  BuildContext context,
  List<FxDeal> deals,
) {
  final open = deals.where((d) => d.status.isOpen).take(5).toList();
  return open.map((d) {
    final customer = d.customerName ?? 'Customer';
    final (title, icon) = _actionForStatus(d.status);
    final useSecondary = title.contains('Receive payment');
    return _NextActionItem(
      title: title,
      subtitle: '$customer • ${d.status.label}',
      route: '/deals/${d.id}',
      icon: icon,
      iconBg: useSecondary
          ? context.fx.secondaryContainer
          : context.fx.errorContainer,
      iconFg: useSecondary ? context.fx.onSecondaryContainer : context.fx.error,
    );
  }).toList();
}

(String, IconData) _actionForStatus(FxDealStatus status) => switch (status) {
  FxDealStatus.customerPaid => (
    'Confirm USD Received',
    Icons.pending_actions_outlined,
  ),
  FxDealStatus.customerPartiallyPaid ||
  FxDealStatus.booked ||
  FxDealStatus.quoted => (
    'Receive payment from Customer',
    Icons.payments_outlined,
  ),
  FxDealStatus.sourcingRequired || FxDealStatus.sourcingInProgress => (
    'Source currency from agent',
    Icons.currency_exchange,
  ),
  FxDealStatus.agentPartiallyPaid ||
  FxDealStatus.agentPaid => ('Pay agent settlement', Icons.person_pin_outlined),
  FxDealStatus.currencyReceived || FxDealStatus.delivered => (
    'Confirm delivery to customer',
    Icons.local_shipping_outlined,
  ),
  _ => ('Review deal workflow', Icons.sync_alt),
};
