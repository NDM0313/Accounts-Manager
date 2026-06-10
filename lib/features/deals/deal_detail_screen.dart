import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_proof_attachments_section.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/deals/widgets/deal_workflow_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Screen 6 — Deal detail timeline hub with guided workflow.
class DealDetailScreen extends ConsumerWidget {
  const DealDetailScreen({super.key, required this.dealId});

  final String dealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealAsync = ref.watch(dealDetailProvider(dealId));
    final timelineAsync = ref.watch(dealTimelineProvider(dealId));
    final profileAsync = ref.watch(currentProfileProvider);
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: dealAsync.when(
          data: (d) => Text(d?.dealNo ?? 'Deal'),
          loading: () => const Text('Deal'),
          error: (_, __) => const Text('Deal'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.read(dealsRefreshProvider.notifier).refresh()),
          PopupMenuButton<String>(
            onSelected: (route) => context.push(route),
            itemBuilder: (_) => [
              PopupMenuItem(value: '/deals/$dealId/sourcing', child: const Text('Sourcing')),
              PopupMenuItem(value: '/deals/$dealId/legs/agent-source', child: const Text('Agent source')),
              PopupMenuItem(value: '/deals/$dealId/legs/cross-source', child: const Text('Cross source')),
              PopupMenuItem(value: '/deals/$dealId/legs/agent-payment', child: const Text('Agent payment')),
              PopupMenuItem(value: '/deals/$dealId/legs/currency-receipt', child: const Text('Currency receipt')),
              PopupMenuItem(value: '/deals/$dealId/delivery', child: const Text('Delivery')),
            ],
          ),
        ],
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
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(deal: deal, legs: legs, fmt: fmt),
                  const SizedBox(height: 16),
                  DealWorkflowPanel(
                    deal: deal,
                    legs: legs,
                    onReceivePayment: () => _recordPayment(context, ref, deal),
                  ),
                  const SizedBox(height: 16),
                  Text('TIMELINE', style: AppTypography.labelCaps(context.fx.outline, context: context)),
                  const SizedBox(height: 8),
                  if (legs.isEmpty)
                    const Text('No legs yet.')
                  else
                    ...legs.map(
                      (leg) => _TimelineTile(
                        leg: leg,
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

  Future<void> _recordPayment(BuildContext context, WidgetRef ref, FxDeal deal) async {
    final amountCtrl = TextEditingController(text: deal.customerReceivablePkr.toStringAsFixed(0));
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
            FxObsidianFormField(controller: notesCtrl, label: 'Notes', maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;
    final amount = double.tryParse(amountCtrl.text);
    final notes = notesCtrl.text.trim();
    amountCtrl.dispose();
    notesCtrl.dispose();
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid payment amount')));
      return;
    }

    try {
      await ref.read(dealRepositoryProvider).recordCustomerPayment(
            dealId: dealId,
            amountPkr: amount,
            notes: notes.isEmpty ? null : notes,
          );
      ref.read(dealsRefreshProvider.notifier).refresh();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.deal, required this.legs, required this.fmt});

  final FxDeal deal;
  final List<FxDealLeg> legs;
  final NumberFormat fmt;

  double get _agentPayable {
    return legs
        .where((l) => l.legType == FxDealLegType.agentSource || l.legType == FxDealLegType.agentPayment)
        .fold<double>(0, (s, l) => s + l.payAmount);
  }

  @override
  Widget build(BuildContext context) {
    final proofCount = legs.fold<int>(0, (s, l) => s + l.attachmentCount);
    return FxObsidianReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(deal.status.label, style: AppTypography.labelCaps(context.fx.primary, context: context)),
          const SizedBox(height: 8),
          Text(deal.customerName ?? 'Customer', style: AppTypography.headlineMd(context.fx.onSurface, context: context)),
          Text(
            '${fmt.format(deal.sellAmount)} ${displayCurrencyCode(deal.sellCurrencyCode)} @ ${fmt.format(deal.saleRatePkr)} PKR',
            style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
          ),
          const Divider(height: 24),
          _row(context, 'Customer payable', 'PKR ${fmt.format(deal.customerPayablePkr)}'),
          _row(context, 'Customer paid', 'PKR ${fmt.format(deal.customerPaidPkr)}'),
          _row(context, 'Receivable', 'PKR ${fmt.format(deal.customerReceivablePkr)}'),
          if (_agentPayable > 0) _row(context, 'Agent payable (legs)', fmt.format(_agentPayable)),
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
          Text(label, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
          Text(value, style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.leg,
    required this.dealId,
    required this.fmt,
    this.branchId,
  });

  final FxDealLeg leg;
  final String dealId;
  final String? branchId;
  final NumberFormat fmt;

  void _showProof(BuildContext context) {
    if (branchId == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Proof — ${leg.legType.label}', style: AppTypography.headlineMd(context.fx.onSurface, context: context).copyWith(fontSize: 16)),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FxObsidianReportPanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: context.fx.primary.withValues(alpha: 0.2),
              child: Text('${leg.legNo}', style: TextStyle(fontSize: 11, color: context.fx.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(leg.legType.label, style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600)),
                      ),
                      if (leg.attachmentCount > 0)
                        InkWell(
                          onTap: () => _showProof(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.attach_file, size: 16, color: context.fx.primary),
                              Text(' ${leg.attachmentCount}', style: TextStyle(fontSize: 11, color: context.fx.primary)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (leg.counterpartyName != null)
                    Text(leg.counterpartyName!, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
                  if (leg.receiveAmount > 0 && leg.receiveCurrency != null)
                    Text('Recv ${fmt.format(leg.receiveAmount)} ${leg.receiveCurrency}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
                  if (leg.payAmount > 0 && leg.payCurrency != null)
                    Text('Pay ${fmt.format(leg.payAmount)} ${leg.payCurrency}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
                  if (leg.proofReference != null && leg.proofReference!.isNotEmpty)
                    Text('Ref: ${leg.proofReference}', style: AppTypography.bodyMd(context.fx.outline, context: context).copyWith(fontSize: 11)),
                  if (leg.linkedTransactionNo != null)
                    Text('Tx ${leg.linkedTransactionNo}', style: AppTypography.bodyMd(context.fx.outline, context: context).copyWith(fontSize: 11)),
                  Text(leg.status.label, style: AppTypography.labelCaps(context.fx.tertiary, context: context).copyWith(fontSize: 9)),
                  TextButton.icon(
                    onPressed: branchId != null ? () => _showProof(context) : null,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                    label: Text(leg.attachmentCount > 0 ? 'View proof' : 'Add proof'),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          Text('PROFIT / LOSS', style: AppTypography.labelCaps(context.fx.outline, context: context)),
          const SizedBox(height: 8),
          if (deal.actualProfitPkr != null)
            Text('Actual: PKR ${fmt.format(deal.actualProfitPkr)}', style: AppTypography.headlineMd(context.fx.onSurface, context: context).copyWith(fontSize: 18))
          else
            Text(
              'Actual profit calculated after delivery when cost basis is known.',
              style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
            ),
          if (deal.costBasisPkr != null)
            Text('Cost basis: PKR ${fmt.format(deal.costBasisPkr)}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
