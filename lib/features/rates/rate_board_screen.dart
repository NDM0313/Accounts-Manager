import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/utils/rate_source_labels.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/core/widgets/rates/fx_rate_pair_card.dart';
import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/domain/services/rate_suggestion_service.dart';
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
    final pairsAsync = ref.watch(rateBoardPairsProvider);
    final fmt = NumberFormat('#,##0.####');

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: const Text('Rate Board'),
        backgroundColor: context.fx.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(ratesProvider);
              ref.invalidate(rateBoardPairsProvider);
            },
          ),
        ],
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
            'Latest PKR reference rates for your branch. Cross pairs are derived automatically.',
            style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurfaceVariant, context: context),
          ),
          const SizedBox(height: 16),
          pairsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const FxObsidianReportPanel(
              child: Text('Unable to load rates. Ensure your profile is configured.'),
            ),
            data: (pairs) {
              if (pairs.isEmpty) return const FxObsidianReportPanel(child: Text('No rates available yet.'));
              final derived = pairs.where((p) => p.isDerived).toList();
              final pkrPairs = pairs.where((p) => !p.isDerived).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pkrPairs.isNotEmpty) ...[
                    Text('PKR pairs', style: AppTypography.labelCaps(context.fx.outline, context: context)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: pkrPairs.map((p) => FxRatePairCard(pair: p, showActions: true)).toList(),
                    ),
                  ],
                  if (derived.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Derived cross rates', style: AppTypography.labelCaps(context.fx.outline, context: context)),
                    const SizedBox(height: 4),
                    Text(
                      'Calculated from PKR rates — reference only',
                      style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: derived.map((p) => FxRatePairCard(pair: p, showActions: true)).toList(),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Currency rates', style: AppTypography.labelCaps(context.fx.outline, context: context)),
          const SizedBox(height: 8),
          ratesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FxObsidianReportPanel(child: Text('Error: $e')),
            data: (rates) {
              if (rates.isEmpty) {
                return const FxObsidianReportPanel(child: Text('No rates available yet.'));
              }
              return Column(
                children: rates.map((r) => _CurrencyRateTile(rate: r, fmt: fmt)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CurrencyRateTile extends ConsumerStatefulWidget {
  const _CurrencyRateTile({required this.rate, required this.fmt});

  final FxRate rate;
  final NumberFormat fmt;

  @override
  ConsumerState<_CurrencyRateTile> createState() => _CurrencyRateTileState();
}

class _CurrencyRateTileState extends ConsumerState<_CurrencyRateTile> {
  bool _expanded = false;
  List<FxRate>? _history;
  bool _loadingHistory = false;

  Future<void> _loadHistory() async {
    if (_history != null || _loadingHistory) return;
    setState(() => _loadingHistory = true);
    try {
      final rows = await ref.read(rateRepositoryProvider).fetchRateHistory(widget.rate.currencyCode);
      if (mounted) setState(() => _history = rows);
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  bool get _isStale {
    return DateTime.now().difference(widget.rate.effectiveAt.toLocal()) > RateSuggestionService.staleThreshold;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rate;
    final fmt = widget.fmt;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: _isStale ? Colors.orange.withValues(alpha: 0.4) : context.fx.outlineVariant),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(r.currencyCode, style: AppTypography.headlineMd(context.fx.onSurface, context: context).copyWith(fontSize: 18)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ref ${fmt.format(r.referenceRate)} · Buy ${fmt.format(r.buyRate)} · Sell ${fmt.format(r.sellRate)}'),
                Text(
                  '${RateSourceLabels.label(r.source)} · ${DateFormat.yMMMd().add_jm().format(r.effectiveAt.toLocal())}',
                  style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11),
                ),
                if (_isStale)
                  Text('Rate may be outdated', style: AppTypography.bodyMd(Colors.orange.shade700, context: context).copyWith(fontSize: 11)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: context.fx.onSurfaceVariant),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit rate')),
                    const PopupMenuItem(value: 'history', child: Text('View history')),
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    const PopupMenuItem(value: 'buy', child: Text('New buy')),
                    const PopupMenuItem(value: 'sell', child: Text('New sell')),
                    PopupMenuItem(
                      enabled: FeatureFlags.rateDeactivateEnabled,
                      value: 'deactivate',
                      child: Tooltip(
                        message: FeatureFlags.rateDeactivateEnabled ? '' : 'Rate deactivate unavailable',
                        child: const Text('Deactivate'),
                      ),
                    ),
                  ],
                  onSelected: (action) {
                    switch (action) {
                      case 'edit':
                        context.push('/rates/edit/${r.id}');
                      case 'history':
                        context.push('/rates/history/${r.currencyCode}');
                      case 'duplicate':
                        context.push('/rates/new?from=${r.id}');
                      case 'deactivate':
                        break;
                      case 'buy':
                      case 'sell':
                        final type = action == 'buy' ? 'currency_buy' : 'currency_sell';
                        final rate = action == 'buy' ? r.buyRate : r.sellRate;
                        context.push('/transactions/new?type=$type&currency=${r.currencyCode}&rate=$rate');
                    }
                  },
                ),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() => _expanded = !_expanded);
                    if (_expanded) _loadHistory();
                  },
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _loadingHistory
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : (_history == null || _history!.isEmpty)
                      ? Text('No history', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context))
                      : Column(
                          children: _history!.map((h) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      DateFormat.yMMMd().add_jm().format(h.effectiveAt.toLocal()),
                                      style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11),
                                    ),
                                  ),
                                  Text('B ${fmt.format(h.buyRate)}', style: AppTypography.labelMono(context.fx.tertiary, context: context).copyWith(fontSize: 11)),
                                  const SizedBox(width: 8),
                                  Text('S ${fmt.format(h.sellRate)}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
            ),
          ],
        ],
      ),
    );
  }
}
