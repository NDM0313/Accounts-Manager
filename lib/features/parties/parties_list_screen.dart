import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_shell.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    final fallback = widget.initialFilter == FxPartyType.agent ? '/accounts-hub' : '/parties';

    return FxPageScaffold(
      fallbackRoute: fallback,
      title: Text(widget.initialFilter == FxPartyType.agent ? 'Agent Ledger' : 'Parties'),
      floatingActionButton: widget.initialFilter == FxPartyType.agent
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/parties/new'),
              child: const Icon(Icons.add),
            ),
      body: FxObsidianPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final t in FxPartyType.values)
                  FilterChip(
                    label: Text(t.label),
                    selected: _filter == t,
                    onSelected: (_) => setState(() => _filter = t),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tap a party to view settlement history. Link parties when creating Settlement Send/Receive.',
              style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: partiesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (parties) {
                  if (parties.isEmpty) {
                    return Center(
                      child: Text(
                        'No parties found.',
                        style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurfaceVariant, context: context),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: parties.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = parties[i];
                      return Material(
                        color: context.fx.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                          onTap: () => context.push('/parties/${p.id}/ledger'),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name, style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text('${p.code} · ${p.partyType.label}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: context.fx.outline),
                              ],
                            ),
                          ),
                        ),
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
}

/// Agent ledger entry point — same list filtered to agents.
class AgentLedgerScreen extends StatelessWidget {
  const AgentLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PartiesListScreen(initialFilter: FxPartyType.agent);
  }
}
