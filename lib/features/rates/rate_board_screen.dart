import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/utils/rate_source_labels.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_rate_card.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RateBoardScreen extends ConsumerWidget {
  const RateBoardScreen({super.key});

  static String _currencyName(String code) => switch (code) {
        'USD' => 'US Dollar',
        'AED' => 'UAE Dirham',
        'CNY' => 'Chinese Yuan',
        'SAR' => 'Saudi Riyal',
        'EUR' => 'Euro',
        'GBP' => 'British Pound',
        'PKR' => 'Pakistani Rupee',
        _ => code,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesAsync = ref.watch(ratesProvider);
    final pairsAsync = ref.watch(rateBoardPairsProvider);
    final fmt = NumberFormat('#,##0.####');

    void refresh() {
      ref.invalidate(ratesProvider);
      ref.invalidate(rateBoardPairsProvider);
    }

    final lastUpdated = ratesAsync.whenOrNull(
      data: (rates) {
        if (rates.isEmpty) return null;
        return rates
            .map((r) => r.effectiveAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      },
    );

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: Text(
          'Live Rates',
          style: AppTypography.headlineSm(
            context.fx.primary,
            context: context,
          ),
        ),
        backgroundColor: context.fx.surface,
        foregroundColor: context.fx.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refresh,
          ),
        ],
      ),
      body: FxStitchScaffold(
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width >= 900
              ? AppSpacing.marginDesktop
              : AppSpacing.marginMobile,
          16,
          MediaQuery.sizeOf(context).width >= 900
              ? AppSpacing.marginDesktop
              : AppSpacing.marginMobile,
          88,
        ),
        child: pairsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const FxStitchCard(
            child: Text(
              'Unable to load rates. Ensure your profile is configured.',
            ),
          ),
          data: (pairs) {
            if (pairs.isEmpty) {
              return const FxStitchCard(child: Text('No rates available yet.'));
            }
            final derived = pairs.where((p) => p.isDerived).toList();
            final pkrPairs = pairs.where((p) => !p.isDerived).toList();
            final sourceLabel = ratesAsync.whenOrNull(
                  data: (rates) => rates.isNotEmpty
                      ? RateSourceLabels.label(rates.first.source)
                      : 'Manual Reference',
                ) ??
                'Manual Reference';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FxStitchRateBoardHeader(
                  lastUpdated: lastUpdated,
                  sourceLabel: sourceLabel,
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, c) {
                    final cols = c.maxWidth >= 900
                        ? 3
                        : c.maxWidth >= 600
                            ? 2
                            : 1;
                    final gap = 12.0;
                    final w = (c.maxWidth - (cols - 1) * gap) / cols;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: pkrPairs.map((p) {
                        return SizedBox(
                          width: cols == 1 ? c.maxWidth : w,
                          child: _pairCard(context, p, fmt),
                        );
                      }).toList(),
                    );
                  },
                ),
                if (derived.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    'DERIVED CROSS PAIRS',
                    style: AppTypography.labelCaps(
                      context.fx.onSurfaceVariant,
                      context: context,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Calculated from PKR reference rates',
                    style: AppTypography.bodySm(
                      context.fx.onSurfaceVariant,
                      context: context,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: derived
                        .map(
                          (p) => SizedBox(
                            width: 160,
                            child: FxStitchDerivedRateChip(
                              pairLabel: p.pairLabel,
                              rateLabel: fmt.format(p.referenceRate),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pairCard(
    BuildContext context,
    RateBoardPair p,
    NumberFormat fmt,
  ) {
    final buy = p.buyRate ?? p.referenceRate;
    final sell = p.sellRate ?? p.referenceRate;
    return FxStitchRateCard(
      pairLabel: p.pairLabel,
      subtitle: _currencyName(p.fromCurrency),
      buyRate: fmt.format(buy),
      sellRate: fmt.format(sell),
      isStale: p.isStale,
      onEdit: p.rateId != null
          ? () => context.push('/rates/edit/${p.rateId}')
          : () => context.push('/rates/new'),
    );
  }
}
