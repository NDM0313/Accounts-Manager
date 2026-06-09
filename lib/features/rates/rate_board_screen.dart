import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RateBoardScreen extends ConsumerWidget {
  const RateBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesAsync = ref.watch(ratesProvider);
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: const Text('Rate Board'),
        backgroundColor: context.fx.background,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/rates/new'),
        backgroundColor: context.fx.tertiary,
        foregroundColor: context.fx.onTertiary,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Rate Board', style: AppTypography.headlineLg(Theme.of(context).colorScheme.onSurface, context: context)),
          const SizedBox(height: 8),
          Text(
            'Latest rates for your branch. Tap + to add a new rate.',
            style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurfaceVariant, context: context),
          ),
          const SizedBox(height: 16),
          ratesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const FxObsidianReportPanel(
              child: Text('Unable to load rates. Ensure your profile is configured and RLS allows branch access.'),
            ),
            data: (rates) {
              if (rates.isEmpty) {
                return const FxObsidianReportPanel(child: Text('No rates available yet.'));
              }
              return Column(
                children: rates.map((r) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.fx.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: context.fx.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.currencyCode, style: AppTypography.headlineMd(context.fx.onSurface, context: context).copyWith(fontSize: 18)),
                              Text(
                                'Updated ${DateFormat.yMMMd().add_jm().format(r.effectiveAt.toLocal())}',
                                style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Buy ${fmt.format(r.buyRate)}', style: AppTypography.labelMono(context.fx.tertiary, context: context)),
                            Text('Sell ${fmt.format(r.sellRate)}', style: AppTypography.labelMono(context.fx.onSurfaceVariant, context: context)),
                          ],
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: context.fx.onSurfaceVariant),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'buy', child: Text('New buy')),
                            const PopupMenuItem(value: 'sell', child: Text('New sell')),
                          ],
                          onSelected: (action) {
                            final type = action == 'buy' ? 'currency_buy' : 'currency_sell';
                            final rate = action == 'buy' ? r.buyRate : r.sellRate;
                            context.push('/transactions/new?type=$type&currency=${r.currencyCode}&rate=$rate');
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
