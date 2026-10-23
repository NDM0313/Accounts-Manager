import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/core/widgets/system/fx_confirmation_emblem.dart';
import 'package:accounts_manager/core/widgets/system/fx_status_badge.dart';
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

    return FxPremiumScaffold(
      title: const Text('Confirmation'),
      fallbackRoute: '/',
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load transaction: $e')),
        data: (tx) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.fx.surface,
                  border: Border.all(color: context.fx.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tx.isPosted)
                      const Center(child: FxConfirmationEmblem()),
                    const SizedBox(height: 24),
                    Text(
                      tx.isPosted
                          ? (draftMode == TransactionDraftMode.standard
                                ? 'Transaction recorded'
                                : draftMode.successTitle)
                          : 'Transaction ${tx.status}',
                      style: AppTypography.headlineLg(context.fx.onSurface),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: FxStatusBadge(
                        label: tx.status,
                        tone: tx.isPosted
                            ? FxStatusTone.success
                            : FxStatusTone.warning,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ReceiptCard(tx: tx, fmt: fmt),
                    if (tx.partyName != null) ...[
                      const SizedBox(height: 12),
                      Text(tx.partyName!),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      tx.isPosted
                          ? 'Saved to the ledger. You can share the receipt or view the updated statement.'
                          : 'This transaction is not currently posted.',
                      style: AppTypography.bodyMd(context.fx.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: tx.isPosted
                          ? () => shareTransactionReceipt(tx)
                          : null,
                      icon: const Icon(Icons.ios_share, size: 20),
                      label: const Text('Share receipt'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          context.go('/transactions/$transactionId'),
                      child: const Text('View transaction'),
                    ),
                    if (tx.partyId != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () =>
                            context.go('/parties/${tx.partyId}/ledger'),
                        child: const Text('View statement'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Done · Back to Home'),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
