import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Full version history for a currency pair (e.g. USD/PKR).
class RateHistoryScreen extends ConsumerStatefulWidget {
  const RateHistoryScreen({super.key, required this.currencyCode});

  final String currencyCode;

  @override
  ConsumerState<RateHistoryScreen> createState() => _RateHistoryScreenState();
}

class _RateHistoryScreenState extends ConsumerState<RateHistoryScreen> {
  List<FxRate>? _history;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref.read(rateRepositoryProvider).fetchRateHistory(widget.currencyCode);
      if (mounted) setState(() => _history = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.currencyCode.toUpperCase();
    final fmt = NumberFormat('#,##0.####');
    final dtFmt = DateFormat.yMMMd().add_jm();

    return FxPageScaffold(
      fallbackRoute: '/rates',
      title: Text('$code/PKR history', style: AppTypography.headlineMd(context.fx.onSurface, context: context)),
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/rates/new?currency=$code'),
        backgroundColor: context.fx.tertiary,
        foregroundColor: context.fx.onTertiary,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : (_history == null || _history!.isEmpty)
                  ? const FxObsidianReportPanel(child: Text('No rate history for this currency.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _history!.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final h = _history![i];
                        final isLatest = i == 0;
                        return FxObsidianReportPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '$code/PKR',
                                    style: AppTypography.labelCaps(context.fx.onSurface, context: context),
                                  ),
                                  const Spacer(),
                                  if (isLatest)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: context.fx.tertiary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Latest',
                                        style: AppTypography.bodyMd(context.fx.tertiary, context: context).copyWith(fontSize: 10),
                                      ),
                                    ),
                                  if (!h.isActive)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Text(
                                        'Inactive',
                                        style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 10),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ref ${fmt.format(h.referenceRate)} · Buy ${fmt.format(h.buyRate)} · Sell ${fmt.format(h.sellRate)}',
                                style: AppTypography.bodyMd(context.fx.onSurface, context: context),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Effective from ${dtFmt.format(h.effectiveAt.toLocal())}',
                                style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11),
                              ),
                              if (h.effectiveTo != null)
                                Text(
                                  'Effective to ${dtFmt.format(h.effectiveTo!.toLocal())}',
                                  style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11),
                                )
                              else if (isLatest)
                                Text(
                                  'Effective to — (current)',
                                  style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Source: ${h.source} · Used count: —',
                                style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11),
                              ),
                              if (h.notes != null && h.notes!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(h.notes!, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11)),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => context.push('/rates/edit/${h.id}'),
                                    child: const Text('Edit (new version)'),
                                  ),
                                  TextButton(
                                    onPressed: () => context.push('/rates/new?from=${h.id}'),
                                    child: const Text('Duplicate'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
