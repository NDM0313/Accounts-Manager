import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_exposure_chip_row.dart';
import 'package:accounts_manager/core/widgets/premium/fx_party_hero_card.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_balance_grid.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_statement_list_container.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_statement_row.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Stitch customer_statement exact section layout.
class CustomerLedgerStitchView extends ConsumerStatefulWidget {
  const CustomerLedgerStitchView({
    super.key,
    required this.partyId,
    required this.party,
    required this.statementAsync,
    required this.fmt,
    required this.onExport,
  });

  final String partyId;
  final FxParty party;
  final AsyncValue<PartyStatementView?> statementAsync;
  final NumberFormat fmt;
  final VoidCallback onExport;

  @override
  ConsumerState<CustomerLedgerStitchView> createState() =>
      _CustomerLedgerStitchViewState();
}

class _CustomerLedgerStitchViewState
    extends ConsumerState<CustomerLedgerStitchView> {
  bool _filtersExpanded = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.statementAsync.whenOrNull(data: (v) => v);
    final summary = view?.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        FxPartyHeroCard(
          name: widget.party.name,
          mode: PartyHeroMode.customer,
          badgeLabel: 'PREMIUM CLIENT',
          balanceLabel: 'Net Balance',
          balanceValue: summary != null
              ? 'PKR ${widget.fmt.format(summary.netBalancePkr.abs())}'
              : '—',
          balanceSuffix: summary != null && summary.netBalancePkr >= 0
              ? 'Receivable'
              : 'Payable',
        ),
        if (summary != null && summary.balancesByCurrency.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'EXPOSURE PORTFOLIO',
            style: AppTypography.labelCaps(
              context.fx.onSurfaceVariant,
              context: context,
            ),
          ),
          const SizedBox(height: 8),
          FxExposureChipRow(
            items: summary.balancesByCurrency.entries
                .map(
                  (e) => FxExposureItem(
                    currencyCode: e.key,
                    amountLabel: widget.fmt.format(e.value),
                  ),
                )
                .toList(),
          ),
        ],
        if (summary != null && view != null) ...[
          const SizedBox(height: 16),
          FxStitchBalanceGrid(
            cells: [
              FxStitchBalanceCell(
                label: 'Opening Balance',
                value: 'PKR ${widget.fmt.format(view.openingBalancePkr)}',
              ),
              FxStitchBalanceCell(
                label: 'Total Debit',
                value: 'PKR ${widget.fmt.format(summary.totalDebitPkr)}',
                valueColor: context.fx.error,
              ),
              FxStitchBalanceCell(
                label: 'Total Credit',
                value: 'PKR ${widget.fmt.format(summary.totalCreditPkr)}',
                valueColor: context.fx.tertiaryContainer,
              ),
              FxStitchBalanceCell(
                label: 'Closing Balance',
                value: 'PKR ${widget.fmt.format(summary.netBalancePkr)}',
                valueColor: context.fx.primary,
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'Statement Activity',
              style: AppTypography.headlineSm(
                context.fx.primary,
                context: context,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
              icon: const Icon(Icons.filter_list, size: 18),
              label: const Text('Filter'),
            ),
          ],
        ),
        if (_filtersExpanded) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDateRange(context),
                  icon: const Icon(Icons.date_range, size: 16),
                  label: const Text('Dates'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickStatus(context),
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: Text(
                    ref.read(partyStatementFiltersProvider).status.name,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search txn no, reference…',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) {
              ref.read(partyStatementFiltersProvider.notifier).setSearch(v);
              ref.invalidate(partyStatementProvider(widget.partyId));
            },
          ),
          const SizedBox(height: 8),
        ],
        widget.statementAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e'),
          data: (view) {
            if (view == null) return const Text('Unable to load statement.');
            if (view.lines.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No transactions in this period.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              );
            }
            return FxStitchStatementListContainer(
              children: [
                for (final line in view.lines)
                  FxStitchStatementRow(
                    line: line,
                    embedded: true,
                    onTap: () => context.push('/transactions/${line.transactionId}'),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Loading earlier transactions…')),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: context.fx.secondary,
              side: BorderSide(color: context.fx.secondary),
            ),
            child: const Text('Load Earlier Transactions'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final filters = ref.read(partyStatementFiltersProvider);
    final from = await FxObsidianPickers.showDate(
      context,
      initialDate: filters.from,
    );
    if (from == null || !context.mounted) return;
    final to = await FxObsidianPickers.showDate(
      context,
      initialDate: filters.to,
    );
    if (to == null) return;
    ref.read(partyStatementFiltersProvider.notifier).setDateRange(from, to);
    ref.invalidate(partyStatementProvider(widget.partyId));
  }

  Future<void> _pickStatus(BuildContext context) async {
    final picked = await showModalBottomSheet<PartyStatementStatusFilter>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: PartyStatementStatusFilter.values
              .map(
                (s) => ListTile(
                  title: Text(s.name),
                  onTap: () => Navigator.pop(ctx, s),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked != null) {
      ref.read(partyStatementFiltersProvider.notifier).setStatus(picked);
      ref.invalidate(partyStatementProvider(widget.partyId));
    }
  }
}
