import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/export/fx_document_export.dart';
import 'package:accounts_manager/core/utils/deal_statement.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_deal_bottom_bar.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_deal_widgets.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/services/deal_workflow_guide.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DealDetailScreen extends ConsumerStatefulWidget {
  const DealDetailScreen({super.key, required this.dealId});

  final String dealId;

  @override
  ConsumerState<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends ConsumerState<DealDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final dealId = widget.dealId;
    final dealAsync = ref.watch(dealDetailProvider(dealId));
    final timelineAsync = ref.watch(dealTimelineProvider(dealId));
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: dealAsync.when(
          data: (d) => Text(d?.dealNo ?? 'Deal'),
          loading: () => const Text('Deal'),
          error: (_, _) => const Text('Deal'),
        ),
        actions: [
          dealAsync.whenOrNull(
                data: (d) => d == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _StatusPill(label: d.status.label),
                      ),
              ) ??
              const SizedBox.shrink(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(dealsRefreshProvider.notifier).refresh(),
          ),
        ],
      ),
      bottomNavigationBar: dealAsync.whenOrNull(
        data: (deal) => deal == null
            ? null
            : FxStitchDealBottomBar(
                onViewStatement: () => context.push(
                  '/parties/${deal.customerPartyId}/ledger',
                ),
                onShareDeal: () => _shareDeal(
                  context,
                  deal,
                  timelineAsync.whenOrNull(data: (v) => v) ?? [],
                ),
                onViewJournal: () => _openJournal(
                  context,
                  dealId,
                  timelineAsync.whenOrNull(data: (v) => v) ?? [],
                ),
              ),
      ),
      body: dealAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (deal) {
          if (deal == null) return const Center(child: Text('Deal not found'));

          return timelineAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Timeline error: $e')),
            data: (legs) {
              final workflow = DealWorkflowGuide.build(deal: deal, legs: legs);
              final completedSteps = workflow.steps
                  .where((s) => s.status == DealWorkflowStepStatus.completed)
                  .length;
              final totalSteps = workflow.steps
                  .where((s) => s.status != DealWorkflowStepStatus.skipped)
                  .length;
              final progress =
                  totalSteps > 0 ? completedSteps / totalSteps : 0.0;

              return LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 900;
                  final timeline = FxStitchWorkflowTimeline(
                    steps: workflow.steps,
                    onStepTap: (step) {
                      if (step.route != null) context.push(step.route!);
                    },
                    onProofTap: (step) => _handleProofTap(
                      context,
                      step,
                      legs,
                    ),
                  );
                  final sidebar = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!workflow.isCompleted)
                        FxStitchDealNextActionCard(
                          title: workflow.nextActionTitle,
                          actionLabel: _nextActionLabel(workflow),
                          onAction: () =>
                              _handleNextAction(context, deal, workflow),
                        ),
                      if (workflow.warningText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          workflow.warningText!,
                          style: AppTypography.bodySm(
                            context.fx.warning,
                            context: context,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FxStitchDealHealthCard(
                        progress: progress,
                        caption: workflow.isCompleted
                            ? 'Deal completed successfully.'
                            : 'Processing ${(progress * 100).round()}% through workflow.',
                      ),
                    ],
                  );

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      FxStitchDealSummaryCard(
                        customer: deal.customerName ?? 'Customer',
                        amount:
                            '${fmt.format(deal.sellAmount)} ${displayCurrencyCode(deal.sellCurrencyCode)}',
                        rate: fmt.format(deal.saleRatePkr),
                        pkrTotal: 'PKR ${fmt.format(deal.customerPayablePkr)}',
                      ),
                      const SizedBox(height: 12),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: timeline),
                            const SizedBox(width: 12),
                            Expanded(child: sidebar),
                          ],
                        )
                      else ...[
                        timeline,
                        const SizedBox(height: 12),
                        sidebar,
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _handleProofTap(
    BuildContext context,
    DealWorkflowStep step,
    List<FxDealLeg> legs,
  ) {
    if (step.route != null) {
      context.push(step.route!);
      return;
    }
    for (final leg in legs) {
      if (leg.attachmentCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Proof on ${leg.legType.label}')),
        );
        return;
      }
    }
  }

  String _nextActionLabel(DealWorkflowView workflow) {
    if (workflow.nextActionRoute != null) return 'Continue';
    if (workflow.nextActionTitle.toLowerCase().contains('payment')) {
      return 'Confirm Receipt';
    }
    return 'Take Action';
  }

  void _handleNextAction(
    BuildContext context,
    FxDeal deal,
    DealWorkflowView workflow,
  ) {
    if (workflow.nextActionRoute != null) {
      context.push(workflow.nextActionRoute!);
      return;
    }
    if (workflow.nextActionTitle.toLowerCase().contains('payment')) {
      _recordPayment(context, ref, deal);
    }
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      await ref.read(dealRepositoryProvider).recordCustomerPayment(
            dealId: widget.dealId,
            amountPkr: amount,
            notes: notes.isEmpty ? null : notes,
          );
      ref.read(dealsRefreshProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _shareDeal(
    BuildContext context,
    FxDeal deal,
    List<FxDealLeg> legs,
  ) async {
    final text = buildDealStatementText(deal: deal, legs: legs, internal: false);
    await showFxExportSheet(
      context,
      mode: FxExportMode.customerFacing,
      document: FxExportDocument(
        title: 'Deal ${deal.dealNo ?? deal.id}',
        textBody: text,
        subject: 'Deal ${deal.dealNo ?? deal.id}',
      ),
    );
  }

  Future<void> _openJournal(
    BuildContext context,
    String dealId,
    List<FxDealLeg> legs,
  ) async {
    final linkedNos = legs
        .map((l) => l.linkedTransactionNo)
        .whereType<String>()
        .toList();
    if (linkedNos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No journal entries linked yet.')),
      );
      return;
    }
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null || !context.mounted) return;
    final repo = ref.read(transactionRepositoryProvider);
    for (final no in linkedNos) {
      final txId = await repo.fetchTransactionIdByNo(profile.branchId, no);
      if (txId != null && context.mounted) {
        context.push('/transactions/$txId');
        return;
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal entry not found.')),
      );
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.fx.tertiaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: context.fx.tertiaryContainer.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelCaps(
          context.fx.onTertiary,
          context: context,
        ).copyWith(fontSize: 8),
      ),
    );
  }
}
