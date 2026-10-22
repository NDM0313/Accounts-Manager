import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
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

    final fallback = widget.initialFilter == FxPartyType.agent
        ? '/accounts-hub'
        : '/parties';
    final pageTitle = widget.initialFilter == FxPartyType.agent
        ? 'Agent Ledger'
        : 'Parties';

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
              'Tap a party to view settlement history. Link parties when creating Settlement Send/Receive.',
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
                  return ListView.separated(
                    itemCount: parties.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.stackSm),
                    itemBuilder: (context, i) {
                      final p = parties[i];
                      return Material(
                        color: context.fx.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusLg,
                          ),
                          onTap: () => context.push('/parties/${p.id}/ledger'),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: AppTypography.bodyMd(
                                          context.fx.onSurface,
                                          context: context,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${p.code} · ${p.partyType.label}',
                                        style: AppTypography.bodyMd(
                                          context.fx.onSurfaceVariant,
                                          context: context,
                                        ).copyWith(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: context.fx.outline,
                                ),
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
