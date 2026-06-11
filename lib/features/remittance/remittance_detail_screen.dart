import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/export/fx_document_export.dart';
import 'package:accounts_manager/core/export/remittance_receipt_builder.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/premium/fx_timeline_step_card.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/domain/models/fx_remittance_event.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:accounts_manager/features/remittance/widgets/remittance_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RemittanceDetailScreen extends ConsumerWidget {
  const RemittanceDetailScreen({super.key, required this.remittanceId});

  final String remittanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remAsync = ref.watch(remittanceDetailProvider(remittanceId));
    final timelineAsync = ref.watch(remittanceTimelineProvider(remittanceId));
    final fmt = NumberFormat('#,##0.00');

    return FxPageScaffold(
      fallbackRoute: '/remittance',
      title: remAsync.when(
        data: (r) => Text(r?.trackingId ?? 'Remittance'),
        loading: () => const Text('Remittance'),
        error: (_, _) => const Text('Remittance'),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.ios_share_outlined),
          onPressed: () async {
            final r = remAsync.value;
            if (r == null) return;
            await _shareReceipt(context, r, customerCopy: true);
          },
        ),
      ],
      body: remAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (r) {
          if (r == null) return const Center(child: Text('Remittance not found.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RemittanceSummaryCard(remittance: r, fmt: fmt),
              const SizedBox(height: 12),
              _actionButtons(context, ref, r),
              const SizedBox(height: 16),
              Text('Timeline', style: AppTypography.labelCaps(context.fx.outline, context: context)),
              const SizedBox(height: 8),
              timelineAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (events) => Column(
                  children: events.map((e) => _eventTile(context, e, fmt)).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _actionButtons(BuildContext context, WidgetRef ref, FxRemittance r) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (r.status == FxRemittanceStatus.booked || r.status == FxRemittanceStatus.customerPaid)
          FilledButton(
            onPressed: () => context.push('/remittance/$remittanceId/payment'),
            child: const Text('Customer payment'),
          ),
        if (r.status == FxRemittanceStatus.customerPaid)
          OutlinedButton(
            onPressed: () => context.push('/remittance/$remittanceId/assign-agent'),
            child: const Text('Send to agent'),
          ),
        if (r.status == FxRemittanceStatus.sentToAgent || r.status == FxRemittanceStatus.readyForPayout)
          FilledButton(
            onPressed: () => context.push('/remittance/$remittanceId/payout'),
            child: const Text('Confirm payout'),
          ),
        if (r.status == FxRemittanceStatus.paidOut)
          FilledButton(
            onPressed: () => context.push('/remittance/$remittanceId/settlement'),
            child: const Text('Agent settlement'),
          ),
        if (r.status == FxRemittanceStatus.booked)
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cancel remittance?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel order')),
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
      ],
    );
  }

  Widget _eventTile(BuildContext context, FxRemittanceEvent e, NumberFormat fmt) {
    final subtitle = [
      if (e.amount != null && e.currencyCode != null) '${e.currencyCode} ${fmt.format(e.amount)}',
      if (e.proofReference != null) 'Ref: ${e.proofReference}',
      if (e.notes != null && e.notes!.isNotEmpty) e.notes,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FxTimelineStepCard(
        title: '${e.eventNo}. ${e.eventType.label}',
        subtitle: subtitle.isEmpty ? e.eventType.label : subtitle,
        statusLabel: e.statusAfter?.label ?? e.eventType.label,
        onTap: e.linkedTransactionId != null
            ? () => context.push('/transactions/${e.linkedTransactionId}')
            : null,
      ),
    );
  }
}

Future<void> _shareReceipt(BuildContext context, FxRemittance r, {required bool customerCopy}) async {
  final text = formatRemittanceReceipt(r, customerCopy: customerCopy);
  final pdf = await buildRemittanceReceiptPdf(r, customerCopy: customerCopy);
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
