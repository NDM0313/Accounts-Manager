import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/core/utils/pending_proof_upload.dart';
import 'package:accounts_manager/features/deals/widgets/deal_workflow_panel.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Agent payment or currency receipt leg (simple settlement append).
class DealSettlementLegScreen extends ConsumerStatefulWidget {
  const DealSettlementLegScreen({
    super.key,
    required this.dealId,
    required this.legType,
  });

  final String dealId;
  final FxDealLegType legType;

  @override
  ConsumerState<DealSettlementLegScreen> createState() => _DealSettlementLegScreenState();
}

class _DealSettlementLegScreenState extends ConsumerState<DealSettlementLegScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _partyId;
  String _currency = 'PKR';
  bool _busy = false;
  final _proofPickerKey = GlobalKey<FxPendingProofPickerState>();

  bool get _isReceipt => widget.legType == FxDealLegType.currencyReceipt;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(partiesProvider(FxPartyType.agent));
    final title = widget.legType.label;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FxSectionLabel(label: 'Counterparty'),
            agentsAsync.when(
              loading: () => const LinearProgressIndicator(),
              data: (agents) => DropdownButtonFormField<String>(
                value: _partyId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: agents.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                onChanged: (v) => setState(() => _partyId = v),
                validator: (v) => v == null ? 'Select agent' : null,
              ),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: InputDecoration(
                labelText: _isReceipt ? 'Receive currency' : 'Pay currency',
                border: const OutlineInputBorder(),
              ),
              items: ['PKR', 'AED', 'USD', 'CNY']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _currency = v ?? 'PKR'),
            ),
            FxObsidianFormField(
              controller: _amountCtrl,
              label: _isReceipt ? 'Receive amount' : 'Pay amount',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => double.tryParse(v ?? '') == null ? 'Enter amount' : null,
            ),
            FxObsidianFormField(controller: _notesCtrl, label: 'Notes / reference no.', maxLines: 2),
            const SizedBox(height: 12),
            FxPendingProofPicker(key: _proofPickerKey),
            const SizedBox(height: 24),
            FxObsidianActionBar(
              onCancel: () => context.pop(),
              onSave: _busy ? null : _submit,
              saveLabel: 'Save leg',
              busy: _busy,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _partyId == null) return;
    final amount = double.parse(_amountCtrl.text);
    setState(() => _busy = true);
    try {
      final legId = await ref.read(dealRepositoryProvider).addLeg(
            dealId: widget.dealId,
            legType: widget.legType,
            counterpartyPartyId: _partyId,
            receiveCurrency: _isReceipt ? _currency : null,
            receiveAmount: _isReceipt ? amount : 0,
            payCurrency: _isReceipt ? null : _currency,
            payAmount: _isReceipt ? 0 : amount,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      final profile = await ref.read(currentProfileProvider.future);
      if (profile != null) {
        await uploadPendingProofsForLeg(
          ref: ref,
          branchId: profile.branchId,
          dealId: widget.dealId,
          legId: legId,
          files: _proofPickerKey.currentState?.files ?? [],
          attachmentType: 'payment_proof',
        );
      }
      ref.read(dealsRefreshProvider.notifier).refresh();
      if (mounted) context.go('/deals/${widget.dealId}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
