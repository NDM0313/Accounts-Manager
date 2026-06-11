import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/core/utils/pending_proof_upload.dart';
import 'package:accounts_manager/domain/services/deal_leg_permissions.dart';
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
    this.legId,
  });

  final String dealId;
  final FxDealLegType legType;
  final String? legId;

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
  bool _loadingLeg = false;
  final _proofPickerKey = GlobalKey<FxPendingProofPickerState>();

  bool get _isReceipt => widget.legType == FxDealLegType.currencyReceipt;
  bool get _isEdit => widget.legId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadingLeg = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLegForEdit());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWarnDuplicate());
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLegForEdit() async {
    try {
      final leg = await ref.read(dealRepositoryProvider).fetchLeg(widget.legId!);
      if (!mounted || leg == null) return;
      setState(() {
        _partyId = leg.counterpartyPartyId;
        _currency = _isReceipt ? (leg.receiveCurrency ?? 'USD') : (leg.payCurrency ?? 'PKR');
        final amount = _isReceipt ? leg.receiveAmount : leg.payAmount;
        _amountCtrl.text = amount > 0 ? amount.toString() : '';
        _notesCtrl.text = leg.notes ?? '';
        _loadingLeg = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingLeg = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _maybeWarnDuplicate() {
    final legs = ref.read(dealTimelineProvider(widget.dealId)).whenOrNull(data: (v) => v);
    if (legs == null) return;
    if (DealLegPermissions.hasPendingLegOfType(legs, widget.legType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pending ${widget.legType.label} already exists — edit it from the timeline or add another intentionally.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(partiesProvider(FxPartyType.agent));
    final title = _isEdit ? 'Edit ${widget.legType.label}' : widget.legType.label;

    if (_loadingLeg) {
      return FxPageScaffold(
        fallbackRoute: '/deals/${widget.dealId}',
        title: Text(title),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return FxPageScaffold(
      fallbackRoute: '/deals/${widget.dealId}',
      title: Text(title),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FxSectionLabel(label: 'Counterparty'),
            agentsAsync.when(
              loading: () => const LinearProgressIndicator(),
              data: (agents) => DropdownButtonFormField<String>(
                initialValue: _partyId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: agents.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                onChanged: (v) => setState(() => _partyId = v),
                validator: (v) => v == null ? 'Select agent' : null,
              ),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _currency,
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
            if (!_isEdit) ...[
              const SizedBox(height: 12),
              FxPendingProofPicker(key: _proofPickerKey),
            ],
            const SizedBox(height: 24),
            FxObsidianActionBar(
              onCancel: () => fxSafePop(context, fallbackRoute: '/deals/${widget.dealId}'),
              onSave: _busy ? null : _submit,
              saveLabel: _isEdit ? 'Save changes' : 'Save leg',
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
      final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
      if (_isEdit) {
        await ref.read(dealRepositoryProvider).updateLeg(
              legId: widget.legId!,
              counterpartyPartyId: _partyId,
              receiveCurrency: _isReceipt ? _currency : null,
              receiveAmount: _isReceipt ? amount : 0,
              payCurrency: _isReceipt ? null : _currency,
              payAmount: _isReceipt ? 0 : amount,
              notes: notes,
            );
      } else {
        final legId = await ref.read(dealRepositoryProvider).addLeg(
              dealId: widget.dealId,
              legType: widget.legType,
              counterpartyPartyId: _partyId,
              receiveCurrency: _isReceipt ? _currency : null,
              receiveAmount: _isReceipt ? amount : 0,
              payCurrency: _isReceipt ? null : _currency,
              payAmount: _isReceipt ? 0 : amount,
              notes: notes,
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
