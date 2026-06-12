import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/rates/fx_rate_valuation_section.dart';
import 'package:accounts_manager/features/deals/widgets/deal_workflow_panel.dart';
import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/domain/models/rate_reference_snapshot.dart';
import 'package:accounts_manager/core/utils/pending_proof_upload.dart';
import 'package:accounts_manager/domain/services/deal_leg_permissions.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_agent_source_form.dart';
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
  void dispose() {
    _receiveAmountCtrl.dispose();
    _payAmountCtrl.dispose();
    _rateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? get _receiveAmount => double.tryParse(_receiveAmountCtrl.text);
  double? get _rate => double.tryParse(_rateCtrl.text);
  double? _referenceRate;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadingLeg = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLegForEdit());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReferenceRate());
  }

  Future<void> _loadReferenceRate() async {
    final rc = _receiveCurrency;
    final pc = _payCurrency ?? 'AED';
    if (rc == null) return;
    try {
      final rates = await ref.read(rateRepositoryProvider).fetchRatesAsOf(DateTime.now());
      final svc = ref.read(rateSuggestionServiceProvider);
      final quote = rc == pc || pc == 'PKR'
          ? svc.pkrQuote(rates, rc)
          : svc.resolvePair(rates, rc, pc);
      if (mounted) setState(() => _referenceRate = quote.rate);
    } catch (_) {}
  }

  String? get _spreadLabel {
    if (_referenceRate == null || _rate == null || _referenceRate == 0) {
      return null;
    }
    final spread = ((_rate! - _referenceRate!) / _referenceRate! * 100);
    return '${spread >= 0 ? '+' : ''}${spread.toStringAsFixed(2)}% SPREAD';
  }

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

    final profileAsync = ref.watch(currentProfileProvider);
    final fmt = NumberFormat('#,##0.00');
    final pkrEq = (_receiveAmount ?? 0) * (_rate ?? 0);

    if (_loadingLeg) {
      return Scaffold(
        backgroundColor: context.fx.background,
        appBar: AppBar(
          backgroundColor: context.fx.background,
          title: const Text('Agent Sourcing'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: const Text('Agent Sourcing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dealTimelineProvider(widget.dealId));
              _loadReferenceRate();
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: context.fx.secondaryContainer,
              child: Text(
                () {
                  final name = profileAsync.value?.fullName ?? '';
                  return name.isNotEmpty ? name[0].toUpperCase() : 'JD';
                }(),
                style: TextStyle(
                  color: context.fx.onSecondaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            agentsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (agents) => FxStitchAgentSourceForm(
                agents: agents,
                agentId: _agentId,
                onAgentChanged: (v) => setState(() => _agentId = v),
                receiveAmountCtrl: _receiveAmountCtrl,
                payAmountCtrl: _payAmountCtrl,
                receiveCurrency: receiveCurrency,
                payCurrency: payCurrency,
                onReceiveCurrencyChanged: (v) {
                  setState(() => _receiveCurrency = v);
                  _loadReferenceRate();
                },
                onPayCurrencyChanged: (v) {
                  setState(() => _payCurrency = v);
                  _loadReferenceRate();
                },
                dealRateLabel: _rate?.toStringAsFixed(4) ?? '—',
                referenceRateLabel:
                    _referenceRate?.toStringAsFixed(4) ?? '—',
                spreadLabel: _spreadLabel,
                pkrEquivalentLabel: fmt.format(pkrEq),
                pkrCaption: receiveCurrency != null
                    ? 'Est. Val: 1 $receiveCurrency = ${_rate?.toStringAsFixed(2) ?? '—'} PKR'
                    : '',
                deliveryTarget: _deliveryTarget,
                onDeliveryChanged: (v) => setState(() => _deliveryTarget = v),
                notesCtrl: _notesCtrl,
                rateField: receiveCurrency != null
                    ? FxRateValuationSection(
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
                      )
                    : null,
                proofSection: !_isEdit
                    ? FxPendingProofPicker(key: _proofPickerKey)
                    : null,
                onSwap: () {
                  final rc = _receiveCurrency;
                  final pc = _payCurrency;
                  final ra = _receiveAmountCtrl.text;
                  final pa = _payAmountCtrl.text;
                  setState(() {
                    _receiveCurrency = pc;
                    _payCurrency = rc ?? 'AED';
                    _receiveAmountCtrl.text = pa;
                    _payAmountCtrl.text = ra;
                  });
                  _loadReferenceRate();
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _confirmAndSubmit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.fx.secondary,
                      side: BorderSide(color: context.fx.secondary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_isEdit ? 'Save changes' : 'Save Leg'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _confirmAndSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.fx.secondary,
                      foregroundColor: context.fx.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Confirm Received'),
                  ),
                ),
              ],
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
