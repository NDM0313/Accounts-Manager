import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AgentRemittanceInboxScreen extends ConsumerStatefulWidget {
  const AgentRemittanceInboxScreen({super.key});

  @override
  ConsumerState<AgentRemittanceInboxScreen> createState() => _AgentRemittanceInboxScreenState();
}

class _AgentRemittanceInboxScreenState extends ConsumerState<AgentRemittanceInboxScreen> {
  final _search = TextEditingController();
  String? _query;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(agentRemittancesProvider(_query));
    final fmt = NumberFormat('#,##0.00');

    return FxPageScaffold(
      title: const Text('Agent Remittance'),
      fallbackRoute: '/remittance',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'RM number, receiver, phone, payout code',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = null);
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (v) => setState(() => _query = v.trim().isEmpty ? null : v.trim()),
            ),
          ),
          Expanded(
            child: listAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) => items.isEmpty
                  ? Center(child: Text('No remittances assigned', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) => _tile(context, items[i], fmt),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, FxRemittance r, NumberFormat fmt) {
    return ListTile(
      title: Text(r.remittanceNo ?? r.trackingId),
      subtitle: Text('${r.receiverName} · ${r.payoutCurrency} ${fmt.format(r.payoutAmount)} · ${r.status.label}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/remittance/agent/${r.id}'),
    );
  }
}
