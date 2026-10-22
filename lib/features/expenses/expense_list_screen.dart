import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Expense workflow list — drafts and posted expense transactions.
///
/// Paid expenses use existing balanced posting (expense Dr / cash-bank Cr).
/// Unpaid “Pay later” is not faked: settle via Settlement Send when needed.
class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(expenseTransactionsProvider);
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: FxPageHeader.appBar(
        context: context,
        fallbackRoute: '/accounts-hub',
        title: const Text('Expenses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transactions/new?type=expense'),
        icon: const Icon(Icons.add),
        label: const Text('New expense'),
      ),
      body: FxContentContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Draft → Review → Post via the existing journal engine. '
              'Paid expenses require a cash/bank payment account. '
              'Unpaid supplier payables are not invented here — settle via '
              'Settlement Send when needed.',
              style: AppTypography.bodySm(
                context.fx.onSurfaceVariant,
                context: context,
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Expanded(
              child: txsAsync.when(
                loading: () => const FxLoadingState(),
                error: (e, _) => FxErrorState(
                  message: 'Unable to load expenses: $e',
                  onRetry: () => ref.invalidate(expenseTransactionsProvider),
                ),
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return FxEmptyState(
                      message: 'No expense transactions yet.',
                      actionLabel: 'Record expense',
                      onAction: () =>
                          context.push('/transactions/new?type=expense'),
                    );
                  }
                  return ListView.separated(
                    itemCount: expenses.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.stackSm),
                    itemBuilder: (context, i) {
                      final tx = expenses[i];
                      final statusTone = switch (tx.status) {
                        'posted' => FxStatusTone.success,
                        'draft' => FxStatusTone.warning,
                        'voided' || 'reversed' => FxStatusTone.error,
                        _ => FxStatusTone.neutral,
                      };
                      return Material(
                        color: context.fx.surface,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusLg),
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                          onTap: () => context.push('/transactions/${tx.id}'),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.transactionNo ??
                                            tx.id.substring(0, 8),
                                        style: AppTypography.bodySm(
                                          context.fx.onSurfaceVariant,
                                          context: context,
                                        ),
                                      ),
                                      Text(
                                        tx.description?.isNotEmpty == true
                                            ? tx.description!
                                            : 'Expense',
                                        style: AppTypography.bodyMd(
                                          context.fx.onSurface,
                                          context: context,
                                        ).copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        dateFmt.format(tx.transactionDate),
                                        style: AppTypography.bodySm(
                                          context.fx.onSurfaceVariant,
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
                                      'PKR ${fmt.format(tx.totalBaseAmountPkr)}',
                                      style: AppTypography.dataMd(
                                        context.fx.onSurface,
                                        context: context,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FxStatusBadge(
                                      label: tx.status.toUpperCase(),
                                      tone: statusTone,
                                    ),
                                  ],
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
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
      ),
    );
  }
}
