import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/export/fx_document_export.dart';
import 'package:accounts_manager/core/export/remittance_receipt_builder.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/premium/fx_timeline_step_card.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/domain/models/fx_remittance_event.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:accounts_manager/features/remittance/widgets/remittance_attachments_section.dart';
import 'package:accounts_manager/features/remittance/widgets/remittance_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RemittanceDetailScreen extends ConsumerWidget {
  const RemittanceDetailScreen({super.key, required this.remittanceId});

  final String remittanceId;

  static final _dtFmt = DateFormat('dd MMM yyyy, HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remAsync = ref.watch(remittanceDetailProvider(remittanceId));
    final timelineAsync = ref.watch(remittanceTimelineProvider(remittanceId));
    final fmt = NumberFormat('#,##0.00');

    return FxPageScaffold(
      fallbackRoute: '/remittance',
      title: remAsync.when(
        data: (r) => Text(r?.remittanceNo ?? r?.trackingId ?? 'Remittance'),
        loading: () => const Text('Remittance'),
        error: (_, _) => const Text('Remittance'),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.ios_share_outlined),
          onPressed: () => _showExportPicker(context, remAsync.value),
        ),
      ],
      body: remAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (r) {
          if (r == null) {
            return const Center(child: Text('Remittance not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RemittanceSummaryCard(remittance: r, fmt: fmt),
              const SizedBox(height: 12),
              _actionButtons(context, ref, r),
              const SizedBox(height: 16),
              RemittanceAttachmentsSection(
                remittanceId: remittanceId,
                branchId: r.branchId ?? '',
                title: 'Remittance proofs',
              ),
              const SizedBox(height: 16),
              Text(
                'Timeline',
                style: AppTypography.labelCaps(
                  context.fx.outline,
                  context: context,
                ),
              ),
              const SizedBox(height: 8),
              timelineAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (events) => Column(
                  children: events
                      .map((e) => _eventTile(context, e, fmt))
                      .toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _actionButtons(BuildContext context, WidgetRef ref, FxRemittance r) {
    final actions = <Widget>[];

    if (r.status == FxRemittanceStatus.booked && r.balanceDue > 0) {
      actions.add(
        FilledButton(
          onPressed: () => context.push('/remittance/$remittanceId/payment'),
          child: const Text('Receive Payment'),
        ),
      );
    }
    if (r.status == FxRemittanceStatus.customerPaid && r.isFullyPaid) {
      actions.add(
        FilledButton(
          onPressed: () =>
              context.push('/remittance/$remittanceId/assign-agent'),
          child: const Text('Send to Agent'),
        ),
      );
    }
    if (r.status == FxRemittanceStatus.sentToAgent ||
        r.status == FxRemittanceStatus.readyForPayout) {
      actions.add(
        FilledButton(
          onPressed: () => context.push('/remittance/$remittanceId/payout'),
          child: const Text('Confirm Payout'),
        ),
      );
    }
    if (r.status == FxRemittanceStatus.paidOut) {
      actions.add(
        FilledButton(
          onPressed: () => context.push('/remittance/$remittanceId/settlement'),
          child: const Text('Mark Settled'),
        ),
      );
    }
    if (r.status == FxRemittanceStatus.completed ||
        r.status == FxRemittanceStatus.cancelled) {
      actions.add(
        OutlinedButton(
          onPressed: () => _showExportPicker(context, r),
          child: const Text('View / Print'),
        ),
      );
    }
    if (r.status == FxRemittanceStatus.booked && r.paidAmount <= 0) {
      actions.add(
        TextButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Cancel remittance?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('No'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Cancel order'),
                  ),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              await ref.read(remittanceRepositoryProvider).cancel(remittanceId);
              ref.read(remittancesRefreshProvider.notifier).refresh();
            }
          },
          child: const Text('Cancel order'),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }

  Widget _eventTile(
    BuildContext context,
    FxRemittanceEvent e,
    NumberFormat fmt,
  ) {
    final lines = <String>[
      if (e.createdAt != null) _dtFmt.format(e.createdAt!.toLocal()),
      if (e.createdByName != null)
        'By ${e.createdByName}${e.actorRole != null ? ' (${e.actorRole})' : ''}',
      if (e.branchName != null) 'Branch: ${e.branchName}',
      if (e.statusAfter != null) 'Status: ${e.statusAfter!.label}',
      if (e.amount != null && e.currencyCode != null)
        'Amount: ${e.currencyCode} ${fmt.format(e.amount)}',
      if (e.proofReference != null) 'Ref: ${e.proofReference}',
      if (e.notes != null && e.notes!.isNotEmpty) e.notes!,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FxTimelineStepCard(
        title: '${e.eventNo}. ${e.eventType.label}',
        subtitle: lines.join(' · '),
        statusLabel: e.statusAfter?.label ?? e.eventType.label,
        proofCount: e.attachmentCount,
        onTap: e.linkedTransactionId != null
            ? () => context.push('/transactions/${e.linkedTransactionId}')
            : (e.attachmentCount > 0 ? () {} : null),
      ),
    );
  }

  Future<void> _showExportPicker(BuildContext context, FxRemittance? r) async {
    if (r == null) return;
    final choice = await showModalBottomSheet<RemittanceReceiptType>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Customer copy'),
              onTap: () => Navigator.pop(ctx, RemittanceReceiptType.customer),
            ),
            ListTile(
              title: const Text('Internal copy'),
              onTap: () => Navigator.pop(ctx, RemittanceReceiptType.internal),
            ),
            if (r.status.index >= FxRemittanceStatus.sentToAgent.index)
              ListTile(
                title: const Text('Agent payout slip'),
                onTap: () =>
                    Navigator.pop(ctx, RemittanceReceiptType.agentSlip),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final customerCopy = choice == RemittanceReceiptType.customer;
    final text = formatRemittanceReceipt(r, receiptType: choice);
    final pdf = await buildRemittanceReceiptPdf(r, receiptType: choice);
    if (!context.mounted) return;
    await showFxExportSheet(
      context,
      mode: customerCopy ? FxExportMode.customerFacing : FxExportMode.internal,
      document: FxExportDocument(
        title: 'Remittance ${r.trackingId}',
        textBody: text,
        pdfBytes: pdf,
        subject: 'Remittance ${r.trackingId}',
      ),
    );
  }
}
