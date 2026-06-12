import 'package:accounts_manager/core/export/fx_document_export.dart';
import 'package:accounts_manager/core/export/remittance_receipt_builder.dart';
import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_action_tile.dart';
import 'package:accounts_manager/core/widgets/premium/fx_section_header.dart';
import 'package:accounts_manager/core/widgets/premium/fx_timeline_step_card.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_remittance_widgets.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/domain/models/fx_remittance_event.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:accounts_manager/features/remittance/widgets/remittance_attachments_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class RemittanceDetailScreen extends ConsumerWidget {
  const RemittanceDetailScreen({super.key, required this.remittanceId});

  final String remittanceId;

  static final _dtFmt = DateFormat('dd MMM yyyy, HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remAsync = ref.watch(remittanceDetailProvider(remittanceId));
    final timelineAsync = ref.watch(remittanceTimelineProvider(remittanceId));
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.surface,
        title: Text(
          'FX Cash Ledger',
          style: AppTypography.headlineSm(
            context.fx.primary,
            context: context,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(remittanceDetailProvider(remittanceId));
              ref.invalidate(remittanceTimelineProvider(remittanceId));
            },
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () => _showExportPicker(
              context,
              remAsync.whenOrNull(data: (v) => v),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: remAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (r) {
          if (r == null) {
            return const Center(child: Text('Remittance not found.'));
          }
          final tracking =
              r.trackingId.isNotEmpty ? r.trackingId : (r.remittanceNo ?? '—');
          final ready = r.status == FxRemittanceStatus.readyForPayout ||
              r.status == FxRemittanceStatus.paidOut;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FxStitchRemittanceMtcnHeader(
                trackingId: tracking,
                statusLabel: r.status.label,
                showReadyPill: ready,
              ),
              const SizedBox(height: 16),
              FxStitchRemittancePayoutLayout(
                remittance: r,
                fmt: fmt,
                onSharePickup: () {
                  SharePlus.instance.share(
                    ShareParams(
                      text:
                          'Pickup: ${r.payoutAgentName ?? 'Agent'} — ${r.trackingId}',
                    ),
                  );
                },
                actionSection: _actionButtons(context, ref, r),
                timelineSection: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RemittanceAttachmentsSection(
                      remittanceId: remittanceId,
                      branchId: r.branchId ?? '',
                      title: 'Remittance proofs',
                    ),
                    const SizedBox(height: 16),
                    const FxSectionHeader(label: 'Timeline'),
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
                ),
              ),
              const FxStitchRemittanceComplianceFooter(),
            ],
          );
        },
      ),
    );
  }

  Widget _actionButtons(BuildContext context, WidgetRef ref, FxRemittance r) {
    final tiles = <Widget>[];

    void addTile(
      String title,
      String subtitle,
      IconData icon,
      VoidCallback onTap,
    ) {
      tiles.add(
        FxActionTile(
          title: title,
          subtitle: subtitle,
          icon: icon,
          onTap: onTap,
        ),
      );
    }

    if (r.status == FxRemittanceStatus.booked && r.balanceDue > 0) {
      addTile(
        'Receive Payment',
        'Balance due ${r.balanceDue.toStringAsFixed(2)}',
        Icons.payments_outlined,
        () => context.push('/remittance/$remittanceId/payment'),
      );
    }
    if (r.status == FxRemittanceStatus.customerPaid && r.isFullyPaid) {
      addTile(
        'Send to Agent',
        'Assign payout agent',
        Icons.send_outlined,
        () => context.push('/remittance/$remittanceId/assign-agent'),
      );
    }
    if (r.status == FxRemittanceStatus.sentToAgent ||
        r.status == FxRemittanceStatus.readyForPayout) {
      addTile(
        'Confirm Payout',
        'Branch payout confirmation',
        Icons.check_circle_outline,
        () => context.push('/remittance/$remittanceId/payout'),
      );
    }
    if (r.status == FxRemittanceStatus.paidOut) {
      addTile(
        'Mark Settled',
        'Complete agent settlement',
        Icons.done_all_outlined,
        () => context.push('/remittance/$remittanceId/settlement'),
      );
    }
    if (r.status == FxRemittanceStatus.completed ||
        r.status == FxRemittanceStatus.cancelled) {
      addTile(
        'View / Print',
        'Customer, internal, or agent slip',
        Icons.receipt_long_outlined,
        () => _showExportPicker(context, r),
      );
    }
    if (r.status == FxRemittanceStatus.booked && r.paidAmount <= 0) {
      addTile(
        'Cancel order',
        'Void before any payment',
        Icons.cancel_outlined,
        () async {
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
      );
    }

    if (tiles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FxSectionHeader(label: 'Actions'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: tiles),
      ],
    );
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
