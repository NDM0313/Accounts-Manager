import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class CurrencyPositionScreen extends ConsumerWidget {
  const CurrencyPositionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asOf = ref.watch(reportAsOfProvider);
    final rowsAsync = ref.watch(currencyPositionProvider);
    final fmt = NumberFormat('#,##0.00');
    final dateLabel = asOf.toIso8601String().split('T').first;

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: const Text('Currency Position'),
        actions: [
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
            return Center(child: Text('No cash currency position as of $dateLabel.'));
          }

          final totalPkr = rows.fold<double>(0, (s, r) => s + r.baseEquivalentPkr);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('As of $dateLabel', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
              const SizedBox(height: 16),
              FxObsidianReportPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total PKR equivalent', style: AppTypography.labelCaps(context.fx.outline, context: context)),
                    Text(fmt.format(totalPkr), style: AppTypography.headlineMd(context.fx.onSurface, context: context)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...rows.map((r) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FxObsidianReportPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.currencyCode, style: AppTypography.headlineMd(context.fx.onSurface, context: context).copyWith(fontSize: 18)),
                              Text(
                                'Foreign ${fmt.format(r.foreignBalance)}',
                                style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text('PKR ${fmt.format(r.baseEquivalentPkr)}', style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600)),
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
