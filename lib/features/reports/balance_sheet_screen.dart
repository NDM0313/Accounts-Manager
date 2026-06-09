import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/utils/report_export.dart';
import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BalanceSheetScreen extends ConsumerWidget {
  const BalanceSheetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asOf = ref.watch(reportAsOfProvider);
    final rowsAsync = ref.watch(balanceSheetProvider);
    final fmt = NumberFormat('#,##0.00');
    final dateLabel = asOf.toIso8601String().split('T').first;

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: const Text('Balance Sheet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export CSV',
            onPressed: () async {
              final rows = await ref.read(balanceSheetProvider.future);
              if (!context.mounted) return;
              if (rows.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No balance sheet data to export.')),
                );
                return;
              }
              await shareReportCsv(
                csv: formatBalanceSheetCsv(rows),
                subject: 'FX Ledger Balance Sheet $dateLabel',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () => _pickDate(context, ref, asOf),
          ),
        ],
      ),
      body: rowsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load balance sheet: $e')),
        data: (rows) {
          final assets = rows.where((r) => r.accountType == 'asset').toList();
          final liabilities = rows.where((r) => r.accountType == 'liability').toList();
          final equity = rows.where((r) => r.accountType == 'equity').toList();
          final totalAssets = assets.fold<double>(0, (s, r) => s + r.balancePkr);
          final totalLiabilities = liabilities.fold<double>(0, (s, r) => s + r.balancePkr);
          final totalEquity = equity.fold<double>(0, (s, r) => s + r.balancePkr);

          if (rows.isEmpty) {
            return Center(child: Text('No balance sheet balances as of $dateLabel.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('As of $dateLabel', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
              const SizedBox(height: 16),
              FxObsidianReportPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assets ${fmt.format(totalAssets)}', style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      'Liabilities + Equity ${fmt.format(totalLiabilities + totalEquity)}',
                      style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FxObsidianReportSection(label: 'Assets', children: _rows(context, fmt, assets)),
              const SizedBox(height: 16),
              FxObsidianReportSection(label: 'Liabilities', children: _rows(context, fmt, liabilities)),
              const SizedBox(height: 16),
              FxObsidianReportSection(label: 'Equity', children: _rows(context, fmt, equity)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _rows(BuildContext context, NumberFormat fmt, List<BalanceSheetRow> rows) {
    return rows
        .map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FxObsidianReportPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${r.accountCode} · ${r.accountName}',
                      style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(fmt.format(r.balancePkr), style: AppTypography.labelMono(context.fx.onSurface, context: context)),
                ],
              ),
            ),
          ),
        )
        .toList();
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref, DateTime current) async {
    final picked = await FxObsidianPickers.showDate(
      context,
      initialDate: current,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(reportAsOfProvider.notifier).setDate(picked);
    }
  }
}
