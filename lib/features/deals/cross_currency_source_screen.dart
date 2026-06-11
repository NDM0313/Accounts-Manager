import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/core/widgets/rates/fx_rate_valuation_section.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/core/utils/pending_proof_upload.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/deals/widgets/deal_workflow_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen 4 — AED sourcing via third party (Agent D pays PKR, delivers AED to Agent C).
class CrossCurrencySourceScreen extends ConsumerStatefulWidget {
  const CrossCurrencySourceScreen({super.key, required this.dealId});

  final String dealId;

  @override
  ConsumerState<CrossCurrencySourceScreen> createState() => _CrossCurrencySourceScreenState();
}

class _CrossCurrencySourceScreenState extends ConsumerState<CrossCurrencySourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pkrAmountCtrl = TextEditingController();
  final _aedAmountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _proofCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _agentDId;
  String? _targetAgentLegId;
  bool _busy = false;
  final _proofPickerKey = GlobalKey<FxPendingProofPickerState>();

  @override
  void dispose() {
    _pkrAmountCtrl.dispose();
    _aedAmountCtrl.dispose();
    _rateCtrl.dispose();
    _proofCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(partiesProvider(FxPartyType.agent));
    final timelineAsync = ref.watch(dealTimelineProvider(widget.dealId));
    final agentLegs = timelineAsync.whenOrNull(
          data: (legs) => legs.where((l) => l.legType == FxDealLegType.agentSource).toList(),
        ) ??
        [];

    return FxPageScaffold(
      fallbackRoute: '/deals/${widget.dealId}',
      title: const Text('Cross-Currency Source'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FxSectionLabel(label:'Agent D (AED provider)'),
            agentsAsync.when(
              loading: () => const LinearProgressIndicator(),
              data: (agents) => DropdownButtonFormField<String>(
                initialValue: _agentDId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: agents.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                onChanged: (v) => setState(() => _agentDId = v),
                validator: (v) => v == null ? 'Select agent' : null,
              ),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 16),
            const FxSectionLabel(label:'Settlement'),
            FxObsidianFormField(
              controller: _pkrAmountCtrl,
              label: 'Pay amount (PKR)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => double.tryParse(v ?? '') == null ? 'Enter PKR amount' : null,
            ),
            FxObsidianFormField(
              controller: _aedAmountCtrl,
              label: 'AED amount arranged',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => double.tryParse(v ?? '') == null ? 'Enter AED amount' : null,
              onChanged: (_) => setState(() {}),
            ),
            FxRateValuationSection(
              fromCurrency: 'AED',
              toCurrency: 'PKR',
              dealRateController: _rateCtrl,
              receiveAmount: double.tryParse(_aedAmountCtrl.text),
              payAmountController: _pkrAmountCtrl,
              rateSide: RateSide.reference,
              asOfDate: DateTime.now(),
              dealRateLabel: 'Implied AED/PKR deal rate',
              onDealRateChanged: (_) => setState(() {}),
            ),
            if (agentLegs.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _targetAgentLegId ?? agentLegs.first.id,
                decoration: const InputDecoration(labelText: 'AED delivered to (Agent C leg)', border: OutlineInputBorder()),
                items: agentLegs
                    .map((l) => DropdownMenuItem(
                          value: l.id,
                          child: Text('Leg ${l.legNo}: ${l.counterpartyName ?? 'Agent'}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _targetAgentLegId = v),
              ),
            ],
            FxObsidianFormField(controller: _proofCtrl, label: 'Reference / proof'),
            FxObsidianFormField(controller: _notesCtrl, label: 'Notes', maxLines: 2),
            const SizedBox(height: 12),
            FxPendingProofPicker(key: _proofPickerKey),
            const SizedBox(height: 24),
            FxObsidianActionBar(
              onCancel: () => fxSafePop(context, fallbackRoute: '/deals/${widget.dealId}'),
              onSave: _busy ? null : () => _submit(agentLegs),
              saveLabel: 'Save & link settlement',
              busy: _busy,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(List<FxDealLeg> agentLegs) async {
    if (!_formKey.currentState!.validate() || _agentDId == null) return;
    final targetLegId = _targetAgentLegId ?? agentLegs.firstOrNull?.id;
    if (targetLegId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add an agent source leg first')));
      return;
    }
    setState(() => _busy = true);
    try {
      final fromLegId = await ref.read(dealRepositoryProvider).addLeg(
            dealId: widget.dealId,
            legType: FxDealLegType.crossCurrencySource,
            counterpartyPartyId: _agentDId,
            receiveCurrency: 'AED',
            receiveAmount: double.parse(_aedAmountCtrl.text),
            payCurrency: 'PKR',
            payAmount: double.parse(_pkrAmountCtrl.text),
            parentLegId: targetLegId,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      await ref.read(dealRepositoryProvider).addSettlementLink(
            dealId: widget.dealId,
            fromLegId: fromLegId,
            toLegId: targetLegId,
            linkType: 'aed_to_agent',
            currencyCode: 'AED',
            amount: double.parse(_aedAmountCtrl.text),
            proofReference: _proofCtrl.text.trim().isEmpty ? null : _proofCtrl.text.trim(),
          );
      final profile = await ref.read(currentProfileProvider.future);
      if (profile != null) {
        await uploadPendingProofsForLeg(
          ref: ref,
          branchId: profile.branchId,
          dealId: widget.dealId,
          legId: fromLegId,
          files: _proofPickerKey.currentState?.files ?? [],
          attachmentType: 'tt_proof',
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

extension _LegFirstOrNull on Iterable<FxDealLeg> {
  FxDealLeg? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
