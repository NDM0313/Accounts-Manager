import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/core/widgets/rates/fx_rate_valuation_section.dart';
import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/domain/models/rate_reference_snapshot.dart';
import 'package:accounts_manager/core/utils/pending_proof_upload.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/deals/widgets/deal_workflow_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Screen 3 — Agent source leg (Agent C provides RMB, wants AED).
class AgentSourceLegScreen extends ConsumerStatefulWidget {
  const AgentSourceLegScreen({super.key, required this.dealId});

  final String dealId;

  @override
  ConsumerState<AgentSourceLegScreen> createState() => _AgentSourceLegScreenState();
}

class _AgentSourceLegScreenState extends ConsumerState<AgentSourceLegScreen> {
  final _formKey = GlobalKey<FormState>();
  final _receiveAmountCtrl = TextEditingController();
  final _payAmountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _agentId;
  String? _receiveCurrency;
  String? _payCurrency;
  FxDeliveryTarget _deliveryTarget = FxDeliveryTarget.ourAccount;
  bool _busy = false;
  final _proofPickerKey = GlobalKey<FxPendingProofPickerState>();

  @override
  void dispose() {
    _receiveAmountCtrl.dispose();
    _payAmountCtrl.dispose();
    _rateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? get _receiveAmount => double.tryParse(_receiveAmountCtrl.text);

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(partiesProvider(FxPartyType.agent));
    final dealAsync = ref.watch(dealDetailProvider(widget.dealId));
    final payCurrency = _payCurrency ?? 'AED';
    final receiveCurrency = _receiveCurrency;

    dealAsync.whenData((deal) {
      if (deal != null && _receiveCurrency == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _receiveCurrency == null) {
            setState(() {
              _receiveCurrency = deal.sellCurrencyCode;
              _receiveAmountCtrl.text = deal.sellAmount.toString();
            });
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Agent Source Leg')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FxSectionLabel(label:'Agent'),
            agentsAsync.when(
              loading: () => const LinearProgressIndicator(),
              data: (agents) => DropdownButtonFormField<String>(
                value: _agentId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: agents.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                onChanged: (v) => setState(() => _agentId = v),
                validator: (v) => v == null ? 'Select agent' : null,
              ),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 16),
            const FxSectionLabel(label:'Receive from agent'),
            FxObsidianFormField(
              controller: _receiveAmountCtrl,
              label: 'Receive amount',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            DropdownButtonFormField<String>(
              value: receiveCurrency,
              decoration: const InputDecoration(labelText: 'Receive currency', border: OutlineInputBorder()),
              items: ['CNY', 'USD', 'AED', 'SAR'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _receiveCurrency = v),
            ),
            const SizedBox(height: 16),
            const FxSectionLabel(label:'Pay to agent'),
            DropdownButtonFormField<String>(
              value: payCurrency,
              decoration: const InputDecoration(labelText: 'Pay currency', border: OutlineInputBorder()),
              items: ['PKR', 'AED', 'USD', 'CNY'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _payCurrency = v),
            ),
            FxObsidianFormField(
              controller: _payAmountCtrl,
              label: 'Pay amount',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            if (receiveCurrency != null) ...[
              const SizedBox(height: 8),
              FxRateValuationSection(
                fromCurrency: receiveCurrency,
                toCurrency: payCurrency,
                dealRateController: _rateCtrl,
                receiveAmount: _receiveAmount,
                payAmountController: _payAmountCtrl,
                rateSide: RateSide.reference,
                asOfDate: DateTime.now(),
                dealRateLabel: receiveCurrency == payCurrency || payCurrency == 'PKR'
                    ? 'Rate (PKR per $receiveCurrency unit)'
                    : 'Deal rate ($receiveCurrency per $payCurrency unit)',
                onDealRateChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),
            const FxSectionLabel(label:'Delivery to'),
            DropdownButtonFormField<FxDeliveryTarget>(
              value: _deliveryTarget,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: FxDeliveryTarget.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
              onChanged: (v) => setState(() => _deliveryTarget = v ?? FxDeliveryTarget.ourAccount),
            ),
            FxObsidianFormField(controller: _notesCtrl, label: 'Notes / reference no.', maxLines: 2),
            const SizedBox(height: 12),
            FxPendingProofPicker(key: _proofPickerKey),
            const SizedBox(height: 24),
            FxObsidianActionBar(
              onCancel: () => context.pop(),
              onSave: _busy ? null : _confirmAndSubmit,
              saveLabel: 'Save leg',
              busy: _busy,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndSubmit() async {
    if (!_formKey.currentState!.validate() || _agentId == null) return;
    final fmt = NumberFormat('#,##0.00');
    final receive = double.parse(_receiveAmountCtrl.text);
    final pay = double.tryParse(_payAmountCtrl.text) ?? 0;
    final payCurrency = _payCurrency ?? 'AED';
    final receiveCurrency = _receiveCurrency!;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm agent source leg'),
        content: Text(
          'Receive ${fmt.format(receive)} $receiveCurrency from agent\n'
          'Pay ${fmt.format(pay)} $payCurrency\n'
          'Delivery: ${_deliveryTarget.label}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final rates = await ref.read(rateRepositoryProvider).fetchRatesAsOf(DateTime.now());
      final svc = ref.read(rateSuggestionServiceProvider);
      final rateSnapshot = RateReferenceSnapshot.capture(
        svc: svc,
        rates: rates,
        fromCurrency: _receiveCurrency!,
        toCurrency: _payCurrency ?? 'AED',
        dealRate: double.tryParse(_rateCtrl.text),
        side: RateSide.reference,
        lockedBy: supabase.auth.currentUser?.id,
      );
      final legId = await ref.read(dealRepositoryProvider).addLeg(
            dealId: widget.dealId,
            legType: FxDealLegType.agentSource,
            counterpartyPartyId: _agentId,
            receiveCurrency: _receiveCurrency,
            receiveAmount: double.parse(_receiveAmountCtrl.text),
            payCurrency: _payCurrency ?? 'AED',
            payAmount: double.tryParse(_payAmountCtrl.text) ?? 0,
            rateUsed: double.tryParse(_rateCtrl.text),
            deliveryTarget: _deliveryTarget,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            rateSnapshot: rateSnapshot,
          );
      final profile = await ref.read(currentProfileProvider.future);
      if (profile != null) {
        await uploadPendingProofsForLeg(
          ref: ref,
          branchId: profile.branchId,
          dealId: widget.dealId,
          legId: legId,
          files: _proofPickerKey.currentState?.files ?? [],
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
