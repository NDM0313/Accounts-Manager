import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_account_list_column.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_gl_widgets.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

enum _GlFilter { all, primary, settlement, custody }

/// Returns every filtered account for GL — never truncates the list.
List<FxAccount> visibleGlAccounts(List<FxAccount> filtered) =>
    List<FxAccount>.from(filtered);

class GeneralLedgerScreen extends ConsumerStatefulWidget {
  const GeneralLedgerScreen({super.key});

  @override
  ConsumerState<GeneralLedgerScreen> createState() =>
      _GeneralLedgerScreenState();
}

class _GeneralLedgerScreenState extends ConsumerState<GeneralLedgerScreen> {
  _GlFilter _chipFilter = _GlFilter.all;
  bool _summaryExpanded = false;

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(reportDateRangeProvider);
    final rowsAsync = ref.watch(generalLedgerProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final accountFilter = ref.watch(generalLedgerAccountFilterProvider);
    final cashAsync = ref.watch(cashBalancesProvider);
    final positionAsync = ref.watch(currencyPositionProvider);
    final fmt = NumberFormat('#,##0.00');
    final fromLabel = range.from.toIso8601String().split('T').first;
    final toLabel = range.to.toIso8601String().split('T').first;
    final days = range.to.difference(range.from).inDays + 1;
    final dateLabel = days <= 31 ? 'Last $days days' : '$fromLabel → $toLabel';
    final activeFilterCount = (_chipFilter == _GlFilter.all ? 0 : 1) +
        (accountFilter != null ? 1 : 0);

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: FxPageHeader.appBar(
        context: context,
        fallbackRoute: '/reports',
        title: const Text('General Ledger'),
      ),
      body: FxContentContainer(
        padding: const EdgeInsets.only(top: AppSpacing.stackSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: cashAsync.when(
                data: (rows) {
                  final net = rows.fold<double>(0, (s, r) => s + r.balancePkr);
                  final currencyCount =
                      positionAsync.whenOrNull(data: (p) => p.length) ?? 0;
                  return _CompactGlSummary(
                    cashPkrLabel: 'PKR ${fmt.format(net)}',
                    dateLabel: dateLabel,
                    currencyCount: currencyCount,
                    expanded: _summaryExpanded,
                    onToggle: () =>
                        setState(() => _summaryExpanded = !_summaryExpanded),
                    onDateTap: () => _pickRange(context, ref, range),
                  );
                },
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (e, _) => Text(
                  'Cash summary unavailable',
                  style: AppTypography.bodySm(
                    context.fx.error,
                    context: context,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openFilterSheet(
                        context,
                        dateLabel: dateLabel,
                        activeCount: activeFilterCount,
                      ),
                      icon: const Icon(Icons.tune, size: 18),
                      label: Text(
                        activeFilterCount == 0
                            ? 'Filters'
                            : 'Filters ($activeFilterCount)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (activeFilterCount > 0)
                    TextButton(
                      onPressed: () {
                        setState(() => _chipFilter = _GlFilter.all);
                        ref
                            .read(generalLedgerAccountFilterProvider.notifier)
                            .set(null);
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            if (accountFilter != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    label: Text('Account $accountFilter'),
                    onDeleted: () => ref
                        .read(generalLedgerAccountFilterProvider.notifier)
                        .set(null),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: accountsAsync.when(
                  loading: () => const FxLoadingState(),
                  error: (e, _) =>
                      FxErrorState(message: 'Unable to load accounts: $e'),
                  data: (accounts) {
                    final filtered =
                        visibleGlAccounts(_filterAccounts(accounts));
                    if (filtered.isEmpty) {
                      return const FxEmptyState(
                        message: 'No accounts match this filter.',
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = FxLayoutBreakpoints.isDesktop(
                          constraints.maxWidth,
                        );
                        final activity = rowsAsync.when(
                          loading: () => const FxLoadingState(),
                          error: (e, _) => FxErrorState(
                            message: 'Unable to load ledger activity: $e',
                          ),
                          data: (rows) => FxStitchGlActivityTable(
                            rows: rows,
                            fmt: fmt,
                          ),
                        );

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 300,
                                child: FxStitchAccountListColumn(
                                  accounts: filtered,
                                  accountCount: filtered.length,
                                  selectedCode: accountFilter,
                                  scrollable: true,
                                  onSelected: (code) => ref
                                      .read(
                                        generalLedgerAccountFilterProvider
                                            .notifier,
                                      )
                                      .set(code),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SingleChildScrollView(child: activity),
                              ),
                            ],
                          );
                        }

                        // Mobile: one scroll surface — account picker header + activity.
                        FxAccount? selected;
                        for (final a in filtered) {
                          if (a.code == accountFilter) {
                            selected = a;
                            break;
                          }
                        }
                        return CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: _MobileAccountHeader(
                                selected: selected,
                                accountCount: filtered.length,
                                onPick: () => _openAccountSheet(
                                  context,
                                  filtered,
                                  accountFilter,
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 8),
                            ),
                            SliverToBoxAdapter(child: activity),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FxAccount> _filterAccounts(List<FxAccount> accounts) {
    return switch (_chipFilter) {
      _GlFilter.all => accounts,
      _GlFilter.primary => accounts
          .where((a) => a.code.startsWith('1') || a.code.startsWith('2'))
          .toList(),
      _GlFilter.settlement => accounts
          .where((a) => a.name.toLowerCase().contains('settlement'))
          .toList(),
      _GlFilter.custody => accounts
          .where((a) => a.name.toLowerCase().contains('custody'))
          .toList(),
    };
  }

  Future<void> _pickRange(
    BuildContext context,
    WidgetRef ref,
    ReportDateRange current,
  ) async {
    final from = await FxObsidianPickers.showDate(
      context,
      initialDate: current.from,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (from == null || !context.mounted) return;
    final to = await FxObsidianPickers.showDate(
      context,
      initialDate: current.to.isBefore(from) ? from : current.to,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (to != null) {
      ref.read(reportDateRangeProvider.notifier).setRange(from, to);
    }
  }

  Future<void> _openFilterSheet(
    BuildContext context, {
    required String dateLabel,
    required int activeCount,
  }) async {
    final range = ref.read(reportDateRangeProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ledger filters${activeCount == 0 ? '' : ' ($activeCount active)'}',
                  style: AppTypography.headlineSm(
                    ctx.fx.onSurface,
                    context: ctx,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date range'),
                  subtitle: Text(dateLabel),
                  trailing: const Icon(Icons.date_range_outlined),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickRange(context, ref, range);
                  },
                ),
                const Divider(),
                for (final f in _GlFilter.values)
                  ListTile(
                    title: Text(switch (f) {
                      _GlFilter.all => 'All accounts',
                      _GlFilter.primary => 'Primary (1xxx / 2xxx)',
                      _GlFilter.settlement => 'Settlement',
                      _GlFilter.custody => 'Custody',
                    }),
                    trailing: _chipFilter == f
                        ? Icon(Icons.check, color: ctx.fx.primary)
                        : null,
                    onTap: () {
                      setState(() => _chipFilter = f);
                      Navigator.pop(ctx);
                    },
                  ),
                TextButton(
                  onPressed: () {
                    setState(() => _chipFilter = _GlFilter.all);
                    ref
                        .read(generalLedgerAccountFilterProvider.notifier)
                        .set(null);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Reset filters'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAccountSheet(
    BuildContext context,
    List<FxAccount> accounts,
    String? selected,
  ) async {
    final search = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final q = search.text.trim().toLowerCase();
            final filtered = q.isEmpty
                ? accounts
                : accounts
                    .where(
                      (a) =>
                          a.code.toLowerCase().contains(q) ||
                          a.name.toLowerCase().contains(q),
                    )
                    .toList();
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        controller: search,
                        decoration: const InputDecoration(
                          hintText: 'Search accounts…',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setLocal(() {}),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final a = filtered[i];
                          return ListTile(
                            selected: a.code == selected,
                            title: Text('${a.code} · ${a.name}'),
                            onTap: () {
                              ref
                                  .read(
                                    generalLedgerAccountFilterProvider.notifier,
                                  )
                                  .set(a.code);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    search.dispose();
  }
}

class _CompactGlSummary extends StatelessWidget {
  const _CompactGlSummary({
    required this.cashPkrLabel,
    required this.dateLabel,
    required this.currencyCount,
    required this.expanded,
    required this.onToggle,
    required this.onDateTap,
  });

  final String cashPkrLabel;
  final String dateLabel;
  final int currencyCount;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onDateTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.fx.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cash & bank $cashPkrLabel',
                    style: AppTypography.dataMd(
                      context.fx.onSurface,
                      context: context,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: expanded ? 'Hide details' : 'Show details',
                  onPressed: onToggle,
                  icon: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: onDateTap,
              child: Text(
                dateLabel,
                style: AppTypography.bodySm(
                  context.fx.primary,
                  context: context,
                ),
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              Text(
                '$currencyCount active currencies in position view',
                style: AppTypography.bodySm(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MobileAccountHeader extends StatelessWidget {
  const _MobileAccountHeader({
    required this.selected,
    required this.accountCount,
    required this.onPick,
  });

  final FxAccount? selected;
  final int accountCount;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPick,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected == null
                      ? 'Select account ($accountCount)'
                      : '${selected!.code} · ${selected!.name}',
                  style: AppTypography.dataMd(
                    context.fx.onSurface,
                    context: context,
                  ),
                ),
                Text(
                  selected == null
                      ? 'Searchable list — all accounts available'
                      : 'Tap to change account',
                  style: AppTypography.bodySm(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.unfold_more),
        ],
      ),
    );
  }
}
