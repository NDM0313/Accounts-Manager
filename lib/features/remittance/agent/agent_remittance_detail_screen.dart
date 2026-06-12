import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_amount_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_bottom_action_bar.dart';
import 'package:accounts_manager/core/widgets/premium/fx_help_tip_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/core/widgets/premium/fx_status_badge.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AgentRemittanceDetailScreen extends ConsumerWidget {
  const AgentRemittanceDetailScreen({super.key, required this.remittanceId});

  final String remittanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remAsync = ref.watch(agentRemittanceDetailProvider(remittanceId));
    final fmt = NumberFormat('#,##0.00');

    return FxPremiumScaffold(
      title: const Text('Agent Payout'),
      fallbackRoute: '/remittance/agent',
      body: remAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (r) {
          if (r == null) return const Center(child: Text('Not found'));
          final canConfirm =
              r.status == FxRemittanceStatus.sentToAgent ||
              r.status == FxRemittanceStatus.readyForPayout;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_isBlocked(r)) ...[
                      FxHelpTipCard(
                        title: 'Action blocked',
                        body: _blockMessage(r),
                        initiallyExpanded: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    FxAmountCard(
                      label: 'Payout amount',
                      amountLabel:
                          '${r.payoutCurrency} ${fmt.format(r.payoutAmount)}',
                      trendLabel: r.payoutCode != null
                          ? 'Code ${r.payoutCode}'
                          : r.status.label,
                    ),
                    const SizedBox(height: 12),
                    FxPremiumCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.remittanceNo ?? r.trackingId,
                                  style: AppTypography.headlineSm(
                                    context.fx.onSurface,
                                    context: context,
                                  ),
                                ),
                              ),
                              FxStatusBadge(label: r.status.label),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Receiver: ${r.receiverName}'),
                          if (r.receiverPhone != null)
                            Text('Phone: ${r.receiverPhone}'),
                          if (r.payoutCode != null)
                            Text(
                              'Verify payout code: ${r.payoutCode}',
                              style: AppTypography.bodyMd(
                                context.fx.primary,
                                context: context,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (canConfirm)
                FxBottomActionBar(
                  primaryLabel: 'Confirm Payout',
                  onPrimary: () =>
                      context.push('/remittance/agent/$remittanceId/confirm'),
                  secondaryLabel: 'Back',
                  onSecondary: () => context.pop(),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _isBlocked(FxRemittance r) =>
      r.status == FxRemittanceStatus.cancelled ||
      r.status == FxRemittanceStatus.refunded ||
      r.status == FxRemittanceStatus.paidOut ||
      r.status == FxRemittanceStatus.completed;

  String _blockMessage(FxRemittance r) => switch (r.status) {
    FxRemittanceStatus.cancelled => 'This remittance was cancelled.',
    FxRemittanceStatus.refunded => 'This remittance was refunded.',
    FxRemittanceStatus.paidOut => 'Payout already confirmed.',
    FxRemittanceStatus.completed => 'This remittance is already settled.',
    _ => 'This remittance cannot be paid out.',
  };
}
