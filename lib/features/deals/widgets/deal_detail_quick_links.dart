import 'package:accounts_manager/core/utils/deal_statement.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:accounts_manager/core/export/fx_document_export.dart';
import 'package:accounts_manager/core/export/report_pdf_builder.dart';

class DealDetailQuickLinks extends ConsumerWidget {
  const DealDetailQuickLinks({
    super.key,
    required this.deal,
    required this.legs,
    required this.dealId,
    this.onViewProofs,
  });

  final FxDeal deal;
  final List<FxDealLeg> legs;
  final String dealId;
  final VoidCallback? onViewProofs;

  String? _agentPartyId(List<FxDealLeg> meta) {
    for (final type in [FxDealLegType.agentSource, FxDealLegType.agentPayment, FxDealLegType.crossCurrencySource]) {
      try {
        final leg = meta.lastWhere((l) => l.legType == type);
        if (leg.counterpartyPartyId != null) return leg.counterpartyPartyId;
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(dealLegMetaProvider(dealId));
    final agentId = metaAsync.whenOrNull(data: (m) => _agentPartyId(m));
    final hasProofs = legs.any((l) => l.attachmentCount > 0);
    final linkedNos = legs.map((l) => l.linkedTransactionNo).whereType<String>().toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (deal.customerPartyId.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => context.push('/parties/${deal.customerPartyId}/ledger'),
            icon: const Icon(Icons.person_outline, size: 16),
            label: const Text('Customer statement'),
          ),
        if (agentId != null)
          OutlinedButton.icon(
            onPressed: () => context.push('/parties/$agentId/ledger'),
            icon: const Icon(Icons.handshake_outlined, size: 16),
            label: const Text('Agent statement'),
          ),
        OutlinedButton.icon(
          onPressed: () => _exportDeal(context),
          icon: const Icon(Icons.share_outlined, size: 16),
          label: const Text('Share deal summary'),
        ),
        if (linkedNos.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => _showJournalSheet(context, ref, linkedNos),
            icon: const Icon(Icons.menu_book_outlined, size: 16),
            label: const Text('View journal'),
          ),
        if (hasProofs && onViewProofs != null)
          OutlinedButton.icon(
            onPressed: onViewProofs,
            icon: const Icon(Icons.attach_file, size: 16),
            label: const Text('View proofs'),
          ),
      ],
    );
  }

  Future<void> _showJournalSheet(BuildContext context, WidgetRef ref, List<String> txnNos) async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null || !context.mounted) return;

    final repo = ref.read(transactionRepositoryProvider);
    final entries = <({String no, String? journalId, String? txId})>[];
    for (final no in txnNos) {
      final txId = await repo.fetchTransactionIdByNo(profile.branchId, no);
      if (txId == null) {
        entries.add((no: no, journalId: null, txId: null));
        continue;
      }
      final journal = await repo.fetchJournalForTransaction(txId);
      entries.add((no: no, journalId: journal?.id, txId: txId));
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Linked transactions & journals', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            if (entries.every((e) => e.txId == null))
              const Text('No linked transactions found.')
            else
              ...entries.map((e) {
                if (e.txId == null) {
                  return ListTile(title: Text('Tx ${e.no}'), subtitle: const Text('Not found'));
                }
                return ListTile(
                  title: Text('Tx ${e.no}'),
                  subtitle: Text(e.journalId != null ? 'Journal posted' : 'Transaction only'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (e.journalId != null) {
                      context.push('/journal/${e.journalId}');
                    } else {
                      context.push('/transactions/${e.txId}');
                    }
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _exportDeal(BuildContext context) async {
    final internalText = buildDealStatementText(deal: deal, legs: legs, internal: true);
    final customerText = buildDealStatementText(deal: deal, legs: legs, internal: false);
    final pdf = await buildDealStatementPdf(
      dealNo: deal.dealNo ?? deal.id.substring(0, 8),
      customerName: deal.customerName ?? '—',
      status: deal.status.label,
      bodyLines: internalText.split('\n'),
      internal: true,
    );
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Export deal statement'),
              subtitle: Text(deal.dealNo ?? deal.id.substring(0, 8)),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share internal summary'),
              onTap: () async {
                Navigator.pop(ctx);
                await showFxExportSheet(
                  context,
                  document: FxExportDocument(
                    title: 'Deal ${deal.dealNo}',
                    textBody: internalText,
                    pdfBytes: pdf,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Share customer copy'),
              onTap: () async {
                Navigator.pop(ctx);
                final custPdf = await buildDealStatementPdf(
                  dealNo: deal.dealNo ?? deal.id.substring(0, 8),
                  customerName: deal.customerName ?? '—',
                  status: deal.status.label,
                  bodyLines: customerText.split('\n'),
                  internal: false,
                );
                if (!context.mounted) return;
                await showFxExportSheet(
                  context,
                  mode: FxExportMode.customerFacing,
                  document: FxExportDocument(
                    title: 'Deal ${deal.dealNo}',
                    textBody: customerText,
                    pdfBytes: custPdf,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
