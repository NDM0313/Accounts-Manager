import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/widgets/premium/fx_amount_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_search_field.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:accounts_manager/features/remittance/widgets/fx_remittance_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum _RemittanceListFilter { all, open, awaitingPayment, inProgress, settled }

class RemittanceListScreen extends ConsumerStatefulWidget {
  const RemittanceListScreen({super.key});

  @override
  ConsumerState<RemittanceListScreen> createState() =>
      _RemittanceListScreenState();
}

class _RemittanceListScreenState extends ConsumerState<RemittanceListScreen> {
  final _search = TextEditingController();
  _RemittanceListFilter _filter = _RemittanceListFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchesFilter(FxRemittance r) {
    return switch (_filter) {
      _RemittanceListFilter.all => true,
      _RemittanceListFilter.open => r.status.isOpen,
      _RemittanceListFilter.awaitingPayment =>
        r.status == FxRemittanceStatus.booked && r.balanceDue > 0,
      _RemittanceListFilter.inProgress =>
        r.status == FxRemittanceStatus.customerPaid ||
            r.status == FxRemittanceStatus.sentToAgent ||
            r.status == FxRemittanceStatus.readyForPayout ||
            r.status == FxRemittanceStatus.paidOut,
      _RemittanceListFilter.settled =>
        r.status == FxRemittanceStatus.completed ||
            r.status == FxRemittanceStatus.cancelled ||
            r.status == FxRemittanceStatus.refunded,
    };
  }

  bool _matchesSearch(FxRemittance r, String q) {
    if (q.isEmpty) return true;
    final lower = q.toLowerCase();
    return (r.trackingId.toLowerCase().contains(lower)) ||
        (r.remittanceNo?.toLowerCase().contains(lower) ?? false) ||
        r.receiverName.toLowerCase().contains(lower) ||
        (r.receiverPhone?.contains(q) ?? false) ||
        (r.payoutCode?.contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.remittanceWorkflowEnabled) {
      return FxPremiumScaffold(
        title: const Text('Remittance'),
        fallbackRoute: '/',
        body: const Center(child: Text('Remittance module is disabled.')),
      );
    }

    final listAsync = ref.watch(remittancesListProvider);
    final fmt = NumberFormat('#,##0.00');
    final q = _search.text.trim();

    return FxPremiumScaffold(
      fallbackRoute: '/',
      title: const Text('Remittance'),
      actions: [
        Consumer(
          builder: (context, ref, _) {
            final unread = ref.watch(unreadNotificationsCountProvider);
            final count = unread.value ?? 0;
            return IconButton(
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () => context.push('/notifications'),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.support_agent_outlined),
          tooltip: 'Agent workspace',
          onPressed: () => context.push('/remittance/agent'),
        ),
        IconButton(
          icon: const Icon(Icons.assessment_outlined),
          tooltip: 'Reports',
          onPressed: () => context.push('/remittance/reports'),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/remittance/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load remittances.\nApply migration 202606230001 if tables are missing.\n\n$e',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ),
            ),
          ),
        ),
        data: (items) {
          final filtered = items
              .where((r) => _matchesFilter(r) && _matchesSearch(r, q))
              .toList();
          final today = DateTime.now();
          final todayItems = items.where((r) {
            final created = r.createdAt;
            if (created == null) return false;
            return created.year == today.year &&
                created.month == today.month &&
                created.day == today.day;
          }).toList();
          final todayReceived = todayItems.fold<double>(
            0,
            (sum, r) => sum + r.paidAmount,
          );
          final openCount = items.where((r) => r.status.isOpen).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FxAmountCard(
                label: 'Today received',
                amountLabel: 'PKR ${fmt.format(todayReceived)}',
                trendLabel: '$openCount open orders',
              ),
              const SizedBox(height: 12),
              FxPremiumSearchField(
                controller: _search,
                hintText: 'Search RM, receiver, phone, payout code…',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('All', _RemittanceListFilter.all),
                    _filterChip('Open', _RemittanceListFilter.open),
                    _filterChip(
                      'Awaiting pay',
                      _RemittanceListFilter.awaitingPayment,
                    ),
                    _filterChip(
                      'In progress',
                      _RemittanceListFilter.inProgress,
                    ),
                    _filterChip('Settled', _RemittanceListFilter.settled),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Center(
                    child: Text(
                      items.isEmpty
                          ? 'No remittance orders yet.\nTrack hawala / payout orders separately from FX deals.'
                          : 'No remittances match your filters.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMd(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ),
                    ),
                  ),
                )
              else
                ...filtered.map(
                  (r) => FxRemittanceCard(
                    remittance: r,
                    fmt: fmt,
                    showBalanceDue: true,
                    onTap: () => context.push('/remittance/${r.id}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, _RemittanceListFilter value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}
