import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:accounts_manager/domain/services/party_statement_narrative.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Customer ledger — design-system reference screen.
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
    final closing = summary?.netBalancePkr ?? 0;
    final balanceText = PartyStatementNarrative.balanceExplanation(
      partyType: widget.party.partyType,
      closingPkr: closing,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.fxHorizontalInset,
        AppSpacing.stackSm,
        context.fxHorizontalInset,
        AppSpacing.shellBottomInset,
      ),
      children: [
        FxStitchCard(
          padding: const EdgeInsets.all(AppSpacing.stackMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FxPageTitleBlock(
                title: widget.party.name,
                subtitle: [
                  if (widget.party.code.trim().isNotEmpty) widget.party.code,
                  'Customer',
                  if (widget.party.phone != null &&
                      widget.party.phone!.trim().isNotEmpty)
                    widget.party.phone!,
                ].join(' · '),
                trailing: IconButton(
                  tooltip: 'Export',
                  onPressed: widget.onExport,
                  icon: const Icon(Icons.ios_share_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              Text(
                'Current balance (as of now)',
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 12),
              ),
              const SizedBox(height: 4),
              if (closing.abs() < 0.005)
                Text(
                  'Settled / No outstanding',
                  style: AppTypography.headlineSm(
                    AppColors.lightSuccess,
                    context: context,
                  ),
                )
              else ...[
                FxMoneyLabel(
                  amount: closing.abs(),
                  bold: true,
                  fontSize: 22,
                  align: TextAlign.start,
                ),
                const SizedBox(height: 2),
                Text(
                  balanceText.isNotEmpty
                      ? balanceText
                      : (closing > 0
                          ? 'Receivable (customer owes)'
                          : 'Payable / advance (we owe or hold credit)'),
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (view != null && summary != null) ...[
          const SizedBox(height: AppSpacing.stackMd),
          FxLedgerSummaryStrip(
            opening: view.openingBalancePkr,
            periodDebits: summary.totalDebitPkr,
            periodCredits: summary.totalCreditPkr,
            closing: view.closingBalancePkr,
            periodLabel:
                'Selected period · Closing for range (may differ from current)',
          ),
        ],
        const SizedBox(height: AppSpacing.stackMd),
        FxFilterToolbar(
          searchController: _searchCtrl,
          searchHint: 'Search txn no, reference…',
          onSearchSubmitted: (v) {
            ref.read(partyStatementFiltersProvider.notifier).setSearch(v);
            ref.invalidate(partyStatementProvider(widget.partyId));
          },
          filters: [
            FxFilterChipButton(
              label: 'Dates',
              onPressed: () => _pickDateRange(context),
            ),
            FxFilterChipButton(
              label: ref.watch(partyStatementFiltersProvider).status.name,
              onPressed: () => _pickStatus(context),
            ),
          ],
          trailing: FilledButton.tonal(
            onPressed: () => context.push(
              '/transactions/receive-payment?partyId=${widget.partyId}',
            ),
            child: const Text('Receive'),
          ),
        ),
        const SizedBox(height: AppSpacing.stackMd),
        Text(
          'Activity',
          style: AppTypography.headlineSm(
            context.fx.onSurface,
            context: context,
          ),
        ),
        const SizedBox(height: AppSpacing.stackSm),
        widget.statementAsync.when(
          loading: () => const FxLoadingState(),
          error: (e, _) => FxErrorState(
            message: 'Error: $e',
            onRetry: () =>
                ref.invalidate(partyStatementProvider(widget.partyId)),
          ),
          data: (view) {
            if (view == null) {
              return const FxEmptyState(message: 'Unable to load statement.');
            }
            return FxResponsiveLedgerView(
              lines: view.lines,
              newestFirst: true,
              rangeTo: view.to,
              onOpenTransaction: (line) =>
                  context.push('/transactions/${line.transactionId}'),
            );
          },
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
