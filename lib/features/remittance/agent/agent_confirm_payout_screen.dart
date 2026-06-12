import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:accounts_manager/features/remittance/widgets/remittance_attachments_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AgentConfirmPayoutScreen extends ConsumerStatefulWidget {
  const AgentConfirmPayoutScreen({super.key, required this.remittanceId});

  final String remittanceId;

  @override
  ConsumerState<AgentConfirmPayoutScreen> createState() =>
      _AgentConfirmPayoutScreenState();
}

class _AgentConfirmPayoutScreenState
    extends ConsumerState<AgentConfirmPayoutScreen> {
  final _proof = TextEditingController();
  final _notes = TextEditingController();
  String _method = 'cash';
  DateTime _payoutAt = DateTime.now();
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
          .agentConfirmPayout(
            remittanceId: widget.remittanceId,
            payoutMethod: _method,
            payoutAt: _payoutAt,
            proofReference: _proof.text.trim().isEmpty
                ? null
                : _proof.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      ref.read(remittancesRefreshProvider.notifier).refresh();
      if (mounted) context.go('/remittance/agent/${widget.remittanceId}');
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
    final profile = ref.watch(currentProfileProvider).value;
    return FxPageScaffold(
      title: const Text('Confirm Payout'),
      fallbackRoute: '/remittance/agent',
      bottomBar: FxObsidianActionBar(
        onCancel: () => context.pop(),
        onSave: _saving ? null : _save,
        saveLabel: 'Confirm',
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
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
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Payout date/time'),
              subtitle: Text(_payoutAt.toLocal().toString()),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  initialDate: _payoutAt,
                );
                if (date == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_payoutAt),
                );
                if (time == null) return;
                setState(
                  () => _payoutAt = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  ),
                );
              },
            ),
            FxObsidianFormField(controller: _proof, label: 'Proof / reference'),
            FxObsidianFormField(controller: _notes, label: 'Note', maxLines: 2),
            if (profile != null) ...[
              const SizedBox(height: 16),
              RemittanceAttachmentsSection(
                remittanceId: widget.remittanceId,
                branchId: profile.branchId,
                attachmentType: 'payout_proof',
                title: 'Receiver proof / ID',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
