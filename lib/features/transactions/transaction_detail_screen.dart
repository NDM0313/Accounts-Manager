import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_attachments_section.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_locked_closing_banner.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_dialog.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/core/utils/transaction_receipt.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionDetailProvider(transactionId));
    final journalAsync = ref.watch(journalForTransactionProvider(transactionId));
    final txDate = txAsync.whenOrNull(data: (tx) => tx.transactionDate) ?? DateTime.now();
    final closedAsync = ref.watch(isDayClosedForDateProvider(txDate));
    final fmt = NumberFormat('#,##0.00');
    final dtFmt = DateFormat('d MMM yyyy • HH:mm');
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: isWide
          ? null
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: const Text('Transaction Detail'),
              backgroundColor: context.fx.background,
            ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tx) {
          final fromLine = tx.lines.where((l) => l.debitPkr > 0).firstOrNull;
          final toLine = tx.lines.where((l) => l.creditPkr > 0).firstOrNull;
          final ts = tx.postedAt ?? tx.createdAt ?? tx.transactionDate;
          final txnLabel = tx.transactionNo != null ? '#${tx.transactionNo}' : '#${tx.id.substring(0, 8).toUpperCase()}';
          final isClosed = closedAsync.whenOrNull(data: (v) => v) ?? false;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    isWide ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
                    16,
                    isWide ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
                    16,
                  ),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FxSectionLabel(label: 'Transaction ID'),
                              Text(txnLabel, style: AppTypography.headlineLg(context.fx.onSurface, context: context)),
                              const SizedBox(height: 4),
                              Text(
                                dtFmt.format(ts.toLocal()),
                                style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _IconBtn(
                              icon: Icons.print_outlined,
                              onTap: () => shareTransactionReceipt(tx, subject: 'FX Ledger Receipt'),
                            ),
                            const SizedBox(width: 8),
                            _IconBtn(
                              icon: Icons.share_outlined,
                              onTap: () => shareTransactionReceipt(tx),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.fx.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                        border: Border.all(color: context.fx.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FxSectionLabel(label: 'Net Amount'),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                fmt.format(tx.totalForeignAmount),
                                style: AppTypography.currencyDisplay(color: context.fx.onSurface, context: context),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tx.currencyCode,
                                style: AppTypography.headlineMd(context.fx.onSurfaceVariant, context: context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _CompletedPill(status: tx.status),
                          const SizedBox(height: 8),
                          Text(
                            'PKR ${fmt.format(tx.totalBaseAmountPkr)} @ ${fmt.format(tx.rateUsed)}',
                            style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _DetailGrid(
                      items: [
                        _DetailItem('Date', DateFormat('d MMM yyyy').format(tx.transactionDate)),
                        if (tx.partyId != null)
                          _DetailItem(
                            'Party',
                            _partyLabel(tx),
                            onTap: () => context.push('/parties/${tx.partyId}/ledger'),
                          ),
                        _DetailItem('From', fromLine != null ? '${fromLine.accountCode ?? ''}\n${fromLine.accountName ?? ''}'.trim() : '—'),
                        _DetailItem('To', toLine != null ? '${toLine.accountCode ?? ''}\n${toLine.accountName ?? ''}'.trim() : '—'),
                        _DetailItem('Currency', tx.currencyCode),
                        _DetailItem('Rate', fmt.format(tx.rateUsed)),
                      ],
                    ),
                    if (tx.description != null && tx.description!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      FxSectionLabel(label: 'Notes'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.fx.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(color: context.fx.outlineVariant),
                        ),
                        child: Text(tx.description!, style: AppTypography.bodyMd(context.fx.onSurface, context: context)),
                      ),
                    ],
                    if (isClosed && !tx.isVoided)
                      FxLockedClosingBanner(
                        onRequestEdit: () => _stub(
                          context,
                          'This day is closed. Void the transaction and create a new one, or contact an admin.',
                        ),
                        onRequestDelete: () => _stub(
                          context,
                          'Void is blocked on closed days. Contact an admin if reversal is required.',
                        ),
                      ),
                    if (!tx.isVoided && !tx.isDraft)
                      Consumer(
                        builder: (context, ref, _) {
                          final profile = ref.watch(currentProfileProvider).value;
                          if (profile == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: FxAttachmentsSection(
                              transactionId: transactionId,
                              branchId: profile.branchId,
                              enabled: !isClosed,
                            ),
                          );
                        },
                      ),
                    if (tx.isDraft) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => _post(context, ref),
                        child: const Text('Post to ledger'),
                      ),
                    ],
                    journalAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (journal) {
                        if (journal == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: OutlinedButton(
                            onPressed: () => context.push('/journal/${journal.id}'),
                            child: Text('View journal ${journal.entryNo}'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              if (tx.isVoided)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: FilledButton.tonal(
                    onPressed: () => _restoreTransaction(context, ref),
                    child: const Text('Restore transaction'),
                  ),
                ),
              if (!tx.isVoided) _ActionRow(
                tx: tx,
                dayClosed: isClosed,
                onEdit: () => context.push('/transactions/$transactionId/edit'),
                onDelete: () => _voidTransaction(context, ref, tx),
                onAudit: () => context.push('/transactions/$transactionId/audit'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _stub(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _partyLabel(FxTransaction tx) {
    final name = tx.partyName ?? 'Party';
    if (tx.partyCode != null && tx.partyCode!.isNotEmpty) {
      return '$name (${tx.partyCode})';
    }
    return name;
  }

  Future<void> _restoreTransaction(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Restore transaction'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Reason'),
            maxLines: 2,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Restore')),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty) return;
    try {
      await ref.read(transactionRepositoryProvider).restoreTransaction(
            transactionId: transactionId,
            reason: reason,
          );
      _invalidateAll(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction restored.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }

  Future<void> _voidTransaction(BuildContext context, WidgetRef ref, FxTransaction tx) async {
    final reason = await showFxDeleteTransactionDialog(context, isDraft: tx.isDraft);
    if (reason == null || reason.isEmpty) return;
    try {
      await ref.read(transactionRepositoryProvider).deleteTransaction(
            transactionId: transactionId,
            reason: reason,
          );
      _invalidateAll(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tx.isDraft ? 'Draft deleted.' : 'Transaction voided.')),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(transactionDetailProvider(transactionId));
    ref.invalidate(journalForTransactionProvider(transactionId));
    ref.invalidate(draftTransactionsProvider);
    ref.invalidate(todayTransactionsProvider);
    ref.invalidate(voidedTransactionsProvider);
    ref.invalidate(cashBalancesProvider);
    ref.invalidate(trialBalanceProvider);
    ref.invalidate(trialBalanceTotalsProvider);
    ref.invalidate(auditLogsProvider);
    ref.invalidate(auditLogsForEntityProvider(transactionId));
  }

  Future<void> _post(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(transactionRepositoryProvider).postTransaction(transactionId);
      _invalidateAll(ref);
      if (context.mounted) {
        context.pushReplacement('/transactions/$transactionId/complete');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post failed: $e')));
      }
    }
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: context.fx.outlineVariant),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(icon, color: context.fx.onSurfaceVariant, size: 20),
        ),
      ),
    );
  }
}

class _CompletedPill extends StatelessWidget {
  const _CompletedPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isPosted = status.toLowerCase() == 'posted';
    final isDraft = status.toLowerCase() == 'draft';
    final (label, fg) = isPosted
        ? ('Completed', context.fx.tertiary)
        : isDraft
            ? ('Pending', context.fx.onSurfaceVariant)
            : (status, context.fx.error);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPosted) Icon(Icons.check_circle, size: 16, color: fg),
          if (isPosted) const SizedBox(width: 6),
          Text(label, style: AppTypography.labelCaps(fg, context: context).copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _DetailItem {
  const _DetailItem(this.label, this.value, {this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});
  final List<_DetailItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= 500 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: crossCount == 2 ? 2.4 : 3.5,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final tile = Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.fx.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: context.fx.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FxSectionLabel(label: item.label),
                  const SizedBox(height: 4),
                  Text(
                    item.value,
                    style: AppTypography.bodyMd(
                      item.onTap != null ? context.fx.primary : context.fx.onSurface,
                      context: context,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
            if (item.onTap == null) return tile;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: tile,
              ),
            );
          },
        );
      },
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.tx,
    required this.dayClosed,
    required this.onEdit,
    required this.onDelete,
    required this.onAudit,
  });

  final FxTransaction tx;
  final bool dayClosed;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAudit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        12,
        AppSpacing.marginMobile,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: context.fx.surface,
        border: Border(top: BorderSide(color: context.fx.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: dayClosed ? null : onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(tx.isDraft ? 'Edit draft' : 'Edit'),
              style: FilledButton.styleFrom(
                backgroundColor: context.fx.primary,
                foregroundColor: context.fx.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: dayClosed ? null : onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onAudit,
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Audit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.fx.onSurface,
                side: BorderSide(color: context.fx.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
