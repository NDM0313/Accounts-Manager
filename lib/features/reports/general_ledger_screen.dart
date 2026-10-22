import 'package:accounts_manager/app/theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(reportDateRangeProvider);
    final rowsAsync = ref.watch(generalLedgerProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final accountFilter = ref.watch(generalLedgerAccountFilterProvider);
    final cashAsync = ref.watch(cashBalancesProvider);
    final positionAsync = ref.watch(currencyPositionProvider);
    final fmt = NumberFormat('#,##0.00');
    final compactFmt =
        NumberFormat.compactCurrency(symbol: 'PKR ', decimalDigits: 0);
    final fromLabel = range.from.toIso8601String().split('T').first;
    final toLabel = range.to.toIso8601String().split('T').first;
    final days = range.to.difference(range.from).inDays;
    final dateLabel = days <= 31 ? 'Last 30 Days' : '$fromLabel → $toLabel';

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: FxPageHeader.appBar(
        context: context,
        fallbackRoute: '/reports',
        title: const Text('General Ledger'),
      ),
      body: FxContentContainer(
        padding: const EdgeInsets.only(top: AppSpacing.stackMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: cashAsync.when(
                data: (rows) {
                  final net = rows.fold<double>(0, (s, r) => s + r.balancePkr);
                  final currencyCount =
                      positionAsync.whenOrNull(data: (p) => p.length) ?? 0;
                  return FxStitchGlBentoHeader(
                    netWorthLabel: compactFmt.format(net),
                    activeLedgerLabel: '$currencyCount',
                    lastSettlementLabel: toLabel,
                  );
                },
                loading: () => const FxLoadingState(),
                error: (e, _) => FxErrorState(message: 'Unable to load cash balances: $e'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FxStitchGlFilterBar(
                dateRangeLabel: dateLabel,
                onDateTap: () => _pickRange(context, ref, range),
                onMoreFiltersTap: () => _pickRange(context, ref, range),
                chips: [
                  FxStitchGlFilterChip(
                    label: 'All Accounts',
                    selected: _chipFilter == _GlFilter.all,
                    onTap: () => setState(() => _chipFilter = _GlFilter.all),
                  ),
                  FxStitchGlFilterChip(
                    label: 'Primary',
                    selected: _chipFilter == _GlFilter.primary,
                    onTap: () => setState(() => _chipFilter = _GlFilter.primary),
                  ),
                  FxStitchGlFilterChip(
                    label: 'Settlement',
                    selected: _chipFilter == _GlFilter.settlement,
                    onTap: () =>
                        setState(() => _chipFilter = _GlFilter.settlement),
                  ),
                  FxStitchGlFilterChip(
                    label: 'Custody',
                    selected: _chipFilter == _GlFilter.custody,
                    onTap: () => setState(() => _chipFilter = _GlFilter.custody),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                        final accountColumn = FxStitchAccountListColumn(
                          accounts: filtered,
                          accountCount: filtered.length,
                          selectedCode: accountFilter,
                          scrollable: true,
                          onSelected: (code) => ref
                              .read(
                                generalLedgerAccountFilterProvider.notifier,
                              )
                              .set(code),
                        );
                        final activity = rowsAsync.when(
                          loading: () => const FxLoadingState(),
                          error: (e, _) => FxErrorState(
                            message: 'Unable to load ledger activity: $e',
                          ),
                          data: (rows) => SingleChildScrollView(
                            child: FxStitchGlActivityTable(
                              rows: rows,
                              fmt: fmt,
                            ),
                          ),
                        );

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 300,
                                child: accountColumn,
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: activity),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 2, child: accountColumn),
                            const SizedBox(height: 16),
                            Expanded(flex: 3, child: activity),
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
}
