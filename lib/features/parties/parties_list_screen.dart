import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/party_directory_measure.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/parties/widgets/party_directory_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PartiesListScreen extends ConsumerStatefulWidget {
  const PartiesListScreen({super.key, this.initialFilter});

  final FxPartyType? initialFilter;

  @override
  ConsumerState<PartiesListScreen> createState() => _PartiesListScreenState();
}

class _PartiesListScreenState extends ConsumerState<PartiesListScreen> {
  FxPartyType? _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final partiesAsync = ref.watch(partiesProvider(_filter));
    final measuresAsync = ref.watch(partyDirectoryMeasuresProvider);
    final currencyBalancesAsync = ref.watch(
      partyDirectoryCurrencyBalancesProvider,
    );
    final fmt = NumberFormat('#,##0.##');

    final fallback = '/accounts-hub';
    final pageTitle = widget.initialFilter == FxPartyType.agent
        ? 'Agents'
        : 'Party directory';

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: FxPageHeader.appBar(
        context: context,
        fallbackRoute: fallback,
        title: Text(pageTitle),
      ),
      floatingActionButton: widget.initialFilter == FxPartyType.agent
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/parties/new'),
              child: const Icon(Icons.add),
            ),
      body: FxContentContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FxFilterToolbar(
              filters: [
                FxFilterChipButton(
                  label: 'All',
                  selected: _filter == null,
                  onPressed: () => setState(() => _filter = null),
                ),
                for (final t in FxPartyType.values)
                  FxFilterChipButton(
                    label: t.label,
                    selected: _filter == t,
                    onPressed: () => setState(() => _filter = t),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Text(
              'Customers: unpaid deals, posted 1190, unapplied 1160 and '
              'control net are different measures — control is not deal due '
              'or cash. Agents: advance 1180 / payable 2100. FX custody is '
              'under the expand arrow — do not sum currencies.',
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (measuresAsync.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
                child: FxErrorState(
                  message:
                      'Balances could not be loaded. Tap retry to refresh them.',
                  onRetry: () =>
                      ref.invalidate(partyDirectoryMeasuresProvider),
                ),
              ),
            Expanded(
              child: partiesAsync.when(
                loading: () => const FxLoadingState(),
                error: (e, _) => FxErrorState(
                  message: 'Error: $e',
                  onRetry: () => ref.invalidate(partiesProvider(_filter)),
                ),
                data: (parties) {
                  if (parties.isEmpty) {
                    return const FxEmptyState(message: 'No parties found.');
                  }
                  final measuresLoading = measuresAsync.isLoading;
                  final measures = measuresAsync.asData?.value;
                  final currencyByParty =
                      currencyBalancesAsync.asData?.value ?? const {};
                  return ListView.separated(
                    itemCount: parties.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.stackSm),
                    itemBuilder: (context, i) {
                      final p = parties[i];
                      final String balanceLabel;
                      if (measuresLoading && measures == null) {
                        balanceLabel = 'Loading balance…';
                      } else if (measuresAsync.hasError) {
                        balanceLabel = 'Balance unavailable — retry';
                      } else if (measures == null ||
                          !measures.containsKey(p.id)) {
                        balanceLabel = 'Balance unavailable — retry';
                      } else {
                        balanceLabel = _formatMeasures(
                          p.partyType,
                          measures[p.id]!,
                          fmt,
                        );
                      }
                      return PartyDirectoryListTile(
                        party: p,
                        pkrBalanceLabel: balanceLabel,
                        currencyBalances: currencyByParty[p.id] ?? const [],
                        fmt: fmt,
                        onOpenLedger: () =>
                            context.push('/parties/${p.id}/ledger'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMeasures(
    FxPartyType type,
    PartyDirectoryMeasure m,
    NumberFormat fmt,
  ) {
    final lines = <String>[];
    if (type == FxPartyType.customer || type == FxPartyType.supplier) {
      if (m.openDealReceivablePkr.abs() >= 0.005) {
        lines.add('Unpaid deals PKR ${fmt.format(m.openDealReceivablePkr)}');
      }
      if (m.postedReceivable1190Pkr.abs() >= 0.005) {
        lines.add(
          'Posted receivable 1190 PKR ${fmt.format(m.postedReceivable1190Pkr)}',
        );
      }
      if (m.unappliedAdvance1160Pkr.abs() >= 0.005) {
        lines.add(
          'Unapplied advance 1160 PKR ${fmt.format(m.unappliedAdvance1160Pkr)}',
        );
      }
      if (m.controlNetPkr.abs() >= 0.005) {
        lines.add(
          'Control net (not deal due, not cash) PKR ${fmt.format(m.controlNetPkr)}',
        );
      } else if (lines.isEmpty) {
        lines.add('Settled');
      }
    } else {
      if (m.agentAdvancePkr >= 0.005) {
        lines.add('Advance 1180 PKR ${fmt.format(m.agentAdvancePkr)}');
      }
      if (m.agentPayablePkr >= 0.005) {
        lines.add('Payable 2100 PKR ${fmt.format(m.agentPayablePkr)}');
      }
      if (lines.isEmpty) {
        if (m.controlNetPkr.abs() < 0.005) {
          lines.add('Settled');
        } else {
          lines.add(
            m.controlNetPkr > 0
                ? 'Control net payable PKR ${fmt.format(m.controlNetPkr)}'
                : 'Control net receivable PKR ${fmt.format(m.controlNetPkr.abs())}',
          );
        }
      }
    }
    return lines.join('\n');
  }
}
