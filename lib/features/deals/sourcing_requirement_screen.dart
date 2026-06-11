import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Screen 2 — view / extend sourcing requirement for a deal.
class SourcingRequirementScreen extends ConsumerWidget {
  const SourcingRequirementScreen({super.key, required this.dealId});

  final String dealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealAsync = ref.watch(dealDetailProvider(dealId));
    final timelineAsync = ref.watch(dealTimelineProvider(dealId));
    final fmt = NumberFormat('#,##0.00');

    return FxPageScaffold(
      fallbackRoute: '/deals/$dealId',
      title: const Text('Sourcing Requirement'),
      body: dealAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (deal) {
          if (deal == null) return const Center(child: Text('Deal not found'));
          final sourcingLeg = timelineAsync.whenOrNull(
            data: (legs) => legs.where((l) => l.legType == FxDealLegType.sourcingRequirement).firstOrNull,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FxObsidianReportPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Deal ${deal.dealNo ?? deal.id.substring(0, 8)}', style: AppTypography.headlineMd(context.fx.onSurface, context: context)),
                    Text('Status: ${deal.status.label}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const FxSectionLabel(label:'Requirement'),
              FxObsidianReportPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Required currency: ${displayCurrencyCode(deal.sellCurrencyCode)}'),
                    Text('Required amount: ${fmt.format(sourcingLeg?.receiveAmount ?? deal.sellAmount)}'),
                    Text('Source method: ${deal.deliveryMethod.label}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const FxSectionLabel(label:'Next steps'),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Add agent source leg'),
                subtitle: const Text('Agent provides currency, may want different pay currency'),
                onTap: () => context.push('/deals/$dealId/legs/agent-source'),
              ),
              ListTile(
                leading: const Icon(Icons.currency_exchange),
                title: const Text('Cross-currency sourcing'),
                subtitle: const Text('Pay PKR to third party who settles AED to agent'),
                onTap: () => context.push('/deals/$dealId/legs/cross-source'),
              ),
              const SizedBox(height: 24),
              FxObsidianActionBar(
                onCancel: () => fxSafePop(context, fallbackRoute: '/deals/$dealId'),
                onSave: () => context.go('/deals/$dealId'),
                saveLabel: 'Back to deal',
                cancelLabel: 'Close',
              ),
            ],
          );
        },
      ),
    );
  }
}

extension _LegFirstOrNull on Iterable<FxDealLeg> {
  FxDealLeg? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
