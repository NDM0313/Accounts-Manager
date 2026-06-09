import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_currency_tile.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_daily_closing_card.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_hero_balance_card.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_bottom_sheet.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_ledger_table.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_shell.dart';
import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/features/dashboard/dashboard_kpi_row.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,##0.00');
    final cashAsync = ref.watch(cashBalancesProvider);
    final ratesAsync = ref.watch(ratesProvider);
    final todayAsync = ref.watch(todayTransactionsProvider);
    final dayClosedAsync = ref.watch(dayClosedProvider);
    final kpiAsync = ref.watch(dashboardKpiProvider);
    final todayPlAsync = ref.watch(todayProfitLossProvider);
    final tbTotalsAsync = ref.watch(trialBalanceTotalsProvider);
    final draftsAsync = ref.watch(draftTransactionsProvider);
    final settlementsAsync = ref.watch(pendingSettlementsCountProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final totalNet = cashAsync.maybeWhen(
      data: (rows) => rows.fold<double>(0, (s, r) => s + r.balancePkr),
      orElse: () => null,
    );

    return FxObsidianPage(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          FxHeroBalanceCard(
            amountLabel: totalNet != null ? 'PKR ${fmt.format(totalNet)}' : '—',
            onQuickAdd: () => _showNewMenu(context),
            onExport: () => _exportTodayCsv(context, ref, todayAsync, fmt),
          ),
          const SizedBox(height: 24),
          DashboardKpiRow(
            kpi: kpiAsync.whenOrNull(data: (v) => v),
            todayPl: todayPlAsync.whenOrNull(data: (v) => v),
            tbBalanced: tbTotalsAsync.whenOrNull(data: (v) => v.isBalanced),
            unpostedCount: draftsAsync.whenOrNull(data: (v) => v.length),
            pendingSettlements: settlementsAsync.whenOrNull(data: (v) => v),
          ),
          const SizedBox(height: 24),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: _closingCard(context, ref, dayClosedAsync),
                ),
                const SizedBox(width: 24),
                Expanded(flex: 8, child: _currencyGrid(context, cashAsync, ratesAsync, fmt)),
              ],
            )
          else ...[
            _closingCard(context, ref, dayClosedAsync),
            const SizedBox(height: 24),
            _currencyGrid(context, cashAsync, ratesAsync, fmt),
          ],
          const SizedBox(height: 24),
          _recentSection(context, todayAsync, fmt),
        ],
      ),
    );
  }

  Widget _closingCard(BuildContext context, WidgetRef ref, AsyncValue<bool> dayClosedAsync) {
    return dayClosedAsync.when(
      loading: () => FxDailyClosingCard(
        isClosed: false,
        statusText: 'Loading…',
        subtitle: 'Checking closing status.',
        onClose: () => context.push('/closing'),
      ),
      error: (e, _) => FxDailyClosingCard(
        isClosed: false,
        statusText: 'Status unavailable',
        subtitle: '$e',
        onClose: () => context.push('/closing'),
      ),
      data: (closed) => FxDailyClosingCard(
        isClosed: closed,
        statusText: closed ? 'Today is Closed' : 'Today is Open',
        subtitle: closed
            ? 'This day is locked for posting and edits.'
            : 'Audit trails are active. Close the ledger when done for the day.',
        onClose: () => context.push('/closing'),
      ),
    );
  }

  Widget _currencyGrid(
    BuildContext context,
    AsyncValue<List<CashBalanceRow>> cashAsync,
    AsyncValue<List<FxRate>> ratesAsync,
    NumberFormat fmt,
  ) {
    return cashAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      error: (e, _) => Text('Unable to load balances.', style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurfaceVariant, context: context)),
      data: (rows) {
        if (rows.isEmpty) {
          return Text(
            'No cash balances yet.',
            style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurfaceVariant, context: context),
          );
        }
        final rateMap = ratesAsync.maybeWhen(
          data: (rates) => {for (final r in rates) r.currencyCode: r.buyRate},
          orElse: () => <String, double>{},
        );
        return LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 600 ? 3 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: cols == 1 ? 2.2 : 1.1,
              ),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final r = rows[i];
                final rate = rateMap[r.currencyCode];
                return FxCurrencyTile(
                  currencyCode: r.currencyCode,
                  amountLabel: fmt.format(r.foreignBalance),
                  rateLabel: rate != null ? '${r.currencyCode}/PKR ${fmt.format(rate)}' : null,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _recentSection(BuildContext context, AsyncValue<List<FxTransaction>> todayAsync, NumberFormat fmt) {
    return Container(
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Transactions', style: AppTypography.headlineMd(Theme.of(context).colorScheme.onSurface, context: context)),
                TextButton(
                  onPressed: () => context.go('/ledger'),
                  child: Text('VIEW ALL', style: AppTypography.labelCaps(Theme.of(context).colorScheme.onSurfaceVariant, context: context)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.fx.outlineVariant),
          todayAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('Error: $e')),
            data: (items) {
              final rows = items.map((tx) {
                return FxLedgerTableRow(
                  id: tx.id,
                  timestamp: tx.postedAt ?? tx.createdAt,
                  type: tx.transactionType,
                  currencyCode: tx.currencyCode,
                  amount: tx.totalForeignAmount,
                  rate: tx.rateUsed,
                  status: tx.status,
                );
              }).toList();
              return FxLedgerTable(
                rows: rows,
                onRowTap: (id) => context.push('/transactions/$id'),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showNewMenu(BuildContext context) {
    FxObsidianBottomSheet.showTransactionTypes(context);
  }

  Future<void> _exportTodayCsv(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<FxTransaction>> todayAsync,
    NumberFormat fmt,
  ) async {
    final items = await ref.read(todayTransactionsProvider.future);
    if (items.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No posted transactions to export.')),
        );
      }
      return;
    }
    final buffer = StringBuffer('date,type,currency,amount,rate,pkr,status,ref\n');
    for (final tx in items) {
      buffer.writeln(
        '${tx.transactionDate.toIso8601String().split('T').first},'
        '${tx.transactionType.dbValue},'
        '${tx.currencyCode},'
        '${tx.totalForeignAmount},'
        '${tx.rateUsed},'
        '${tx.totalBaseAmountPkr},'
        '${tx.status},'
        '${tx.transactionNo ?? tx.id}',
      );
    }
    await Share.share(buffer.toString(), subject: 'FX Ledger export');
  }
}
