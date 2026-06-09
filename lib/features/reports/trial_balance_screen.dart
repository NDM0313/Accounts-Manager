import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/utils/report_export.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TrialBalanceScreen extends ConsumerWidget {
  const TrialBalanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asOf = ref.watch(trialBalanceAsOfProvider);
    final rowsAsync = ref.watch(trialBalanceProvider);
    final totalsAsync = ref.watch(trialBalanceTotalsProvider);
    final fmt = NumberFormat('#,##0.00');
    final dateLabel = asOf.toIso8601String().split('T').first;

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: const Text('Trial Balance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export CSV',
            onPressed: () async {
              final rows = await ref.read(trialBalanceProvider.future);
              if (!context.mounted) return;
              if (rows.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No trial balance data to export.')),
                );
                return;
              }
              final dateLabel = asOf.toIso8601String().split('T').first;
              await shareReportCsv(
                csv: formatTrialBalanceCsv(rows),
                subject: 'FX Ledger Trial Balance $dateLabel',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () => _pickDate(context, ref, asOf),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text('As of $dateLabel', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
          ),
          totalsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
            data: (totals) => Padding(
              padding: const EdgeInsets.all(16),
              child: FxObsidianReportPanel(
                child: Row(
                  children: [
                    Icon(
                      totals.isBalanced ? Icons.check_circle : Icons.warning_amber,
                      color: totals.isBalanced ? context.fx.tertiary : context.fx.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            totals.isBalanced ? 'Balanced' : 'Out of balance',
                            style: AppTypography.headlineMd(context.fx.onSurface, context: context).copyWith(fontSize: 16),
                          ),
                          Text(
                            'Debit ${fmt.format(totals.totalDebit)} · Credit ${fmt.format(totals.totalCredit)}',
                            style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: rowsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Unable to load trial balance: $e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(
                    child: Text('No posted journal activity yet.', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FxObsidianReportPanel(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        onTap: () => context.push(
                          '/reports/account-journal?code=${row.accountCode}&asOf=$dateLabel',
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${row.accountCode} · ${row.accountName}',
                                    style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Net ${fmt.format(row.netPkr)}',
                                    style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Dr ${fmt.format(row.debitPkr)}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
                                Text('Cr ${fmt.format(row.creditPkr)}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
                              ],
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right, size: 18, color: context.fx.outline),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref, DateTime current) async {
    final picked = await FxObsidianPickers.showDate(
      context,
      initialDate: current,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(trialBalanceAsOfProvider.notifier).setDate(picked);
    }
  }
}
