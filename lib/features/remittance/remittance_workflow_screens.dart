import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/premium/fx_bottom_action_bar.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RemittanceAssignAgentScreen extends ConsumerStatefulWidget {
  const RemittanceAssignAgentScreen({super.key, required this.remittanceId});

  final String remittanceId;

  @override
  ConsumerState<RemittanceAssignAgentScreen> createState() =>
      _RemittanceAssignAgentScreenState();
}

class _RemittanceAssignAgentScreenState
    extends ConsumerState<RemittanceAssignAgentScreen> {
  String? _agentId;
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_agentId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select payout agent')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(remittanceRepositoryProvider)
          .sendToAgent(
            remittanceId: widget.remittanceId,
            agentPartyId: _agentId!,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      ref.read(remittancesRefreshProvider.notifier).refresh();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(partiesProvider(FxPartyType.agent));
    return FxPremiumScaffold(
      title: const Text('Send to Agent'),
      fallbackRoute: '/remittance',
      bottomBar: FxBottomActionBar(
        primaryLabel: 'Send',
        onPrimary: _saving ? null : _save,
        secondaryLabel: 'Cancel',
        onSecondary: () => context.pop(),
        isLoading: _saving,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            agentsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (parties) => DropdownButtonFormField<String>(
                initialValue: _agentId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Payout agent',
                ),
                items: parties
                    .map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _agentId = v),
              ),
            ),
            FxObsidianFormField(
              controller: _notes,
              label: 'Notes',
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class RemittanceConfirmPayoutScreen extends ConsumerStatefulWidget {
  const RemittanceConfirmPayoutScreen({super.key, required this.remittanceId});

  final String remittanceId;

  @override
  ConsumerState<RemittanceConfirmPayoutScreen> createState() =>
      _RemittanceConfirmPayoutScreenState();
}

class _RemittanceConfirmPayoutScreenState
    extends ConsumerState<RemittanceConfirmPayoutScreen> {
  final _proof = TextEditingController();
  final _notes = TextEditingController();
  String _method = 'cash';
  bool _saving = false;

  @override
  void dispose() {
    _proof.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(remittanceRepositoryProvider)
          .confirmPayout(
            remittanceId: widget.remittanceId,
            proofReference: _proof.text.trim().isEmpty
                ? null
                : _proof.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            payoutMethod: _method,
          );
      ref.read(remittancesRefreshProvider.notifier).refresh();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FxPremiumScaffold(
      title: const Text('Confirm Payout'),
      fallbackRoute: '/remittance',
      bottomBar: FxBottomActionBar(
        primaryLabel: 'Confirm',
        onPrimary: _saving ? null : _save,
        secondaryLabel: 'Cancel',
        onSecondary: () => context.pop(),
        isLoading: _saving,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Payout method',
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
                DropdownMenuItem(value: 'mobile', child: Text('Mobile wallet')),
              ],
              onChanged: (v) => setState(() => _method = v ?? 'cash'),
            ),
            FxObsidianFormField(controller: _proof, label: 'Proof / reference'),
            FxObsidianFormField(
              controller: _notes,
              label: 'Notes',
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class RemittanceAgentSettlementScreen extends ConsumerStatefulWidget {
  const RemittanceAgentSettlementScreen({
    super.key,
    required this.remittanceId,
  });

  final String remittanceId;

  @override
  ConsumerState<RemittanceAgentSettlementScreen> createState() =>
      _RemittanceAgentSettlementScreenState();
}

class _RemittanceAgentSettlementScreenState
    extends ConsumerState<RemittanceAgentSettlementScreen> {
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text);
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter valid amount')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(remittanceRepositoryProvider)
          .settleAgent(
            remittanceId: widget.remittanceId,
            amount: amt,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      ref.read(remittancesRefreshProvider.notifier).refresh();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FxPremiumScaffold(
      title: const Text('Agent Settlement'),
      fallbackRoute: '/remittance',
      bottomBar: FxBottomActionBar(
        primaryLabel: 'Settle',
        onPrimary: _saving ? null : _save,
        secondaryLabel: 'Cancel',
        onSecondary: () => context.pop(),
        isLoading: _saving,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FxObsidianFormField(
              controller: _amount,
              label: 'Settlement amount (PKR)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            FxObsidianFormField(
              controller: _notes,
              label: 'Notes',
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
