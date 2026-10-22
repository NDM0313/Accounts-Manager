import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
import 'package:accounts_manager/domain/models/agent_custody.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:accounts_manager/domain/services/agent_custody_labels.dart';
import 'package:accounts_manager/domain/services/party_statement_narrative.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Agent ledger — shared design-system ledger (custody noted separately from payable).
class AgentLedgerStitchView extends ConsumerWidget {
  const AgentLedgerStitchView({
    super.key,
    required this.partyId,
    required this.party,
    required this.statementAsync,
    required this.fmt,
  });

  final String partyId;
  final FxParty party;
  final AsyncValue<PartyStatementView?> statementAsync;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custodyAsync = ref.watch(agentCustodyProvider(partyId));
    final openDealsAsync = FeatureFlags.dealsWorkflowEnabled
        ? ref.watch(partyDealOpenItemsProvider(partyId))
        : const AsyncValue<List<PartyDealOpenItem>>.data([]);
    final view = statementAsync.whenOrNull(data: (v) => v);
    final summary = view?.summary;
    final closing = summary?.netBalancePkr ?? 0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.fxHorizontalInset,
        AppSpacing.stackSm,
        context.fxHorizontalInset,
        AppSpacing.shellBottomInset,
      ),
      children: [
        FxStitchCard(
          padding: const EdgeInsets.all(AppSpacing.stackMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FxPageTitleBlock(
                title: party.name,
                subtitle: [
                  if (party.code.trim().isNotEmpty) party.code,
                  'Agent',
                ].join(' · '),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              Text(
                'Ledger balance (PKR statement)',
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 12),
              ),
              const SizedBox(height: 4),
              if (closing.abs() < 0.005)
                Text(
                  'Settled / No outstanding',
                  style: AppTypography.headlineSm(
                    AppColors.lightSuccess,
                    context: context,
                  ),
                )
              else ...[
                FxMoneyLabel(
                  amount: closing.abs(),
                  bold: true,
                  fontSize: 22,
                  align: TextAlign.start,
                ),
                const SizedBox(height: 2),
                Text(
                  PartyStatementNarrative.balanceExplanation(
                    partyType: FxPartyType.agent,
                    closingPkr: closing,
                  ),
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.stackMd),
        _AgentCustodySection(custodyAsync: custodyAsync),
        if (view != null && summary != null) ...[
          const SizedBox(height: AppSpacing.stackMd),
          FxLedgerSummaryStrip(
            opening: view.openingBalancePkr,
            periodDebits: summary.totalDebitPkr,
            periodCredits: summary.totalCreditPkr,
            closing: view.closingBalancePkr,
            periodLabel: 'Selected period',
          ),
        ],
        openDealsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.stackMd),
              child: FxStitchCard(
                padding: const EdgeInsets.all(AppSpacing.stackMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open deal legs',
                      style: AppTypography.headlineSm(
                        context.fx.onSurface,
                        context: context,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final item in items.take(5))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.dealNo ?? item.dealId.substring(0, 8)),
                        subtitle: Text(item.dealStatus.label),
                        onTap: () => context.push('/deals/${item.dealId}'),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.stackMd),
        Text(
          'Activity',
          style: AppTypography.headlineSm(
            context.fx.onSurface,
            context: context,
          ),
        ),
        const SizedBox(height: AppSpacing.stackSm),
        statementAsync.when(
          loading: () => const FxLoadingState(),
          error: (e, _) => FxErrorState(message: 'Error: $e'),
          data: (view) {
            if (view == null) {
              return const FxEmptyState(message: 'Unable to load statement.');
            }
            return FxResponsiveLedgerView(
              lines: view.lines,
              newestFirst: true,
              rangeTo: view.to,
              onOpenTransaction: (line) =>
                  context.push('/transactions/${line.transactionId}'),
            );
          },
        ),
      ],
    );
  }
}

class _AgentCustodySection extends StatelessWidget {
  const _AgentCustodySection({required this.custodyAsync});

  final AsyncValue<List<AgentCustodyRow>> custodyAsync;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AgentCustodyLabels.custodySectionTitle(),
            style: AppTypography.headlineSm(
              context.fx.onSurface,
              context: context,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AgentCustodyLabels.custodyNotPhysicalCash,
            style: AppTypography.bodyMd(
              context.fx.onSurfaceVariant,
              context: context,
            ).copyWith(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          custodyAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => Text(
              AgentCustodyLabels.emptyCustodyInventory,
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 12),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return Text(
                  AgentCustodyLabels.emptyCustodyInventory,
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ).copyWith(fontSize: 12),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final row in rows) ...[
                    if (row != rows.first) const Divider(height: 20),
                    Text(
                      row.currencyCode,
                      style: AppTypography.bodyMd(
                        context.fx.onSurface,
                        context: context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    _custodyLine(
                      context,
                      AgentCustodyLabels.custodyMetricLabel('Owned'),
                      row.owned,
                      row.currencyCode,
                    ),
                    _custodyLine(
                      context,
                      AgentCustodyLabels.custodyMetricLabel('Reserved'),
                      row.reserved,
                      row.currencyCode,
                    ),
                    _custodyLine(
                      context,
                      AgentCustodyLabels.custodyMetricLabel('Available'),
                      row.available,
                      row.currencyCode,
                    ),
                    if (row.payablePkr.abs() >= 0.005) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              AgentCustodyLabels.payablePkrCreditLabel(),
                              style: AppTypography.bodyMd(
                                context.fx.onSurfaceVariant,
                                context: context,
                              ).copyWith(fontSize: 12),
                            ),
                          ),
                          FxMoneyLabel(
                            amount: row.payablePkr.abs(),
                            currencyCode: 'PKR',
                            fontSize: 13,
                          ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.stackSm),
                  Text(
                    AgentCustodyLabels.pkrLedgerVsCustodyNote,
                    style: AppTypography.bodyMd(
                      context.fx.onSurfaceVariant,
                      context: context,
                    ).copyWith(fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _custodyLine(
    BuildContext context,
    String label,
    double amount,
    String currencyCode,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
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
          FxMoneyLabel(
            amount: amount,
            currencyCode: currencyCode,
            fontSize: 13,
          ),
        ],
      ),
    );
  }
}
