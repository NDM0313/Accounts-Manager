import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_help_tip_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_search_field.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:accounts_manager/features/remittance/widgets/fx_remittance_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AgentRemittanceInboxScreen extends ConsumerStatefulWidget {
  const AgentRemittanceInboxScreen({super.key});

  @override
  ConsumerState<AgentRemittanceInboxScreen> createState() =>
      _AgentRemittanceInboxScreenState();
}

class _AgentRemittanceInboxScreenState
    extends ConsumerState<AgentRemittanceInboxScreen> {
  final _search = TextEditingController();
  String? _query;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submitSearch(String v) {
    setState(() => _query = v.trim().isEmpty ? null : v.trim());
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(agentRemittancesProvider(_query));
    final fmt = NumberFormat('#,##0.00');

    return FxPremiumScaffold(
      title: const Text('Agent Remittance'),
      fallbackRoute: '/remittance',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                FxPremiumSearchField(
                  controller: _search,
                  hintText: 'RM number, receiver, phone, payout code',
                  onChanged: (v) {
                    if (v.isEmpty) setState(() => _query = null);
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _submitSearch(_search.text),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Search'),
                  ),
                ),
                const FxHelpTipCard(
                  title: 'Agent setup',
                  body:
                      'Your profile must have linked_party_id set to your agent party and can_agent_remittance permission. You only see remittances assigned to your agent.',
                ),
              ],
            ),
          ),
          Expanded(
            child: listAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No remittances assigned',
                      style: AppTypography.bodyMd(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ),
                    ),
                  );
                }
                final pending = items
                    .where(
                      (r) =>
                          r.status == FxRemittanceStatus.sentToAgent ||
                          r.status == FxRemittanceStatus.readyForPayout,
                    )
                    .length;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (pending > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '$pending pending payout${pending == 1 ? '' : 's'}',
                          style: AppTypography.bodyMd(
                            context.fx.secondary,
                            context: context,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ...items.map(
                      (r) => FxRemittanceCard(
                        remittance: r,
                        fmt: fmt,
                        subtitle:
                            '${r.receiverName} · ${r.payoutCurrency} ${fmt.format(r.payoutAmount)}',
                        onTap: () => context.push('/remittance/agent/${r.id}'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
