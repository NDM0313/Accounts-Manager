import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
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

    return FxPageScaffold(
      title: const Text('Agent Payout'),
      fallbackRoute: '/remittance/agent',
      body: remAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (r) {
          if (r == null) return const Center(child: Text('Not found'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_isBlocked(r)) _warning(context, _blockMessage(r)),
              Text(
                'RM ${r.remittanceNo ?? r.trackingId}',
                style: AppTypography.headlineSm(
                  context.fx.onSurface,
                  context: context,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Receiver: ${r.receiverName}',
                style: AppTypography.bodyMd(
                  context.fx.onSurface,
                  context: context,
                ),
              ),
              if (r.receiverPhone != null) Text('Phone: ${r.receiverPhone}'),
              Text('Payout: ${r.payoutCurrency} ${fmt.format(r.payoutAmount)}'),
              Text('Status: ${r.status.label}'),
              if (r.payoutCode != null)
                Text(
                  'Payout code: ${r.payoutCode}',
                  style: AppTypography.bodyMd(
                    context.fx.primary,
                    context: context,
                  ),
                ),
              const SizedBox(height: 16),
              if (r.status == FxRemittanceStatus.sentToAgent ||
                  r.status == FxRemittanceStatus.readyForPayout)
                FilledButton(
                  onPressed: () =>
                      context.push('/remittance/agent/$remittanceId/confirm'),
                  child: const Text('Confirm Payout'),
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

  Widget _warning(BuildContext context, String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.fx.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: context.fx.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMd(
                context.fx.onSurface,
                context: context,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
