import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_ledger_table.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_shell.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PartyLedgerScreen extends ConsumerWidget {
  const PartyLedgerScreen({super.key, required this.partyId});

  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partyAsync = ref.watch(partyDetailProvider(partyId));
    final txAsync = ref.watch(partyTransactionsProvider(partyId));
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: partyAsync.when(
          data: (p) => Text(p?.name ?? 'Party Ledger'),
          loading: () => const Text('Party Ledger'),
          error: (_, __) => const Text('Party Ledger'),
        ),
        backgroundColor: context.fx.background,
      ),
      floatingActionButton: partyAsync.whenOrNull(
        data: (party) => party == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'party_settlement_receive',
                    onPressed: () => context.push(
                      '/transactions/new?type=${FxTransactionType.settlementReceive.dbValue}&partyId=$partyId',
                    ),
                    icon: const Icon(Icons.call_received),
                    label: const Text('Receive'),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    heroTag: 'party_settlement_send',
                    onPressed: () => context.push(
                      '/transactions/new?type=${FxTransactionType.settlementSend.dbValue}&partyId=$partyId',
                    ),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Send'),
                  ),
                ],
              ),
      ),
      body: FxObsidianPage(
        child: partyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (party) {
            if (party == null) return const Center(child: Text('Party not found.'));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.fx.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: context.fx.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FxSectionLabel(label: party.partyType.label),
                      Text(party.name, style: AppTypography.headlineMd(context.fx.onSurface, context: context)),
                      if (party.phone != null)
                        Text(party.phone!, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: txAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (txs) {
                      if (txs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'No settlement transactions linked to this party.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create Settlement Send or Receive and select this party on the draft form.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                                ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: () => context.push(
                                    '/transactions/new?type=${FxTransactionType.settlementSend.dbValue}&partyId=$partyId',
                                  ),
                                  icon: const Icon(Icons.send_outlined),
                                  label: const Text('Settlement Send'),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => context.push(
                                    '/transactions/new?type=${FxTransactionType.settlementReceive.dbValue}&partyId=$partyId',
                                  ),
                                  icon: const Icon(Icons.call_received),
                                  label: const Text('Settlement Receive'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: txs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final tx = txs[i];
                          return Material(
                            color: context.fx.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              onTap: () => context.push('/transactions/${tx.id}'),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    FxTypeBadge(type: tx.transactionType, compact: true),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.transactionNo ?? tx.id.substring(0, 8),
                                            style: AppTypography.bodyMd(context.fx.onSurface, context: context),
                                          ),
                                          Text(
                                            DateFormat('d MMM yyyy').format(tx.transactionDate),
                                            style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${fmt.format(tx.totalForeignAmount)} ${tx.currencyCode}',
                                      style: AppTypography.labelMono(context.fx.onSurface, context: context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
