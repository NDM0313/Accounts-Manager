import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/export/fx_report_export.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_converted_amount.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/auth/providers/display_currency_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CurrencyPositionScreen extends ConsumerWidget {
  const CurrencyPositionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asOf = ref.watch(reportAsOfProvider);
    final rowsAsync = ref.watch(currencyPositionProvider);
    final fmt = NumberFormat('#,##0.00');
    final dateLabel = asOf.toIso8601String().split('T').first;
    final extended = FeatureFlags.dealsWorkflowEnabled;
    final currencyView = ref.watch(reportCurrencyViewProvider);
    final userDisplayCode = ref.watch(displayCurrencyCodeProvider);
    final converter = ref
        .watch(currencyConverterAsOfProvider(asOf))
        .whenOrNull(data: (v) => v);

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: const Text('Currency Position'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export',
            onPressed: () async {
              final rows = await ref.read(currencyPositionProvider.future);
              if (!context.mounted) return;
              await exportCurrencyPositionReport(
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
        error: (e, _) => Center(child: Text('Unable to load position: $e')),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Text('No cash currency position as of $dateLabel.'),
            );
          }

          final totalPkr = rows.fold<double>(
            0,
            (s, r) => s + r.baseEquivalentPkr,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'As of $dateLabel',
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
              if (extended)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Includes committed / required balances from open FX deals.',
                    style: AppTypography.bodyMd(
                      context.fx.onSurfaceVariant,
                      context: context,
                    ).copyWith(fontSize: 11),
                  ),
                ),
              const SizedBox(height: 8),
              ref
                  .watch(companyAccountingContextProvider)
                  .maybeWhen(
                    data: (ctx) => FxReportCurrencyToggle(
                      view: currencyView,
                      displayCurrencyCode: userDisplayCode,
                      baseCurrencyCode: ctx.baseCurrencyCode,
                      onChanged: (v) => ref
                          .read(reportCurrencyViewProvider.notifier)
                          .setView(v),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
              const SizedBox(height: 16),
              FxObsidianReportPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total PKR equivalent',
                      style: AppTypography.labelCaps(
                        context.fx.outline,
                        context: context,
                      ),
                    ),
                    converter != null
                        ? FxConvertedAmount(
                            pkrAmount: totalPkr,
                            converter: converter,
                            style: AppTypography.headlineMd(
                              context.fx.onSurface,
                              context: context,
                            ),
                          )
                        : Text(
                            fmt.format(totalPkr),
                            style: AppTypography.headlineMd(
                              context.fx.onSurface,
                              context: context,
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...rows.map((r) {
                final showExtended = extended && r.hasExtendedMetrics;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FxObsidianReportPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayCurrencyCode(r.currencyCode),
                                style: AppTypography.headlineMd(
                                  context.fx.onSurface,
                                  context: context,
                                ).copyWith(fontSize: 18),
                              ),
                            ),
                            converter != null
                                ? Text(
                                    formatReportAmount(
                                      pkrAmount: r.baseEquivalentPkr,
                                      converter: converter,
                                      view: currencyView,
                                      fmt: fmt,
                                    ),
                                    style: AppTypography.bodyMd(
                                      context.fx.onSurface,
                                      context: context,
                                    ).copyWith(fontWeight: FontWeight.w600),
                                  )
                                : Text(
                                    'PKR ${fmt.format(r.baseEquivalentPkr)}',
                                    style: AppTypography.bodyMd(
                                      context.fx.onSurface,
                                      context: context,
                                    ).copyWith(fontWeight: FontWeight.w600),
                                  ),
                          ],
                        ),
                        if (showExtended) ...[
                          const SizedBox(height: 8),
                          _metricRow(
                            context,
                            'Actual',
                            r.actualBalance ?? r.foreignBalance,
                            fmt,
                          ),
                          if (r.committedBalance != null &&
                              r.committedBalance! > 0)
                            _metricRow(
                              context,
                              'Committed',
                              r.committedBalance!,
                              fmt,
                              color: Colors.orange,
                            ),
                          if (r.onOrderBalance != null && r.onOrderBalance! > 0)
                            _metricRow(
                              context,
                              'On order',
                              r.onOrderBalance!,
                              fmt,
                            ),
                          if (r.requiredBalance != null &&
                              r.requiredBalance! > 0)
                            _metricRow(
                              context,
                              'To source',
                              r.requiredBalance!,
                              fmt,
                              color: Colors.red.shade300,
                            ),
                          if (r.availableBalance != null)
                            _metricRow(
                              context,
                              'Available',
                              r.availableBalance!,
                              fmt,
                              bold: true,
                            ),
                        ] else
                          Text(
                            'Foreign ${fmt.format(r.foreignBalance)}',
                            style: AppTypography.bodyMd(
                              context.fx.onSurfaceVariant,
                              context: context,
                            ).copyWith(fontSize: 12),
                          ),
                        if (extended && (r.requiredBalance ?? 0) > 0)
                          TextButton(
                            onPressed: () => context.push('/deals'),
                            child: const Text('View open deals'),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _metricRow(
    BuildContext context,
    String label,
    double value,
    NumberFormat fmt, {
    Color? color,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMd(
              color ?? context.fx.onSurfaceVariant,
              context: context,
            ).copyWith(fontSize: 11),
          ),
          Text(
            fmt.format(value),
            style:
                AppTypography.bodyMd(
                  color ?? context.fx.onSurface,
                  context: context,
                ).copyWith(
                  fontSize: 11,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref,
    DateTime current,
  ) async {
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
