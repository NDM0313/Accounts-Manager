import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DealsListScreen extends ConsumerWidget {
  const DealsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.dealsWorkflowEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('FX Deals')),
        body: const Center(child: Text('FX Deals workflow is disabled.')),
      );
    }

    final dealsAsync = ref.watch(dealsListProvider);
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: const Text('FX Deals'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/deals/new'),
        icon: const Icon(Icons.add),
        label: const Text('Customer Order'),
      ),
      body: dealsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load deals: $e')),
        data: (deals) {
          if (deals.isEmpty) {
            return Center(
              child: Text(
                'No FX deals yet.\nBook a customer order first, source later.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: deals.length,
            itemBuilder: (context, i) => _DealCard(deal: deals[i], fmt: fmt),
          );
        },
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.deal, required this.fmt});

  final FxDeal deal;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FxObsidianReportPanel(
        padding: const EdgeInsets.all(12),
        child: InkWell(
          onTap: () => context.push('/deals/${deal.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deal.dealNo ?? deal.id.substring(0, 8),
                      style: AppTypography.headlineMd(
                        context.fx.onSurface,
                        context: context,
                      ).copyWith(fontSize: 16),
                    ),
                  ),
                  _StatusChip(status: deal.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${deal.customerName ?? 'Customer'} · ${fmt.format(deal.sellAmount)} ${deal.sellCurrencyCode} @ ${fmt.format(deal.saleRatePkr)}',
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 12),
              ),
              Text(
                'PKR ${fmt.format(deal.customerPayablePkr)} · Recv ${fmt.format(deal.customerReceivablePkr)}',
                style: AppTypography.bodyMd(
                  context.fx.onSurface,
                  context: context,
                ).copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final FxDealStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      FxDealStatus.completed => context.fx.tertiary,
      FxDealStatus.sourcingRequired ||
      FxDealStatus.sourcingInProgress => context.fx.warning,
      FxDealStatus.cancelled || FxDealStatus.voided => context.fx.error,
      _ => context.fx.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: AppTypography.labelCaps(
          color,
          context: context,
        ).copyWith(fontSize: 9),
      ),
    );
  }
}
