import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class GeneralLedgerScreen extends ConsumerWidget {
  const GeneralLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportDateRangeProvider);
    final rowsAsync = ref.watch(generalLedgerProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final accountFilter = ref.watch(generalLedgerAccountFilterProvider);
    final fmt = NumberFormat('#,##0.00');
    final fromLabel = range.from.toIso8601String().split('T').first;
    final toLabel = range.to.toIso8601String().split('T').first;

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: const Text('General Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            onPressed: () => _pickRange(context, ref, range),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text('$fromLabel → $toLabel', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: accountsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => const SizedBox.shrink(),
              data: (accounts) {
                return DropdownButtonFormField<String?>(
                  key: ValueKey(accountFilter),
                  initialValue: accountFilter,
                  dropdownColor: context.fx.surfaceContainerHigh,
                  decoration: InputDecoration(
                    labelText: 'Account filter',
                    labelStyle: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
                    isDense: true,
                    filled: true,
                    fillColor: context.fx.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      borderSide: BorderSide(color: context.fx.outlineVariant),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text('All accounts', style: AppTypography.bodyMd(context.fx.onSurface, context: context))),
                    ...accounts.map(
                      (a) => DropdownMenuItem(
                        value: a.code,
                        child: Text('${a.code} · ${a.name}', style: AppTypography.bodyMd(context.fx.onSurface, context: context)),
                      ),
                    ),
                  ],
                  onChanged: (v) => ref.read(generalLedgerAccountFilterProvider.notifier).set(v),
                );
              },
            ),
          ),
          Expanded(
            child: rowsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Unable to load ledger: $e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(
                    child: Text('No journal entries in this period.', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  row.entryDate.toIso8601String().split('T').first,
                                  style: AppTypography.labelCaps(context.fx.outline, context: context).copyWith(fontSize: 10),
                                ),
                                const Spacer(),
                                Text(row.entryNo, style: AppTypography.labelMono(context.fx.outline, context: context).copyWith(fontSize: 10)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${row.accountCode} · ${row.accountName}',
                              style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (row.description != null && row.description!.isNotEmpty)
                              Text(row.description!, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('Dr ${fmt.format(row.debitPkr)}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
                                const SizedBox(width: 12),
                                Text('Cr ${fmt.format(row.creditPkr)}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
                                const Spacer(),
                                Text(
                                  '${row.currencyCode} ${fmt.format(row.foreignAmount)}',
                                  style: AppTypography.labelMono(context.fx.onSurface, context: context).copyWith(fontSize: 12),
                                ),
                              ],
                            ),
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

  Future<void> _pickRange(BuildContext context, WidgetRef ref, ReportDateRange current) async {
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
