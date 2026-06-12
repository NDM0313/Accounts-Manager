import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_proof_attachments_section.dart';
import 'package:accounts_manager/core/widgets/premium/fx_timeline_step_card.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/services/deal_leg_permissions.dart';
import 'package:accounts_manager/domain/services/deal_workflow_narrative.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/deals/widgets/deal_detail_quick_links.dart';
import 'package:accounts_manager/features/deals/widgets/deal_workflow_panel.dart';
import 'package:accounts_manager/features/deals/widgets/deal_workflow_summary.dart';
import 'package:accounts_manager/features/messaging/widgets/entity_chat_panel.dart';
import 'package:accounts_manager/domain/models/fx_conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Screen 6 — Deal detail timeline hub with guided workflow.
class DealDetailScreen extends ConsumerStatefulWidget {
  const DealDetailScreen({super.key, required this.dealId});

  final String dealId;

  @override
  ConsumerState<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends ConsumerState<DealDetailScreen> {
  final _timelineKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final dealId = widget.dealId;
    final dealAsync = ref.watch(dealDetailProvider(dealId));
    final timelineAsync = ref.watch(dealTimelineProvider(dealId));
    final profileAsync = ref.watch(currentProfileProvider);
    final fmt = NumberFormat('#,##0.00');

    return FxPageScaffold(
      fallbackRoute: '/deals',
      title: dealAsync.when(
        data: (d) => Text(d?.dealNo ?? 'Deal'),
        loading: () => const Text('Deal'),
        error: (_, _) => const Text('Deal'),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.read(dealsRefreshProvider.notifier).refresh(),
        ),
        PopupMenuButton<String>(
          onSelected: (route) {
            timelineAsync.whenOrNull(
              data: (legs) {
                final type = DealLegPermissions.legTypeForAddRoute(route);
                if (type != null &&
                    DealLegPermissions.hasPendingLegOfType(legs, type)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Pending ${type.label} already exists — edit it from the timeline or add another intentionally.',
                      ),
                    ),
                  );
                }
              },
            );
            context.push(route);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: '/deals/$dealId/sourcing',
              child: const Text('Sourcing'),
            ),
            PopupMenuItem(
              value: '/deals/$dealId/legs/agent-source',
              child: const Text('Agent source'),
            ),
            PopupMenuItem(
              value: '/deals/$dealId/legs/cross-source',
              child: const Text('Cross source'),
            ),
            PopupMenuItem(
              value: '/deals/$dealId/legs/agent-payment',
              child: const Text('Agent payment'),
            ),
            PopupMenuItem(
              value: '/deals/$dealId/legs/currency-receipt',
              child: const Text('Currency receipt'),
            ),
            PopupMenuItem(
              value: '/deals/$dealId/delivery',
              child: const Text('Delivery'),
            ),
          ],
        ),
      ],
      body: dealAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (deal) {
          if (deal == null) return const Center(child: Text('Deal not found'));

          return timelineAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Timeline error: $e')),
            data: (legs) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(deal: deal, legs: legs, fmt: fmt),
                  const SizedBox(height: 12),
                  DealDetailQuickLinks(
                    deal: deal,
                    legs: legs,
                    dealId: dealId,
                    onViewProofs: () {
                      final ctx = _timelineKey.currentContext;
                      if (ctx != null) {
                        Scrollable.ensureVisible(
                          ctx,
                          duration: const Duration(milliseconds: 300),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  EntityChatPanel(
                    type: FxConversationType.deal,
                    dealId: dealId,
                    title: deal.dealNo ?? 'Deal',
                  ),
                  const SizedBox(height: 16),
                  DealWorkflowSummary(deal: deal, legs: legs),
                  const SizedBox(height: 16),
                  DealWorkflowPanel(
                    deal: deal,
                    legs: legs,
                    onReceivePayment: () => _recordPayment(context, ref, deal),
                  ),
                  const SizedBox(height: 16),
                  KeyedSubtree(
                    key: _timelineKey,
                    child: Text(
                      'TIMELINE',
                      style: AppTypography.labelCaps(
                        context.fx.outline,
                        context: context,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (legs.isEmpty)
                    const Text('No legs yet.')
                  else
                    ...legs.map(
                      (leg) => _TimelineTile(
                        leg: leg,
                        deal: deal,
                        dealId: dealId,
                        branchId: profileAsync.value?.branchId,
                        fmt: fmt,
                      ),
                    ),
                  const SizedBox(height: 16),
                  _ProfitSection(deal: deal, fmt: fmt),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _recordPayment(
    BuildContext context,
    WidgetRef ref,
    FxDeal deal,
  ) async {
    final amountCtrl = TextEditingController(
      text: deal.customerReceivablePkr.toStringAsFixed(0),
    );
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record customer payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FxObsidianFormField(
              controller: amountCtrl,
              label: 'Amount (PKR)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            FxObsidianFormField(
              controller: notesCtrl,
              label: 'Notes',
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;
    final amount = double.tryParse(amountCtrl.text);
    final notes = notesCtrl.text.trim();
    amountCtrl.dispose();
    notesCtrl.dispose();
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid payment amount')),
      );
      return;
    }

    try {
      await ref
          .read(dealRepositoryProvider)
          .recordCustomerPayment(
            dealId: widget.dealId,
            amountPkr: amount,
            notes: notes.isEmpty ? null : notes,
          );
      ref.read(dealsRefreshProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment recorded')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.deal,
    required this.legs,
    required this.fmt,
  });

  final FxDeal deal;
  final List<FxDealLeg> legs;
  final NumberFormat fmt;

  double get _agentPayable {
    return legs
        .where(
          (l) =>
              l.legType == FxDealLegType.agentSource ||
              l.legType == FxDealLegType.agentPayment,
        )
        .fold<double>(0, (s, l) => s + l.payAmount);
  }

  @override
  Widget build(BuildContext context) {
    final proofCount = legs.fold<int>(0, (s, l) => s + l.attachmentCount);
    return FxObsidianReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deal.status.label,
            style: AppTypography.labelCaps(
              context.fx.primary,
              context: context,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            deal.customerName ?? 'Customer',
            style: AppTypography.headlineMd(
              context.fx.onSurface,
              context: context,
            ),
          ),
          Text(
            '${fmt.format(deal.sellAmount)} ${displayCurrencyCode(deal.sellCurrencyCode)} @ ${fmt.format(deal.saleRatePkr)} PKR',
            style: AppTypography.bodyMd(
              context.fx.onSurfaceVariant,
              context: context,
            ),
          ),
          const Divider(height: 24),
          _row(
            context,
            'Customer payable',
            'PKR ${fmt.format(deal.customerPayablePkr)}',
          ),
          _row(
            context,
            'Customer paid',
            'PKR ${fmt.format(deal.customerPaidPkr)}',
          ),
          _row(
            context,
            'Receivable',
            'PKR ${fmt.format(deal.customerReceivablePkr)}',
          ),
          if (_agentPayable > 0)
            _row(context, 'Agent payable (legs)', fmt.format(_agentPayable)),
          _row(context, 'Proof attachments', '$proofCount'),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMd(
              context.fx.onSurfaceVariant,
              context: context,
            ).copyWith(fontSize: 12),
          ),
          Text(
            value,
            style: AppTypography.bodyMd(
              context.fx.onSurface,
              context: context,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends ConsumerWidget {
  const _TimelineTile({
    required this.leg,
    required this.deal,
    required this.dealId,
    required this.fmt,
    this.branchId,
  });

  final FxDealLeg leg;
  final FxDeal deal;
  final String dealId;
  final String? branchId;
  final NumberFormat fmt;

  void _showProof(BuildContext context) {
    if (branchId == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Proof — ${leg.legType.label}',
              style: AppTypography.headlineMd(
                context.fx.onSurface,
                context: context,
              ).copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            FxProofAttachmentsSection(
              branchId: branchId!,
              dealId: dealId,
              dealLegId: leg.id,
              attachmentType: 'proof',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _openTransaction(BuildContext context, WidgetRef ref) async {
    final no = leg.linkedTransactionNo;
    if (no == null || branchId == null) return;
    final txId = await ref
        .read(transactionRepositoryProvider)
        .fetchTransactionIdByNo(branchId!, no);
    if (txId != null && context.mounted) context.push('/transactions/$txId');
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${leg.legType.label}?'),
        content: Text(
          'Remove step ${leg.legNo} (${leg.legType.label})? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(dealRepositoryProvider).deleteLeg(leg.id);
      ref.read(dealsRefreshProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Step deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String _subtitle(NumberFormat fmt) {
    final parts = <String>[];
    if (leg.counterpartyName != null) parts.add(leg.counterpartyName!);
    if (leg.receiveAmount > 0 && leg.receiveCurrency != null) {
      parts.add('Recv ${fmt.format(leg.receiveAmount)} ${leg.receiveCurrency}');
    }
    if (leg.payAmount > 0 && leg.payCurrency != null) {
      parts.add('Pay ${fmt.format(leg.payAmount)} ${leg.payCurrency}');
    }
    if (leg.proofReference != null && leg.proofReference!.isNotEmpty) {
      parts.add('Ref: ${leg.proofReference}');
    }
    if (leg.linkedTransactionNo != null) {
      parts.add('Tx ${leg.linkedTransactionNo}');
    }
    return parts.isEmpty ? leg.legType.label : parts.join(' · ');
  }

  void _showLegMenu(
    BuildContext context,
    WidgetRef ref, {
    required bool canEdit,
    required bool canDelete,
    required String? editRoute,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.fx.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit && editRoute != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(editRoute);
                },
              ),
            if (canDelete)
              ListTile(
                leading: Icon(Icons.delete_outline, color: context.fx.error),
                title: Text(
                  'Delete',
                  style: TextStyle(color: context.fx.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, ref);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = DealLegTimelineActions.forLeg(
      leg: leg,
      deal: deal,
      customerPartyId: deal.customerPartyId,
    );
    final canEdit = DealLegPermissions.canEditLeg(leg, deal);
    final canDelete = DealLegPermissions.canDeleteLeg(leg, deal);
    final editRoute = DealLegPermissions.editRoute(leg: leg, deal: deal);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxTimelineStepCard(
            title: 'Step ${leg.legNo} · ${leg.legType.label}',
            subtitle: _subtitle(fmt),
            statusLabel: leg.status.label,
            proofCount: leg.attachmentCount,
            isActive:
                leg.status == FxDealLegStatus.pending ||
                leg.status == FxDealLegStatus.partial,
            onTap: leg.linkedTransactionNo != null
                ? () => _openTransaction(context, ref)
                : (branchId != null && leg.attachmentCount > 0
                      ? () => _showProof(context)
                      : null),
            onMenu: (canEdit || canDelete)
                ? () => _showLegMenu(
                    context,
                    ref,
                    canEdit: canEdit,
                    canDelete: canDelete,
                    editRoute: editRoute,
                  )
                : null,
          ),
          if (branchId != null || action != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Wrap(
                spacing: 4,
                children: [
                  if (branchId != null)
                    TextButton.icon(
                      onPressed: () => _showProof(context),
                      icon: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 16,
                      ),
                      label: Text(
                        leg.attachmentCount > 0 ? 'View proof' : 'Add proof',
                      ),
                    ),
                  if (action != null)
                    TextButton(
                      onPressed: () {
                        switch (action.onTapKind) {
                          case DealLegActionKind.viewCustomerStatement:
                            context.push(
                              '/parties/${deal.customerPartyId}/ledger',
                            );
                          case DealLegActionKind.viewProof:
                            _showProof(context);
                          case null:
                            if (action.route != null) {
                              context.push(action.route!);
                            }
                        }
                      },
                      child: Text(action.label),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfitSection extends StatelessWidget {
  const _ProfitSection({required this.deal, required this.fmt});

  final FxDeal deal;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return FxObsidianReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROFIT / LOSS',
            style: AppTypography.labelCaps(
              context.fx.outline,
              context: context,
            ),
          ),
          const SizedBox(height: 8),
          if (deal.actualProfitPkr != null)
            Text(
              'Actual: PKR ${fmt.format(deal.actualProfitPkr)}',
              style: AppTypography.headlineMd(
                context.fx.onSurface,
                context: context,
              ).copyWith(fontSize: 18),
            )
          else
            Text(
              'Actual profit calculated after delivery when cost basis is known.',
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 12),
            ),
          if (deal.costBasisPkr != null)
            Text(
              'Cost basis: PKR ${fmt.format(deal.costBasisPkr)}',
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 12),
            ),
        ],
      ),
    );
  }
}
