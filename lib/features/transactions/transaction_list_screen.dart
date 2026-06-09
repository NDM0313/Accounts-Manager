import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_filter_chip_row.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_ledger_card.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_bottom_sheet.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_shell.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key, this.inShell = false, this.embeddedInHub = false});

  final bool inShell;
  final bool embeddedInHub;

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final _searchCtrl = TextEditingController();
  FxLedgerFilter _filter = FxLedgerFilter.active;
  bool _last30DaysOnly = false;
  String? _currencyFilter;
  FxLedgerSortOrder _sortOrder = FxLedgerSortOrder.newest;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _refresh() {
    ref.invalidate(draftTransactionsProvider);
    ref.invalidate(todayTransactionsProvider);
    ref.invalidate(voidedTransactionsProvider);
  }

  bool _matchesSearch(FxTransaction tx, String q) {
    if (q.isEmpty) return true;
    final hay = '${tx.transactionNo} ${tx.description} ${tx.currencyCode} ${tx.transactionType.label}'.toLowerCase();
    return hay.contains(q.toLowerCase());
  }

  bool _withinLast30Days(FxTransaction tx) {
    if (!_last30DaysOnly) return true;
    final dt = tx.postedAt ?? tx.createdAt ?? tx.transactionDate;
    return DateTime.now().difference(dt).inDays <= 30;
  }

  bool _matchesCurrency(FxTransaction tx) {
    if (_currencyFilter == null) return true;
    return tx.currencyCode == _currencyFilter;
  }

  List<FxTransaction> _applyFilters(List<FxTransaction> items, String query) {
    return items
        .where((t) => _matchesSearch(t, query) && _withinLast30Days(t) && _matchesCurrency(t))
        .toList();
  }

  Future<void> _pickCurrency(List<FxTransaction> allItems) async {
    final codes = allItems.map((t) => t.currencyCode).toSet().toList()..sort();
    if (codes.isEmpty) return;

    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: context.fx.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Filter by currency', style: AppTypography.headlineMd(context.fx.onSurface, context: context)),
            ),
            ListTile(
              title: Text('All currencies', style: AppTypography.bodyMd(context.fx.onSurface, context: context)),
              trailing: _currencyFilter == null ? Icon(Icons.check, color: context.fx.tertiary) : null,
              onTap: () => Navigator.pop(context, '__all__'),
            ),
            for (final code in codes)
              ListTile(
                title: Text(code, style: AppTypography.bodyMd(context.fx.onSurface, context: context)),
                trailing: _currencyFilter == code ? Icon(Icons.check, color: context.fx.tertiary) : null,
                onTap: () => Navigator.pop(context, code),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (picked == null) return;
    setState(() => _currencyFilter = picked == '__all__' ? null : picked);
  }

  List<FxTransaction> _allLoaded(
    AsyncValue<List<FxTransaction>> draftsAsync,
    AsyncValue<List<FxTransaction>> postedAsync,
    AsyncValue<List<FxTransaction>> voidedAsync,
  ) {
    return [
      ...?draftsAsync.whenOrNull(data: (v) => v),
      ...?postedAsync.whenOrNull(data: (v) => v),
      ...?voidedAsync.whenOrNull(data: (v) => v),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final draftsAsync = ref.watch(draftTransactionsProvider);
    final postedAsync = ref.watch(todayTransactionsProvider);
    final voidedAsync = ref.watch(voidedTransactionsProvider);
    final query = _searchCtrl.text.trim();
    final allForCurrency = _allLoaded(draftsAsync, postedAsync, voidedAsync);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search by Party or Reference…',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: context.fx.surfaceContainerLow,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        FxFilterChipRow(
          selected: _filter,
          onChanged: (f) => setState(() => _filter = f),
          showLast30Days: true,
          last30DaysOnly: _last30DaysOnly,
          onLast30DaysChanged: (v) => setState(() => _last30DaysOnly = v),
          showCurrencyAndMore: true,
          selectedCurrencyCode: _currencyFilter,
          onCurrencyTap: () => _pickCurrency(allForCurrency),
          sortOrder: _sortOrder,
          onSortChanged: (s) => setState(() => _sortOrder = s),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: switch (_filter) {
            FxLedgerFilter.draft => _buildList(draftsAsync, query, emptyLabel: 'No drafts.'),
            FxLedgerFilter.active => _buildList(postedAsync, query, emptyLabel: 'No active transactions.'),
            FxLedgerFilter.voided => _buildList(voidedAsync, query, emptyLabel: 'No voided transactions.'),
            FxLedgerFilter.all => _buildAll(draftsAsync, postedAsync, voidedAsync, query),
          },
        ),
      ],
    );

    final fab = FloatingActionButton(
      onPressed: () => FxObsidianBottomSheet.showTransactionTypes(context),
      backgroundColor: context.fx.tertiary,
      foregroundColor: context.fx.onTertiary,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
      child: const Icon(Icons.add, size: 28),
    );

    if (widget.embeddedInHub) {
      return body;
    }

    if (widget.inShell) {
      return Stack(
        children: [
          FxObsidianPage(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
              16,
              MediaQuery.sizeOf(context).width >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
              88,
            ),
            child: body,
          ),
          Positioned(right: 16, bottom: 88, child: fab),
        ],
      );
    }

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(title: const Text('Transactions'), backgroundColor: context.fx.background),
      floatingActionButton: fab,
      body: Padding(padding: const EdgeInsets.all(16), child: body),
    );
  }

  Widget _buildAll(
    AsyncValue<List<FxTransaction>> draftsAsync,
    AsyncValue<List<FxTransaction>> postedAsync,
    AsyncValue<List<FxTransaction>> voidedAsync,
    String query,
  ) {
    if (draftsAsync.isLoading || postedAsync.isLoading || voidedAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (draftsAsync.hasError) return Center(child: Text('Error: ${draftsAsync.error}'));
    if (postedAsync.hasError) return Center(child: Text('Error: ${postedAsync.error}'));
    if (voidedAsync.hasError) return Center(child: Text('Error: ${voidedAsync.error}'));

    final all = [
      ...?postedAsync.value,
      ...?draftsAsync.value,
      ...?voidedAsync.value,
    ];
    final filtered = _applyFilters(all, query);
    if (filtered.isEmpty) {
      return Center(
        child: Text('No transactions.', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: _groupedList(filtered),
    );
  }

  Widget _buildList(AsyncValue<List<FxTransaction>> async, String query, {required String emptyLabel}) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        final filtered = _applyFilters(items, query);
        if (filtered.isEmpty) {
          return Center(
            child: Text(emptyLabel, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: _groupedList(filtered),
        );
      },
    );
  }

  Widget _groupedList(List<FxTransaction> items) {
    final groups = groupTransactionsByDate(items, sort: _sortOrder);
    final keys = groups.keys.toList();
    if (_sortOrder == FxLedgerSortOrder.oldest) {
      keys.sort();
    }

    final slivers = <Widget>[];
    for (var gi = 0; gi < keys.length; gi++) {
      final key = keys[gi];
      final dayItems = groups[key]!;
      final headerDate = DateTime.parse(key);
      final headerLabel = formatLedgerDateHeader(headerDate).toUpperCase();

      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyDateHeaderDelegate(label: headerLabel),
        ),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final tx = dayItems[i];
              return Padding(
                padding: EdgeInsets.only(bottom: i == dayItems.length - 1 ? 16 : 8),
                child: FxLedgerCard(
                  transaction: tx,
                  onTap: () => context.push('/transactions/${tx.id}'),
                ),
              );
            },
            childCount: dayItems.length,
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: slivers,
    );
  }
}

class _StickyDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyDateHeaderDelegate({required this.label});

  final String label;

  @override
  double get minExtent => 36;

  @override
  double get maxExtent => 36;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: context.fx.background.withValues(alpha: 0.95),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(label, style: AppTypography.labelCaps(context.fx.onSurfaceVariant, context: context)),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyDateHeaderDelegate old) => old.label != label;
}
