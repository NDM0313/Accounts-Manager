import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_shell.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_party_statement_row.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/services/party_statement_builder.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:accounts_manager/core/export/fx_document_export.dart';
import 'package:accounts_manager/core/export/report_pdf_builder.dart';

class PartyLedgerScreen extends ConsumerStatefulWidget {
  const PartyLedgerScreen({super.key, required this.partyId});

  final String partyId;

  @override
  ConsumerState<PartyLedgerScreen> createState() => _PartyLedgerScreenState();
}

class _PartyLedgerScreenState extends ConsumerState<PartyLedgerScreen> {
  bool _filtersExpanded = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partyAsync = ref.watch(partyDetailProvider(widget.partyId));
    final statementAsync = ref.watch(partyStatementProvider(widget.partyId));
    final openDealsAsync = FeatureFlags.dealsWorkflowEnabled
        ? ref.watch(partyDealOpenItemsProvider(widget.partyId))
        : const AsyncValue<List<PartyDealOpenItem>>.data([]);
    final fmt = NumberFormat('#,##0.00');

    return FxPageScaffold(
      fallbackRoute: '/parties',
      title: partyAsync.when(
        data: (p) => Text(p?.name ?? 'Party Statement'),
        loading: () => const Text('Party Statement'),
        error: (_, _) => const Text('Party Statement'),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: () => _exportStatement(context, customerCopy: false),
        ),
      ],
      floatingActionButton: partyAsync.whenOrNull(
        data: (party) => party == null ? null : _buildFab(context, party),
      ),
      body: FxObsidianPage(
        child: partyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (party) {
            if (party == null) return const Center(child: Text('Party not found.'));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _partyHeader(context, party, statementAsync, fmt),
                _openDealsSection(context, openDealsAsync, fmt),
                _filtersSection(context),
                Expanded(
                  child: statementAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (view) {
                      if (view == null) return const Center(child: Text('Unable to load statement.'));
                      if (view.lines.isEmpty) {
                        return _emptyState(context, party);
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: view.lines.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final line = view.lines[i];
                          return FxPartyStatementRow(
                            line: line,
                            onTap: () => context.push('/transactions/${line.transactionId}'),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _partyHeader(
    BuildContext context,
    FxParty party,
    AsyncValue<PartyStatementView?> statementAsync,
    NumberFormat fmt,
  ) {
    final view = statementAsync.whenOrNull(data: (v) => v);
    final summary = view?.summary;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.fx.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  party.partyType.label.toUpperCase(),
                  style: AppTypography.labelCaps(context.fx.primary, context: context).copyWith(fontSize: 9),
                ),
              ),
              const Spacer(),
              if (summary != null)
                Text(
                  'Net PKR ${fmt.format(summary.netBalancePkr)}',
                  style: AppTypography.headlineMd(context.fx.onSurface, context: context).copyWith(fontSize: 16),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(party.name, style: AppTypography.headlineMd(context.fx.onSurface, context: context)),
          if (party.phone != null)
            Text(party.phone!, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
          if (summary != null && view != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  FxPartySummaryCard(label: 'Opening', value: fmt.format(view.openingBalancePkr)),
                  const SizedBox(width: 8),
                  FxPartySummaryCard(label: 'Total Debit', value: fmt.format(summary.totalDebitPkr)),
                  const SizedBox(width: 8),
                  FxPartySummaryCard(label: 'Total Credit', value: fmt.format(summary.totalCreditPkr)),
                  const SizedBox(width: 8),
                  FxPartySummaryCard(label: 'Net Balance', value: fmt.format(summary.netBalancePkr)),
                  const SizedBox(width: 8),
                  FxPartySummaryCard(label: 'Pending', value: '${summary.pendingDraftCount}'),
                  if (summary.lastTransactionDate != null) ...[
                    const SizedBox(width: 8),
                    FxPartySummaryCard(
                      label: 'Last txn',
                      value: DateFormat('d MMM yy').format(summary.lastTransactionDate!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _openDealsSection(BuildContext context, AsyncValue<List<PartyDealOpenItem>> openDealsAsync, NumberFormat fmt) {
    return openDealsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.fx.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: context.fx.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OPEN FX DEALS', style: AppTypography.labelCaps(context.fx.outline, context: context)),
              const SizedBox(height: 8),
              ...items.map((item) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.dealNo ?? item.dealId.substring(0, 8), style: AppTypography.bodyMd(context.fx.onSurface, context: context)),
                  subtitle: Text(
                    '${item.role} · ${item.dealStatus.label} · recv PKR ${fmt.format(item.receivablePkr)}',
                    style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => context.push('/deals/${item.dealId}'),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _filtersSection(BuildContext context) {
    final filters = ref.watch(partyStatementFiltersProvider);
    final fromLabel = DateFormat('d MMM yy').format(filters.from);
    final toLabel = DateFormat('d MMM yy').format(filters.to);

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 18, color: context.fx.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$fromLabel → $toLabel · ${filters.status.name}',
                    style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                  ),
                ),
                Icon(_filtersExpanded ? Icons.expand_less : Icons.expand_more, color: context.fx.onSurfaceVariant),
              ],
            ),
          ),
        ),
        if (_filtersExpanded) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDateRange(context),
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text('Dates', style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickStatus(context),
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: Text(filters.status.name, style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search txn no, reference…',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
            ),
            onSubmitted: (v) {
              ref.read(partyStatementFiltersProvider.notifier).setSearch(v);
              ref.invalidate(partyStatementProvider(widget.partyId));
            },
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        const FxSectionLabel(label: 'Statement'),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _emptyState(BuildContext context, FxParty party) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No transactions in this period.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showActions(context, party),
              icon: const Icon(Icons.add),
              label: const Text('New transaction'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context, FxParty party) {
    return FloatingActionButton(
      onPressed: () => _showActions(context, party),
      backgroundColor: context.fx.tertiary,
      foregroundColor: context.fx.onTertiary,
      child: const Icon(Icons.add),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final filters = ref.read(partyStatementFiltersProvider);
    final from = await FxObsidianPickers.showDate(context, initialDate: filters.from);
    if (from == null || !context.mounted) return;
    final to = await FxObsidianPickers.showDate(context, initialDate: filters.to);
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

  void _showActions(BuildContext context, FxParty party) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.call_received),
              title: const Text('Receive Payment'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(
                  '/transactions/new?type=${FxTransactionType.settlementReceive.dbValue}&partyId=${widget.partyId}',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.send_outlined),
              title: const Text('Send Payment'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(
                  '/transactions/new?type=${FxTransactionType.settlementSend.dbValue}&partyId=${widget.partyId}',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.handshake_outlined),
              title: const Text('New Deal'),
              onTap: () {
                Navigator.pop(ctx);
                final type = party.partyType == FxPartyType.customer
                    ? FxTransactionType.currencySell
                    : FxTransactionType.currencyBuy;
                context.push(
                  '/transactions/new?type=${type.dbValue}&partyId=${widget.partyId}',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('Export / Print'),
              onTap: () {
                Navigator.pop(ctx);
                _exportStatement(context, customerCopy: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportStatement(BuildContext context, {required bool customerCopy}) async {
    final view = ref.read(partyStatementProvider(widget.partyId)).whenOrNull(data: (v) => v);
    if (view == null || view.lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No statement data to share.')),
      );
      return;
    }
    final internal = !customerCopy;
    final text = PartyStatementBuilder.formatShareText(view, internal: internal);
    final csv = PartyStatementBuilder.formatShareCsv(view);
    final pdfRows = view.lines
        .map((l) => [
              l.transactionDate.toIso8601String().split('T').first,
              l.transactionNo ?? l.transactionId.substring(0, 8),
              l.transactionType.label,
              l.currencyCode,
              l.debitPkr.toStringAsFixed(2),
              l.creditPkr.toStringAsFixed(2),
              l.runningBalancePkr.toStringAsFixed(2),
            ])
        .toList();
    final pdf = await buildStatementPdf(
      title: 'Party Statement',
      partyName: view.party.name,
      periodLabel: '${view.from.toIso8601String().split('T').first} → ${view.to.toIso8601String().split('T').first}',
      displayCurrency: 'PKR',
      lineRows: pdfRows,
      totalDebit: view.summary.totalDebitPkr.toStringAsFixed(2),
      totalCredit: view.summary.totalCreditPkr.toStringAsFixed(2),
      closingBalance: view.summary.netBalancePkr.toStringAsFixed(2),
      internal: internal,
    );
    if (!context.mounted) return;
    await showFxExportSheet(
      context,
      mode: internal ? FxExportMode.internal : FxExportMode.customerFacing,
      document: FxExportDocument(
        title: 'Party Statement — ${view.party.name}',
        textBody: text,
        csvBody: csv,
        pdfBytes: pdf,
        subject: 'Party Statement — ${view.party.name}',
      ),
    );
  }
}
