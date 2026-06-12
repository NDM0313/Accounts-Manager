import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class RemittanceReportsScreen extends ConsumerStatefulWidget {
  const RemittanceReportsScreen({super.key});

  @override
  ConsumerState<RemittanceReportsScreen> createState() =>
      _RemittanceReportsScreenState();
}

class _RemittanceReportsScreenState
    extends ConsumerState<RemittanceReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _fmt = NumberFormat('#,##0.00');
  Map<String, dynamic>? _cashFlow;
  Map<String, dynamic>? _branchStmt;
  Map<String, dynamic>? _agentStmt;
  Map<String, dynamic>? _customerStmt;
  String? _agentId;
  String? _customerId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCashFlow());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadCashFlow() async {
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null) return;
    setState(() => _loading = true);
    try {
      _cashFlow = await ref
          .read(remittanceRepositoryProvider)
          .fetchCashFlowSummary(profile.branchId, DateTime.now());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBranch() async {
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null) return;
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      _branchStmt = await ref
          .read(remittanceRepositoryProvider)
          .fetchBranchStatement(profile.branchId, from, now);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAgent() async {
    if (_agentId == null) return;
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      _agentStmt = await ref
          .read(remittanceRepositoryProvider)
          .fetchAgentStatement(_agentId!, from, now);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCustomer() async {
    if (_customerId == null) return;
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      _customerStmt = await ref
          .read(remittanceRepositoryProvider)
          .fetchCustomerStatement(_customerId!, from, now);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(partiesProvider(FxPartyType.agent));
    final customersAsync = ref.watch(partiesProvider(FxPartyType.customer));

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: const Text('Remittance Reports'),
        backgroundColor: context.fx.background,
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          onTap: (i) {
            if (i == 0) _loadCashFlow();
            if (i == 1) _loadBranch();
          },
          tabs: const [
            Tab(text: 'Cash Flow'),
            Tab(text: 'Branch'),
            Tab(text: 'Agent'),
            Tab(text: 'Customer'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _cashFlowTab(context),
                _kvPanel(context, _branchStmt),
                Column(
                  children: [
                    agentsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (parties) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Agent',
                          ),
                          items: parties
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => _agentId = v);
                            _loadAgent();
                          },
                        ),
                      ),
                    ),
                    Expanded(child: _kvPanel(context, _agentStmt)),
                  ],
                ),
                Column(
                  children: [
                    customersAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (parties) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Customer / sender',
                          ),
                          items: parties
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => _customerId = v);
                            _loadCustomer();
                          },
                        ),
                      ),
                    ),
                    Expanded(child: _kvPanel(context, _customerStmt)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _cashFlowTab(BuildContext context) {
    final d = _cashFlow ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _stat(
          context,
          'Today customer received',
          _fmt.format((d['today_customer_received'] as num?) ?? 0),
        ),
        _stat(
          context,
          'Today agent payouts',
          _fmt.format((d['today_agent_payouts'] as num?) ?? 0),
        ),
        _stat(
          context,
          'Today commission',
          _fmt.format((d['today_commission'] as num?) ?? 0),
        ),
        _stat(
          context,
          'Pending payout liability',
          _fmt.format((d['pending_payout_liability'] as num?) ?? 0),
        ),
        _stat(
          context,
          'Pending agent settlement',
          _fmt.format((d['pending_agent_settlement'] as num?) ?? 0),
        ),
        _stat(context, 'Open remittances', '${d['open_count'] ?? 0}'),
      ],
    );
  }

  Widget _kvPanel(BuildContext context, Map<String, dynamic>? data) {
    if (data == null) {
      return Center(
        child: Text(
          'Select filters to load report',
          style: AppTypography.bodyMd(
            context.fx.onSurfaceVariant,
            context: context,
          ),
        ),
      );
    }
    final entries = data.entries
        .where((e) => e.value is! List && e.value is! Map)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: entries
          .map((e) => _stat(context, e.key, '${e.value}'))
          .toList(),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FxObsidianReportPanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
            ),
            Text(
              value,
              style: AppTypography.headlineSm(
                context.fx.onSurface,
                context: context,
              ).copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
