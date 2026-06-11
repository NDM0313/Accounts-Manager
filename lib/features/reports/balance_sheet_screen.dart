import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/export/fx_report_export.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_converted_amount.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:accounts_manager/domain/services/reporting_currency_converter.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/auth/providers/display_currency_providers.dart';
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
    final currencyView = ref.watch(reportCurrencyViewProvider);
    final displayCode = ref.watch(displayCurrencyCodeProvider);
    final converter = ref.watch(currencyConverterAsOfProvider(asOf)).whenOrNull(data: (v) => v);

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: const Text('Balance Sheet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export',
            onPressed: () async {
              final rows = await ref.read(balanceSheetProvider.future);
              if (!context.mounted) return;
              await exportBalanceSheetReport(
                context,
                rows: rows,
                dateLabel: dateLabel,
                converter: converter,
                view: currencyView,
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
              const SizedBox(height: 8),
              ref.watch(companyAccountingContextProvider).maybeWhen(
                    data: (ctx) => FxReportCurrencyToggle(
                      view: currencyView,
                      displayCurrencyCode: displayCode,
                      baseCurrencyCode: ctx.baseCurrencyCode,
                      onChanged: (v) => ref.read(reportCurrencyViewProvider.notifier).setView(v),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
              const SizedBox(height: 16),
              FxObsidianReportPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assets', style: AppTypography.labelCaps(context.fx.outline, context: context)),
                    converter != null
                        ? FxConvertedAmount(
                            pkrAmount: totalAssets,
                            converter: converter,
                            style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600),
                          )
                        : Text('Assets ${fmt.format(totalAssets)}', style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    converter != null
                        ? FxConvertedAmount(
                            pkrAmount: totalLiabilities + totalEquity,
                            converter: converter,
                            style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                          )
                        : Text(
                            'Liabilities + Equity ${fmt.format(totalLiabilities + totalEquity)}',
                            style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FxObsidianReportSection(label: 'Assets', children: _rows(context, fmt, assets, converter, currencyView)),
              const SizedBox(height: 16),
              FxObsidianReportSection(label: 'Liabilities', children: _rows(context, fmt, liabilities, converter, currencyView)),
              const SizedBox(height: 16),
              FxObsidianReportSection(label: 'Equity', children: _rows(context, fmt, equity, converter, currencyView)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _rows(
    BuildContext context,
    NumberFormat fmt,
    List<BalanceSheetRow> rows,
    ReportingCurrencyConverter? converter,
    ReportCurrencyView currencyView,
  ) {
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
                  converter != null
                      ? Text(
                          formatReportAmount(pkrAmount: r.balancePkr, converter: converter, view: currencyView, fmt: fmt),
                          style: AppTypography.labelMono(context.fx.onSurface, context: context),
                        )
                      : Text(fmt.format(r.balancePkr), style: AppTypography.labelMono(context.fx.onSurface, context: context)),
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
