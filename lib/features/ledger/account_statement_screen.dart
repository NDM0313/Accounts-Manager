import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_account_statement_table.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AccountStatementScreen extends ConsumerWidget {
  const AccountStatementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final accountCode = ref.watch(ledgerStatementAccountProvider);
    final range = ref.watch(ledgerStatementRangeProvider);
    final statementAsync = ref.watch(accountStatementProvider);
    final fmt = NumberFormat('#,##0.00');
    final fromLabel = range.from.toIso8601String().split('T').first;
    final toLabel = range.to.toIso8601String().split('T').first;
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        accountsAsync.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text('Unable to load accounts: $e'),
          data: (accounts) {
            return DropdownButtonFormField<String?>(
              key: ValueKey(accountCode),
              initialValue: accountCode,
              dropdownColor: context.fx.surfaceContainerHigh,
              decoration: InputDecoration(
                labelText: 'Account',
                labelStyle: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
                hintText: 'Select account for statement',
                filled: true,
                fillColor: context.fx.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  borderSide: BorderSide(color: context.fx.outlineVariant),
                ),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Select account…', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
                ),
                ...accounts.map(
                  (a) => DropdownMenuItem(
                    value: a.code,
                    child: Text('${a.code} · ${a.name}', style: AppTypography.bodyMd(context.fx.onSurface, context: context)),
                  ),
                ),
              ],
              onChanged: (v) => ref.read(ledgerStatementAccountProvider.notifier).set(v),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickRange(context, ref, range),
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text('$fromLabel → $toLabel', style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.fx.onSurface,
                  side: BorderSide(color: context.fx.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: accountCode == null
              ? Center(
                  child: Text(
                    'Select an account to view its statement.',
                    style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
                    textAlign: TextAlign.center,
                  ),
                )
              : statementAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Unable to load statement: $e')),
                  data: (view) {
                    if (view == null) {
                      return const SizedBox.shrink();
                    }
                    if (view.lines.isEmpty && view.openingBalancePkr == 0) {
                      return Center(
                        child: Text(
                          'No entries for ${view.accountCode} from $fromLabel to $toLabel.',
                          style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView(
                      children: [
                        FxObsidianReportPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${view.accountCode} · ${view.accountName}',
                                style: AppTypography.headlineMd(context.fx.onSurface, context: context).copyWith(fontSize: 16),
                              ),
                              Text(
                                '$fromLabel → $toLabel',
                                style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _summaryTile(context, 'Opening', fmt.format(view.openingBalancePkr)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _summaryTile(context, 'Closing', fmt.format(view.closingBalancePkr)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isWide)
                          FxAccountStatementTable(
                            lines: view.lines,
                            openingBalancePkr: view.openingBalancePkr,
                          )
                        else
                          ...view.lines.map(
                            (line) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: FxObsidianReportPanel(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          line.entryDate.toIso8601String().split('T').first,
                                          style: AppTypography.labelCaps(context.fx.outline, context: context).copyWith(fontSize: 10),
                                        ),
                                        const Spacer(),
                                        Text(line.entryNo, style: AppTypography.labelMono(context.fx.outline, context: context).copyWith(fontSize: 10)),
                                      ],
                                    ),
                                    if (line.description != null && line.description!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(line.description!, style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontSize: 12)),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Dr ${fmt.format(line.debitPkr)}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11)),
                                        Text('Cr ${fmt.format(line.creditPkr)}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11)),
                                        Text(
                                          'Bal ${fmt.format(line.runningBalancePkr)}',
                                          style: AppTypography.labelMono(context.fx.tertiary, context: context).copyWith(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (isWide && view.lines.isEmpty)
                          FxAccountStatementTable(lines: const [], openingBalancePkr: view.openingBalancePkr),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _summaryTile(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.labelCaps(context.fx.outline, context: context).copyWith(fontSize: 10)),
        Text(value, style: AppTypography.labelMono(context.fx.onSurface, context: context).copyWith(fontSize: 14)),
      ],
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
      ref.read(ledgerStatementRangeProvider.notifier).setRange(from, to);
    }
  }
}
