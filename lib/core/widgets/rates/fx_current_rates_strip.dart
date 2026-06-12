import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/rates/fx_rate_pair_card.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Horizontal "Current Rates" strip for dashboard.
class FxCurrentRatesStrip extends ConsumerWidget {
  const FxCurrentRatesStrip({super.key, this.showTicker = true});

  final bool showTicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairsAsync = ref.watch(rateBoardPairsProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return pairsAsync.when(
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (pairs) {
        if (pairs.isEmpty) {
          return _emptyStrip(context, ref);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Current Rates',
                  style: AppTypography.headlineMd(
                    context.fx.onSurface,
                    context: context,
                  ).copyWith(fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    size: 20,
                    color: context.fx.onSurfaceVariant,
                  ),
                  tooltip: 'Refresh rates',
                  onPressed: () {
                    ref.invalidate(ratesProvider);
                    ref.invalidate(rateBoardPairsProvider);
                  },
                ),
                TextButton(
                  onPressed: () => context.push('/rates'),
                  child: const Text('Manage Rates'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isWide)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pairs
                    .map(
                      (p) => FxRatePairCard(
                        pair: p,
                        onTap: () => context.push('/rates'),
                      ),
                    )
                    .toList(),
              )
            else
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: pairs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => FxRatePairCard(
                    pair: pairs[i],
                    compact: true,
                    onTap: () => context.push('/rates'),
                  ),
                ),
              ),
            if (showTicker && pairs.isNotEmpty) ...[
              const SizedBox(height: 8),
              _RatesTicker(pairs: pairs),
            ],
          ],
        );
      },
    );
  }

  Widget _emptyStrip(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Current Rates',
              style: AppTypography.headlineMd(
                context.fx.onSurface,
                context: context,
              ).copyWith(fontSize: 16),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/rates'),
              child: const Text('Manage Rates'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'No reference rates yet — add rates in Rate Board.',
          style: AppTypography.bodyMd(
            context.fx.onSurfaceVariant,
            context: context,
          ).copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

class _RatesTicker extends StatelessWidget {
  const _RatesTicker({required this.pairs});

  final List<RateBoardPair> pairs;

  @override
  Widget build(BuildContext context) {
    final text = pairs
        .take(6)
        .map((p) => '${p.pairLabel} ${p.referenceRate.toStringAsFixed(2)}')
        .join('  ·  ');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(
        text,
        style: AppTypography.bodyMd(
          context.fx.onSurfaceVariant,
          context: context,
        ).copyWith(fontSize: 11),
      ),
    );
  }
}
