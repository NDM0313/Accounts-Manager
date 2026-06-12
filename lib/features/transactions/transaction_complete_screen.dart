import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/utils/transaction_receipt.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/models/transaction_draft_mode.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TransactionCompleteScreen extends ConsumerWidget {
  const TransactionCompleteScreen({
    super.key,
    required this.transactionId,
    this.draftMode = TransactionDraftMode.standard,
  });

  final String transactionId;
  final TransactionDraftMode draftMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionDetailProvider(transactionId));
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: context.fx.background,
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tx) => Stack(
          children: [
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.fx.primary.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -60,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.fx.tertiary.withValues(alpha: 0.1),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.fx.tertiary.withValues(alpha: 0.15),
                        boxShadow: [
                          BoxShadow(
                            color: context.fx.tertiary.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: -10,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: context.fx.secondary,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      draftMode != TransactionDraftMode.standard
                          ? draftMode.successTitle
                          : 'Transaction Posted',
                      style: AppTypography.headlineLg(
                        context.fx.onSurface,
                        context: context,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tx.partyName != null
                          ? '${tx.currencyCode} ${fmt.format(tx.totalForeignAmount)} · ${tx.partyName}'
                          : 'Your ledger has been updated successfully.',
                      style: AppTypography.bodyMd(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _ReceiptCard(tx: tx, fmt: fmt),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => shareTransactionReceipt(tx),
                        child: const Text('Share Receipt'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: tx.partyId != null
                            ? () => context.go('/parties/${tx.partyId}/ledger')
                            : () => context.go('/transactions/$transactionId'),
                        child: Text(
                          tx.partyId != null ? 'View Statement' : 'View Detail',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.tx, required this.fmt});

  final FxTransaction tx;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tx.transactionType.label.toUpperCase(),
            style: AppTypography.labelCaps(
              context.fx.onSurfaceVariant,
              context: context,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${tx.currencyCode} ${fmt.format(tx.totalForeignAmount)}',
            style: AppTypography.headlineMd(
              context.fx.onSurface,
              context: context,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'PKR ${fmt.format(tx.totalBaseAmountPkr)}',
            style: AppTypography.bodyMd(
              context.fx.onSurfaceVariant,
              context: context,
            ),
          ),
          if (tx.transactionNo != null) ...[
            const SizedBox(height: 12),
            Text(
              'Ref ${tx.transactionNo}',
              style: AppTypography.labelMono(
                context.fx.outline,
                context: context,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
