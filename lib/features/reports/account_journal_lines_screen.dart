import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AccountJournalLinesScreen extends ConsumerWidget {
  const AccountJournalLinesScreen({
    super.key,
    required this.accountCode,
    required this.asOf,
  });

  final String accountCode;
  final DateTime asOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linesAsync = ref.watch(accountJournalLinesProvider((accountCode, asOf)));
    final fmt = NumberFormat('#,##0.00');
    final dateLabel = asOf.toIso8601String().split('T').first;

    return FxPageScaffold(
      fallbackRoute: '/reports/trial-balance',
      title: Text('Account $accountCode'),
      body: linesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lines) {
          if (lines.isEmpty) {
            return Center(child: Text('No journal lines for $accountCode as of $dateLabel.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lines.length,
            itemBuilder: (context, i) {
              final line = lines[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FxObsidianReportPanel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Line ${line.lineNo}',
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
                          Text('Dr ${fmt.format(line.debitPkr)}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
                          Text('Cr ${fmt.format(line.creditPkr)}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
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
    );
  }
}
