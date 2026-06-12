import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
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
import 'package:accounts_manager/domain/services/deal_leg_permissions.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/deals/widgets/deal_workflow_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Screen 3 — Agent source leg (Agent C provides RMB, wants AED).
class AgentSourceLegScreen extends ConsumerStatefulWidget {
  const AgentSourceLegScreen({super.key, required this.dealId, this.legId});

  final String dealId;
  final String? legId;

  @override
  ConsumerState<AgentSourceLegScreen> createState() =>
      _AgentSourceLegScreenState();
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
  bool _loadingLeg = false;
  final _proofPickerKey = GlobalKey<FxPendingProofPickerState>();

  bool get _isEdit => widget.legId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadingLeg = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLegForEdit());
    }
  }

  @override
  void dispose() {
    _receiveAmountCtrl.dispose();
    _payAmountCtrl.dispose();
    _rateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? get _receiveAmount => double.tryParse(_receiveAmountCtrl.text);

  Future<void> _loadLegForEdit() async {
    try {
      final leg = await ref
          .read(dealRepositoryProvider)
          .fetchLeg(widget.legId!);
      if (!mounted || leg == null) return;
      setState(() {
        _agentId = leg.counterpartyPartyId;
        _receiveCurrency = leg.receiveCurrency;
        _payCurrency = leg.payCurrency ?? 'AED';
        _deliveryTarget = leg.deliveryTarget ?? FxDeliveryTarget.ourAccount;
        _receiveAmountCtrl.text = leg.receiveAmount > 0
            ? leg.receiveAmount.toString()
            : '';
        _payAmountCtrl.text = leg.payAmount > 0 ? leg.payAmount.toString() : '';
        if (leg.rateUsed != null) _rateCtrl.text = leg.rateUsed.toString();
        _notesCtrl.text = leg.notes ?? '';
        _loadingLeg = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingLeg = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _maybeWarnDuplicate() {
    if (_isEdit) return;
    final legs = ref
        .read(dealTimelineProvider(widget.dealId))
        .whenOrNull(data: (v) => v);
    if (legs == null) return;
    if (DealLegPermissions.hasPendingLegOfType(
      legs,
      FxDealLegType.agentSource,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pending Agent Source already exists — edit it from the timeline or add another intentionally.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(partiesProvider(FxPartyType.agent));
    final dealAsync = ref.watch(dealDetailProvider(widget.dealId));
    final payCurrency = _payCurrency ?? 'AED';
    final receiveCurrency = _receiveCurrency;

    if (!_isEdit) {
      dealAsync.whenData((deal) {
        if (deal != null && _receiveCurrency == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _receiveCurrency == null) {
              setState(() {
                _receiveCurrency = deal.sellCurrencyCode;
                _receiveAmountCtrl.text = deal.sellAmount.toString();
              });
              _maybeWarnDuplicate();
            }
          });
        }
      });
    }

    if (_loadingLeg) {
      return FxPageScaffold(
        fallbackRoute: '/deals/${widget.dealId}',
        title: Text(_isEdit ? 'Edit Agent Source' : 'Agent Source Leg'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return FxPageScaffold(
      fallbackRoute: '/deals/${widget.dealId}',
      title: Text(_isEdit ? 'Edit Agent Source' : 'Agent Source Leg'),
      bottomBar: FxObsidianActionBar(
        onCancel: () =>
            fxSafePop(context, fallbackRoute: '/deals/${widget.dealId}'),
        onSave: _busy ? null : _confirmAndSubmit,
        saveLabel: _isEdit ? 'Save changes' : 'Save leg',
        busy: _busy,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FxSectionLabel(label: 'Agent'),
            agentsAsync.when(
              loading: () => const LinearProgressIndicator(),
              data: (agents) => DropdownButtonFormField<String>(
                initialValue: _agentId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: agents
                    .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _agentId = v),
                validator: (v) => v == null ? 'Select agent' : null,
              ),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 16),
            const FxSectionLabel(label: 'Receive from agent'),
            FxObsidianFormField(
              controller: _receiveAmountCtrl,
              label: 'Receive amount',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            DropdownButtonFormField<String>(
              initialValue: receiveCurrency,
              decoration: const InputDecoration(
                labelText: 'Receive currency',
                border: OutlineInputBorder(),
              ),
              items: [
                'CNY',
                'USD',
                'AED',
                'SAR',
              ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _receiveCurrency = v),
            ),
            const SizedBox(height: 16),
            const FxSectionLabel(label: 'Pay to agent'),
            DropdownButtonFormField<String>(
              initialValue: payCurrency,
              decoration: const InputDecoration(
                labelText: 'Pay currency',
                border: OutlineInputBorder(),
              ),
              items: [
                'PKR',
                'AED',
                'USD',
                'CNY',
              ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _payCurrency = v),
            ),
            FxObsidianFormField(
              controller: _payAmountCtrl,
              label: 'Pay amount',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
                dealRateLabel:
                    receiveCurrency == payCurrency || payCurrency == 'PKR'
                    ? 'Rate (PKR per $receiveCurrency unit)'
                    : 'Deal rate ($receiveCurrency per $payCurrency unit)',
                onDealRateChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),
            const FxSectionLabel(label: 'Delivery to'),
            DropdownButtonFormField<FxDeliveryTarget>(
              initialValue: _deliveryTarget,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: FxDeliveryTarget.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => setState(
                () => _deliveryTarget = v ?? FxDeliveryTarget.ourAccount,
              ),
            ),
            FxObsidianFormField(
              controller: _notesCtrl,
              label: 'Notes / reference no.',
              maxLines: 2,
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 12),
              FxPendingProofPicker(key: _proofPickerKey),
            ],
            const SizedBox(height: 16),
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
        title: Text(_isEdit ? 'Confirm changes' : 'Confirm agent source leg'),
        content: Text(
          'Receive ${fmt.format(receive)} $receiveCurrency from agent\n'
          'Pay ${fmt.format(pay)} $payCurrency\n'
          'Delivery: ${_deliveryTarget.label}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final rates = await ref
          .read(rateRepositoryProvider)
          .fetchRatesAsOf(DateTime.now());
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
      final notes = _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim();
      final receiveAmount = double.parse(_receiveAmountCtrl.text);
      final payAmount = double.tryParse(_payAmountCtrl.text) ?? 0;
      final rateUsed = double.tryParse(_rateCtrl.text);

      if (_isEdit) {
        await ref
            .read(dealRepositoryProvider)
            .updateLeg(
              legId: widget.legId!,
              counterpartyPartyId: _agentId,
              receiveCurrency: _receiveCurrency,
              receiveAmount: receiveAmount,
              payCurrency: _payCurrency ?? 'AED',
              payAmount: payAmount,
              rateUsed: rateUsed,
              deliveryTarget: _deliveryTarget,
              notes: notes,
              rateSnapshot: rateSnapshot,
            );
      } else {
        final legId = await ref
            .read(dealRepositoryProvider)
            .addLeg(
              dealId: widget.dealId,
              legType: FxDealLegType.agentSource,
              counterpartyPartyId: _agentId,
              receiveCurrency: _receiveCurrency,
              receiveAmount: receiveAmount,
              payCurrency: _payCurrency ?? 'AED',
              payAmount: payAmount,
              rateUsed: rateUsed,
              deliveryTarget: _deliveryTarget,
              notes: notes,
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
      }
      ref.read(dealsRefreshProvider.notifier).refresh();
      if (mounted) context.go('/deals/${widget.dealId}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
