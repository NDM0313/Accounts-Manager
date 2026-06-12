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

class ProfitLossScreen extends ConsumerWidget {
  const ProfitLossScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportDateRangeProvider);
    final rowsAsync = ref.watch(profitLossProvider);
    final fmt = NumberFormat('#,##0.00');
    final fromLabel = range.from.toIso8601String().split('T').first;
    final toLabel = range.to.toIso8601String().split('T').first;
    final currencyView = ref.watch(reportCurrencyViewProvider);
    final displayCode = ref.watch(displayCurrencyCodeProvider);
    final converter = ref
        .watch(currencyConverterAsOfProvider(range.to))
        .whenOrNull(data: (v) => v);

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: const Text('Profit & Loss'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export',
            onPressed: () async {
              final rows = await ref.read(profitLossProvider.future);
              if (!context.mounted) return;
              await exportProfitLossReport(
                context,
                rows: rows,
                fromLabel: fromLabel,
                toLabel: toLabel,
                converter: converter,
                view: currencyView,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            onPressed: () => _pickRange(context, ref, range),
          ),
        ],
      ),
      body: rowsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load P&L: $e')),
        data: (rows) {
          final income = rows.where((r) => r.accountType == 'income').toList();
          final expense = rows
              .where((r) => r.accountType == 'expense')
              .toList();
          final totalIncome = income.fold<double>(0, (s, r) => s + r.amountPkr);
          final totalExpense = expense.fold<double>(
            0,
            (s, r) => s + r.amountPkr,
          );
          final net = totalIncome - totalExpense;

          if (rows.isEmpty) {
            return Center(
              child: Text(
                'No income or expense activity from $fromLabel to $toLabel.',
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '$fromLabel → $toLabel',
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
              const SizedBox(height: 8),
              ref
                  .watch(companyAccountingContextProvider)
                  .maybeWhen(
                    data: (ctx) => FxReportCurrencyToggle(
                      view: currencyView,
                      displayCurrencyCode: displayCode,
                      baseCurrencyCode: ctx.baseCurrencyCode,
                      onChanged: (v) => ref
                          .read(reportCurrencyViewProvider.notifier)
                          .setView(v),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
              const SizedBox(height: 16),
              FxObsidianReportPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net profit',
                            style: AppTypography.labelCaps(
                              context.fx.outline,
                              context: context,
                            ),
                          ),
                          converter != null
                              ? FxConvertedAmount(
                                  pkrAmount: net,
                                  converter: converter,
                                  style: AppTypography.headlineMd(
                                    net >= 0
                                        ? context.fx.tertiary
                                        : context.fx.error,
                                    context: context,
                                  ),
                                )
                              : Text(
                                  fmt.format(net),
                                  style: AppTypography.headlineMd(
                                    net >= 0
                                        ? context.fx.tertiary
                                        : context.fx.error,
                                    context: context,
                                  ),
                                ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          converter != null
                              ? 'Income ${formatReportAmount(pkrAmount: totalIncome, converter: converter, view: currencyView, fmt: fmt)}'
                              : 'Income ${fmt.format(totalIncome)}',
                          style: AppTypography.bodyMd(
                            context.fx.onSurfaceVariant,
                            context: context,
                          ).copyWith(fontSize: 12),
                        ),
                        Text(
                          converter != null
                              ? 'Expense ${formatReportAmount(pkrAmount: totalExpense, converter: converter, view: currencyView, fmt: fmt)}'
                              : 'Expense ${fmt.format(totalExpense)}',
                          style: AppTypography.bodyMd(
                            context.fx.onSurfaceVariant,
                            context: context,
                          ).copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FxObsidianReportSection(
                label: 'Income',
                children: income
                    .map((r) => _row(context, fmt, r, converter, currencyView))
                    .toList(),
              ),
              const SizedBox(height: 16),
              FxObsidianReportSection(
                label: 'Expense',
                children: expense
                    .map((r) => _row(context, fmt, r, converter, currencyView))
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(
    BuildContext context,
    NumberFormat fmt,
    ProfitLossRow r,
    ReportingCurrencyConverter? converter,
    ReportCurrencyView currencyView,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FxObsidianReportPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${r.accountCode} · ${r.accountName}',
                style: AppTypography.bodyMd(
                  context.fx.onSurface,
                  context: context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            converter != null
                ? Text(
                    formatReportAmount(
                      pkrAmount: r.amountPkr,
                      converter: converter,
                      view: currencyView,
                      fmt: fmt,
                    ),
                    style: AppTypography.labelMono(
                      context.fx.onSurface,
                      context: context,
                    ),
                  )
                : Text(
                    fmt.format(r.amountPkr),
                    style: AppTypography.labelMono(
                      context.fx.onSurface,
                      context: context,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange(
    BuildContext context,
    WidgetRef ref,
    ReportDateRange current,
  ) async {
    final from = await FxObsidianPickers.showDate(
      context,
      initialDate: current.from,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (from == null || !context.mounted) return;
    final to = await FxObsidianPickers.showDate(
      context,
      initialDate: current.to.isBefore(from) ? from : current.to,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (to != null) {
      ref.read(reportDateRangeProvider.notifier).setRange(from, to);
    }
  }
}
