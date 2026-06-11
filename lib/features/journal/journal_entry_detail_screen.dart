import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class JournalEntryDetailScreen extends ConsumerWidget {
  const JournalEntryDetailScreen({super.key, required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(journalEntryProvider(entryId));
    final fmt = NumberFormat('#,##0.00');

    return FxPageScaffold(
      fallbackRoute: '/ledger',
      title: const Text('Journal Entry'),
      body: entryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entry) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.fx.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(color: context.fx.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      entry.isBalanced ? Icons.check_circle : Icons.warning_amber,
                      color: entry.isBalanced ? context.fx.tertiary : context.fx.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.entryNo, style: AppTypography.headlineMd(context.fx.onSurface, context: context)),
                          Text(
                            entry.isBalanced ? 'Balanced' : 'Out of balance',
                            style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
                          ),
                          Text(
                            'Date: ${entry.entryDate.toIso8601String().split('T').first}',
                            style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                          ),
                          if (entry.description != null)
                            Text(entry.description!, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FxSectionLabel(label: 'Totals'),
              const SizedBox(height: 8),
              Text(
                'Dr ${fmt.format(entry.totalDebit)} · Cr ${fmt.format(entry.totalCredit)}',
                style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              FxSectionLabel(label: 'Lines'),
              const SizedBox(height: 8),
              ...entry.lines.map((line) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.fx.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: context.fx.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${line.accountCode} · ${line.accountName ?? ''}',
                              style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${line.currencyCode} ${fmt.format(line.foreignAmount)}',
                              style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Dr ${fmt.format(line.debitPkr)}', style: AppTypography.labelMono(context.fx.onSurfaceVariant, context: context)),
                          Text('Cr ${fmt.format(line.creditPkr)}', style: AppTypography.labelMono(context.fx.onSurfaceVariant, context: context)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
