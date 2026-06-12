import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_agent_widgets.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum _AgentDealFilter { all, pending, disputed }

/// Stitch agent_statement exact section layout.
class AgentLedgerStitchView extends ConsumerStatefulWidget {
  const AgentLedgerStitchView({
    super.key,
    required this.partyId,
    required this.party,
    required this.statementAsync,
    required this.fmt,
  });

  final String partyId;
  final FxParty party;
  final AsyncValue<PartyStatementView?> statementAsync;
  final NumberFormat fmt;

  @override
  ConsumerState<AgentLedgerStitchView> createState() =>
      _AgentLedgerStitchViewState();
}

class _AgentLedgerStitchViewState extends ConsumerState<AgentLedgerStitchView> {
  _AgentDealFilter _filter = _AgentDealFilter.all;

  @override
  Widget build(BuildContext context) {
    final openDealsAsync = FeatureFlags.dealsWorkflowEnabled
        ? ref.watch(partyDealOpenItemsProvider(widget.partyId))
        : const AsyncValue<List<PartyDealOpenItem>>.data([]);
    final view = widget.statementAsync.whenOrNull(data: (v) => v);
    final summary = view?.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        FxStitchAgentInstitutionHeader(party: widget.party),
        if (summary != null) ...[
          const SizedBox(height: 20),
          FxStitchAgentKpiBento(summary: summary, fmt: widget.fmt),
        ],
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All Deals',
                selected: _filter == _AgentDealFilter.all,
                onTap: () => setState(() => _filter = _AgentDealFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Pending',
                selected: _filter == _AgentDealFilter.pending,
                onTap: () => setState(() => _filter = _AgentDealFilter.pending),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Disputed',
                selected: _filter == _AgentDealFilter.disputed,
                onTap: () => setState(() => _filter = _AgentDealFilter.disputed),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list, size: 18),
                label: Text(
                  'FILTERS',
                  style: AppTypography.labelCaps(
                    context.fx.secondary,
                    context: context,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        openDealsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (items) {
            final filtered = _filterDeals(items);
            if (filtered.isEmpty) {
              return Text(
                'No open deals for this agent.',
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < filtered.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FxStitchAgentDealRow(
                      item: filtered[i],
                      fmt: widget.fmt,
                      highlighted: i == 1,
                      onTap: () => context.push('/deals/${filtered[i].dealId}'),
                    ),
                  ),
              ],
            );
          },
        ),
        if (view != null && view.lines.isNotEmpty) ...[
          const SizedBox(height: 24),
          FxStitchAgentTransferTimeline(lines: view.lines),
        ],
      ],
    );
  }

  List<PartyDealOpenItem> _filterDeals(List<PartyDealOpenItem> items) {
    return switch (_filter) {
      _AgentDealFilter.all => items,
      _AgentDealFilter.pending =>
        items.where((d) => d.dealStatus.isOpen).toList(),
      _AgentDealFilter.disputed => items
          .where((d) => d.dealStatus == FxDealStatus.cancelled)
          .toList(),
    };
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: context.fx.primary,
      checkmarkColor: context.fx.onPrimary,
      labelStyle: AppTypography.labelCaps(
        selected ? context.fx.onPrimary : context.fx.onSurfaceVariant,
        context: context,
      ),
    );
  }
}
