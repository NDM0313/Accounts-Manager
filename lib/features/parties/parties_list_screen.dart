import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
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
    final balancesAsync = ref.watch(partyDirectoryBalancesProvider);
    final currencyBalancesAsync =
        ref.watch(partyDirectoryCurrencyBalancesProvider);
    final fmt = NumberFormat('#,##0.00');

    final fallback = widget.initialFilter == FxPartyType.agent
        ? '/accounts-hub'
        : '/accounts-hub';
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
              'Current PKR balance uses control accounts (not a currency sum). '
              'Tap a row to open the party ledger. Zero = Settled.',
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Expanded(
              child: partiesAsync.when(
                loading: () => const FxLoadingState(),
                error: (e, _) => FxErrorState(message: 'Error: $e'),
                data: (parties) {
                  if (parties.isEmpty) {
                    return const FxEmptyState(message: 'No parties found.');
                  }
                  final balances = balancesAsync.asData?.value ?? const {};
                  final currencyByParty =
                      currencyBalancesAsync.asData?.value ?? const {};
                  return ListView.separated(
                    itemCount: parties.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.stackSm),
                    itemBuilder: (context, i) {
                      final p = parties[i];
                      final bal = balances[p.id];
                      final balanceLabel = bal == null
                          ? 'Balance unavailable'
                          : bal.abs() < 0.005
                              ? 'Settled'
                              : _balanceMeaning(p.partyType, bal, fmt);
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

  String _balanceMeaning(FxPartyType type, double bal, NumberFormat fmt) {
    final abs = fmt.format(bal.abs());
    return switch (type) {
      FxPartyType.customer || FxPartyType.supplier => bal > 0
          ? 'Receivable PKR $abs'
          : 'Advance/credit PKR $abs',
      FxPartyType.agent || FxPartyType.settlement => bal > 0
          ? 'Payable/custody PKR $abs'
          : 'Receivable PKR $abs',
    };
  }
}

/// Agent ledger entry point — same list filtered to agents.
class AgentLedgerScreen extends StatelessWidget {
  const AgentLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PartiesListScreen(initialFilter: FxPartyType.agent);
  }
}
