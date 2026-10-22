import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Daily cash & bank book (Roznamcha).
class RoznamchaScreen extends ConsumerWidget {
  const RoznamchaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportDateRangeProvider);
    final viewAsync = ref.watch(roznamchaProvider);
    final accountFilter = ref.watch(roznamchaAccountFilterProvider);
    final cashAsync = ref.watch(cashBalancesProvider);
    final fmt = NumberFormat('#,##0.00');
    final timeFmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('dd MMM');

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: FxPageHeader.appBar(
        context: context,
        fallbackRoute: '/reports',
        title: const Text('Roznamcha'),
        actions: [
          IconButton(
            tooltip: 'Today',
            icon: const Icon(Icons.today_outlined),
            onPressed: () {
              final today = DateTime.now();
              final d = DateTime(today.year, today.month, today.day);
              ref.read(reportDateRangeProvider.notifier).setRange(d, d);
            },
          ),
          IconButton(
            tooltip: 'Date range',
            icon: const Icon(Icons.date_range_outlined),
            onPressed: () => _pickRange(context, ref, range),
          ),
        ],
      ),
      body: FxContentContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cash & bank book · Asia/Karachi calendar dates · '
              'Opening + Money in − Money out = Closing',
              style: AppTypography.bodySm(
                context.fx.onSurfaceVariant,
                context: context,
              ),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            FxFilterToolbar(
              filters: [
                FxFilterChipButton(
                  label: 'All cash/bank',
                  selected: accountFilter == null,
                  onPressed: () =>
                      ref.read(roznamchaAccountFilterProvider.notifier).set(null),
                ),
                ...cashAsync.maybeWhen(
                  data: (rows) => rows
                      .map(
                        (r) => FxFilterChipButton(
                          label: r.accountCode,
                          selected: accountFilter == r.accountCode,
                          onPressed: () => ref
                              .read(roznamchaAccountFilterProvider.notifier)
                              .set(r.accountCode),
                        ),
                      )
                      .toList(),
                  orElse: () => const <Widget>[],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Expanded(
              child: viewAsync.when(
                loading: () => const FxLoadingState(message: 'Loading book…'),
                error: (e, _) => FxErrorState(
                  message: 'Unable to load Roznamcha: $e',
                  onRetry: () => ref.invalidate(roznamchaProvider),
                ),
                data: (view) {
                  return ListView(
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FxCompactMetric(
                            label: 'Opening',
                            amount: view.openingTotal,
                          ),
                          FxCompactMetric(
                            label: 'Money in (all legs)',
                            amount: view.totalIn,
                          ),
                          FxCompactMetric(
                            label: 'Money out (all legs)',
                            amount: view.totalOut,
                          ),
                          FxCompactMetric(
                            label: 'Closing',
                            amount: view.closing,
                          ),
                          FxCompactMetric(
                            label: 'External in',
                            amount: view.externalIn,
                            subtitle: 'Excludes internal transfers',
                          ),
                          FxCompactMetric(
                            label: 'External out',
                            amount: view.externalOut,
                            subtitle: 'Excludes internal transfers',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.stackMd),
                      if (view.lines.isEmpty)
                        const FxEmptyState(
                          message: 'No cash/bank movements in this period.',
                        )
                      else
                        ...view.lines.map((line) {
                          final movement = line.moneyInPkr > 0
                              ? '+ ${fmt.format(line.moneyInPkr)}'
                              : '− ${fmt.format(line.moneyOutPkr)}';
                          final movementColor = line.moneyInPkr > 0
                              ? AppColors.lightSuccess
                              : context.fx.error;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: context.fx.surface,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusLg),
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusLg),
                                onTap: line.transactionId == null
                                    ? null
                                    : () => context.push(
                                          '/transactions/${line.transactionId}',
                                        ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${dateFmt.format(line.entryDate)} '
                                            '${timeFmt.format(line.entryTime.toLocal())}',
                                            style: AppTypography.bodySm(
                                              context.fx.onSurfaceVariant,
                                              context: context,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            line.entryNo,
                                            style: AppTypography.bodySm(
                                              context.fx.outline,
                                              context: context,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (line.isInternalTransfer)
                                            const FxStatusBadge(
                                              label: 'Internal transfer',
                                              tone: FxStatusTone.neutral,
                                            ),
                                          if (line.attachmentCount > 0) ...[
                                            const SizedBox(width: 6),
                                            Icon(
                                              Icons.attach_file,
                                              size: 16,
                                              color: context.fx.secondary,
                                            ),
                                            Text(
                                              '${line.attachmentCount}',
                                              style: AppTypography.bodySm(
                                                context.fx.secondary,
                                                context: context,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${line.accountCode} · ${line.accountName}',
                                        style: AppTypography.bodyMd(
                                          context.fx.onSurface,
                                          context: context,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      if (line.partyName != null)
                                        Text(
                                          line.partyName!,
                                          style: AppTypography.bodySm(
                                            context.fx.onSurfaceVariant,
                                            context: context,
                                          ),
                                        ),
                                      if (line.description != null &&
                                          line.description!.isNotEmpty)
                                        Text(
                                          line.description!,
                                          style: AppTypography.bodySm(
                                            context.fx.onSurfaceVariant,
                                            context: context,
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(
                                            line.moneyInPkr > 0
                                                ? 'Received'
                                                : 'Paid',
                                            style: AppTypography.bodySm(
                                              movementColor,
                                              context: context,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'PKR $movement',
                                            style: AppTypography.dataMd(
                                              movementColor,
                                              context: context,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            'Balance after: PKR ${fmt.format(line.runningBalancePkr)}',
                                            style: AppTypography.bodySm(
                                              context.fx.onSurface,
                                              context: context,
                                            ).copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                },
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
