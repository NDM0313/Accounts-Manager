import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/utils/transaction_receipt.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/core/widgets/system/fx_confirmation_emblem.dart';
import 'package:accounts_manager/core/widgets/system/fx_status_badge.dart';
import 'package:accounts_manager/domain/models/cash_bank_account.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
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
        data: (tx) {
          // Success chrome only after a confirmed posted backend row.
          if (!tx.isPosted) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Transaction ${tx.status}',
                      style: AppTypography.headlineLg(context.fx.onSurface),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This transaction is not currently posted. Open the draft to finish posting before sharing a receipt.',
                      style: AppTypography.bodyMd(context.fx.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () =>
                          context.go('/transactions/$transactionId'),
                      child: const Text('View transaction'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Done · Back to Home'),
                    ),
                  ],
                ),
              ),
            );
          }

          final remainingLabel = tx.dealId == null
              ? null
              : ref
                    .watch(dealDetailProvider(tx.dealId!))
                    .maybeWhen(
                      data: (deal) {
                        if (deal == null) return null;
                        return 'Remaining on deal: PKR ${fmt.format(deal.customerReceivablePkr)}';
                      },
                      orElse: () => null,
                    );

          return SingleChildScrollView(
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
                      const Center(child: FxConfirmationEmblem()),
                      const SizedBox(height: 24),
                      Text(
                        draftMode == TransactionDraftMode.standard
                            ? 'Transaction recorded'
                            : draftMode.successTitle,
                        style: AppTypography.headlineLg(context.fx.onSurface),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.center,
                        child: FxStatusBadge(
                          label: 'posted',
                          tone: FxStatusTone.success,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _ReceiptCard(
                        tx: tx,
                        fmt: fmt,
                        remainingBalanceLabel: remainingLabel,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Saved to the ledger. You can share the customer receipt or view the updated statement.',
                        style: AppTypography.bodyMd(
                          context.fx.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => shareTransactionReceipt(
                          tx,
                          customerCopy: true,
                        ),
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
          );
        },
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.tx,
    required this.fmt,
    this.remainingBalanceLabel,
  });

  final FxTransaction tx;
  final NumberFormat fmt;
  final String? remainingBalanceLabel;

  @override
  Widget build(BuildContext context) {
    final vault = _vaultLine(tx);
    final method = _methodLabel(vault?.accountCode);
    final reference = _referenceFrom(tx);

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
          const SizedBox(height: 16),
          if (tx.partyName != null)
            _DetailRow(label: 'Party', value: tx.partyName!),
          if (method != null && vault != null)
            _DetailRow(
              label: method,
              value: [
                if ((vault.accountName ?? '').isNotEmpty) vault.accountName!,
                if ((vault.accountCode ?? '').isNotEmpty) vault.accountCode!,
              ].join(' · '),
            ),
          if (reference != null)
            _DetailRow(label: 'Reference', value: reference),
          if (tx.transactionNo != null)
            _DetailRow(label: 'Receipt no', value: tx.transactionNo!),
          if (tx.dealNo != null) _DetailRow(label: 'Deal', value: tx.dealNo!),
          if (remainingBalanceLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              remainingBalanceLabel!,
              style: AppTypography.bodyMd(
                context.fx.onSurface,
                context: context,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static FxTransactionLine? _vaultLine(FxTransaction tx) {
    for (final line in tx.lines) {
      final code = line.accountCode;
      if (code == null) continue;
      final probe = FxAccount(
        id: line.accountId,
        code: code,
        name: line.accountName ?? code,
        accountType: 'asset',
        isActive: true,
      );
      if (CashBankAccountRules.isCashVault(probe) ||
          CashBankAccountRules.isBankVault(probe)) {
        return line;
      }
    }
    if (tx.transactionType == FxTransactionType.settlementReceive) {
      return tx.lines.where((l) => l.debitPkr > 0).firstOrNull;
    }
    if (tx.transactionType == FxTransactionType.settlementSend) {
      return tx.lines.where((l) => l.creditPkr > 0).firstOrNull;
    }
    return tx.lines.firstOrNull;
  }

  static String? _methodLabel(String? accountCode) {
    if (accountCode == null) return null;
    final probe = FxAccount(
      id: accountCode,
      code: accountCode,
      name: accountCode,
      accountType: 'asset',
      isActive: true,
    );
    if (CashBankAccountRules.isBankVault(probe)) return 'Bank account';
    if (CashBankAccountRules.isCashVault(probe)) return 'Cash account';
    return 'Account';
  }

  static String? _referenceFrom(FxTransaction tx) {
    final desc = tx.description ?? '';
    final match = RegExp(r'Ref:\s*([^.]+)').firstMatch(desc);
    final fromDesc = match?.group(1)?.trim();
    if (fromDesc != null && fromDesc.isNotEmpty) return fromDesc;
    return null;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.bodySm(
                context.fx.onSurfaceVariant,
                context: context,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMd(
                context.fx.onSurface,
                context: context,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
