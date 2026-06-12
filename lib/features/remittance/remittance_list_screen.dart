import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/core/widgets/premium/fx_status_badge.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RemittanceListScreen extends ConsumerWidget {
  const RemittanceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.remittanceWorkflowEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Remittance')),
        body: const Center(child: Text('Remittance module is disabled.')),
      );
    }

    final listAsync = ref.watch(remittancesListProvider);
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: const Text('Remittance'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final unread = ref.watch(unreadNotificationsCountProvider);
              final count = unread.value ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => context.push('/notifications'),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.support_agent_outlined),
            tooltip: 'Agent workspace',
            onPressed: () => context.push('/remittance/agent'),
          ),
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () => context.push('/remittance/reports'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/remittance/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load remittances.\nApply migration 202606230001 if tables are missing.\n\n$e',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No remittance orders yet.\nTrack hawala / payout orders separately from FX deals.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) => _RemittanceCard(r: items[i], fmt: fmt),
          );
        },
      ),
    );
  }
}

class _RemittanceCard extends StatelessWidget {
  const _RemittanceCard({required this.r, required this.fmt});

  final FxRemittance r;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FxObsidianReportPanel(
        padding: const EdgeInsets.all(12),
        child: InkWell(
          onTap: () => context.push('/remittance/${r.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.trackingId,
                      style: AppTypography.headlineSm(context.fx.onSurface, context: context).copyWith(fontSize: 14),
                    ),
                  ),
                  FxStatusBadge(label: r.status.label, tone: FxStatusBadge.fromString(r.status.dbValue)),
                ],
              ),
              const SizedBox(height: 4),
              Text('To: ${r.receiverName}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
              Text(
                '${r.receiveCurrency} ${fmt.format(r.receiveAmount)} → ${r.payoutCurrency} ${fmt.format(r.payoutAmount)}',
                style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
