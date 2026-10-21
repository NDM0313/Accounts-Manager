import 'package:accounts_manager/core/utils/client_operation_id.dart';
import 'package:accounts_manager/core/utils/deal_posting_errors.dart';
import 'package:accounts_manager/core/utils/pending_proof_upload.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/services/deal_leg_permissions.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/deals/widgets/deal_workflow_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
  ConsumerState<DealSettlementLegScreen> createState() =>
      _DealSettlementLegScreenState();
}

class _DealSettlementLegScreenState
    extends ConsumerState<DealSettlementLegScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _fmt = NumberFormat('#,##0.########');

  String? _partyId;
  String? _parentSourceLegId;
  String _currency = 'PKR';
  FxDealLeg? _selectedSource;
  String? _inlineError;
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
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeWarnDuplicate(),
      );
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
      final leg = await ref
          .read(dealRepositoryProvider)
          .fetchLeg(widget.legId!);
      if (!mounted || leg == null) return;
      setState(() {
        _partyId = leg.counterpartyPartyId;
        _parentSourceLegId = leg.parentLegId;
        _currency = _isReceipt
            ? (leg.receiveCurrency ?? 'USD')
            : (leg.payCurrency ?? 'PKR');
        final amount = _isReceipt ? leg.receiveAmount : leg.payAmount;
        _amountCtrl.text = amount > 0 ? amount.toString() : '';
        _notesCtrl.text = leg.notes ?? '';
        _loadingLeg = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingLeg = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyDealPostingError(e))),
        );
      }
    }
  }

  void _maybeWarnDuplicate() {
    final legs = ref
        .read(dealTimelineProvider(widget.dealId))
        .whenOrNull(data: (v) => v);
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

  void _applySource(FxDealLeg? source) {
    if (source == null) {
      setState(() {
        _selectedSource = null;
        _parentSourceLegId = null;
        _inlineError = null;
      });
      return;
    }
    final ccy = (source.receiveCurrency ?? '').trim().toUpperCase();
    final prevCcy = _currency;
    setState(() {
      _selectedSource = source;
      _parentSourceLegId = source.id;
      _partyId = source.counterpartyPartyId;
      if (ccy.isNotEmpty) _currency = ccy;
      _inlineError = null;
      // Changing source invalidates amount if currency changed.
      if (prevCcy != _currency) {
        _amountCtrl.clear();
      }
    });
  }

  String? _validateReceiptAmount(String? raw) {
    final amount = double.tryParse((raw ?? '').replaceAll(',', ''));
    if (amount == null) return 'Enter amount';
    if (amount <= 0) return 'Amount must be greater than zero';
    final source = _selectedSource;
    if (source == null) return 'Select sourcing leg first';
    final remaining = source.remainingAmount > 0
        ? source.remainingAmount
        : (source.receiveAmount - source.paidAmount);
    if (amount > remaining + 0.0000001) {
      return 'Cannot exceed remaining ${_fmt.format(remaining)} $_currency';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(partiesProvider(FxPartyType.agent));
    final legsAsync = ref.watch(dealTimelineProvider(widget.dealId));
    final title = _isEdit
        ? 'Edit ${widget.legType.label}'
        : widget.legType.label;

    if (_loadingLeg) {
      return FxPageScaffold(
        fallbackRoute: '/deals/${widget.dealId}',
        title: Text(title),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Keep selected source object in sync after timeline refresh.
    legsAsync.whenData((legs) {
      if (_parentSourceLegId != null) {
        final match = legs.where((l) => l.id == _parentSourceLegId).toList();
        if (match.isNotEmpty &&
            (_selectedSource == null ||
                _selectedSource!.remainingAmount != match.first.remainingAmount ||
                _selectedSource!.paidAmount != match.first.paidAmount)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _selectedSource = match.first);
          });
        }
      }
    });

    return FxPageScaffold(
      fallbackRoute: '/deals/${widget.dealId}',
      title: Text(title),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isReceipt) ...[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receive Sourced Currency',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This posts a currency receipt against an agent source leg '
                        '(same currency only). It does not record customer PKR '
                        'payment, mark custody complete, or confirm delivery.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.push(
                          '/deals/${widget.dealId}',
                        ),
                        child: const Text(
                          'Need customer PKR payment? Open deal → Receive customer payment',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const FxSectionLabel(label: 'Source agent leg'),
              legsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (legs) {
                  final sources = legs
                      .where(
                        (l) =>
                            l.legType == FxDealLegType.agentSource &&
                            (l.status == FxDealLegStatus.pending ||
                                l.status == FxDealLegStatus.partial),
                      )
                      .toList();
                  // Key forces rebuild when selection changes (initialValue is one-shot).
                  return DropdownButtonFormField<String>(
                    key: ValueKey('src-$_parentSourceLegId'),
                    initialValue: _parentSourceLegId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      helperText:
                          'Receipt allocates to one agent_source leg in its currency',
                    ),
                    items: sources
                        .map(
                          (l) => DropdownMenuItem(
                            value: l.id,
                            child: Text(
                              'Leg #${l.legNo} · ${l.receiveCurrency ?? '?'} '
                              '${_fmt.format(l.receiveAmount)} · remaining '
                              '${_fmt.format(l.remainingAmount)}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _isEdit
                        ? null
                        : (id) {
                            FxDealLeg? src;
                            for (final l in sources) {
                              if (l.id == id) {
                                src = l;
                                break;
                              }
                            }
                            _applySource(src);
                          },
                    validator: (v) =>
                        v == null ? 'Select sourcing leg' : null,
                  );
                },
              ),
              if (_selectedSource != null) ...[
                const SizedBox(height: 12),
                _SourceSummaryCard(
                  source: _selectedSource!,
                  receiveCurrency: _currency,
                  receiveAmountText: _amountCtrl.text,
                  fmt: _fmt,
                ),
              ],
              const SizedBox(height: 16),
            ],
            const FxSectionLabel(label: 'Counterparty'),
            if (_isReceipt)
              InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  helperText: 'Locked to the source agent on the selected leg',
                ),
                child: agentsAsync.when(
                  loading: () => const Text('…'),
                  error: (e, _) => Text('$e'),
                  data: (agents) {
                    String? agentName;
                    for (final a in agents) {
                      if (a.id == _partyId) {
                        agentName = a.name;
                        break;
                      }
                    }
                    final name = agentName ??
                        _selectedSource?.counterpartyName ??
                        (_partyId == null ? 'Select a source leg' : _partyId!);
                    return Text(name);
                  },
                ),
              )
            else
              agentsAsync.when(
                loading: () => const LinearProgressIndicator(),
                data: (agents) => DropdownButtonFormField<String>(
                  key: ValueKey('party-$_partyId'),
                  initialValue: _partyId,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  items: agents
                      .map(
                        (a) =>
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _partyId = v),
                  validator: (v) => v == null ? 'Select agent' : null,
                ),
                error: (e, _) => Text('$e'),
              ),
            const SizedBox(height: 16),
            if (_isReceipt)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Receive currency (from source)',
                  border: OutlineInputBorder(),
                  helperText:
                      'Locked to source currency — PKR customer payment is a separate action',
                ),
                child: Text(
                  _currency,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              )
            else
              DropdownButtonFormField<String>(
                key: ValueKey('ccy-$_currency'),
                initialValue: _currency,
                decoration: const InputDecoration(
                  labelText: 'Pay currency',
                  border: OutlineInputBorder(),
                ),
                items: [
                  'PKR',
                  'AED',
                  'USD',
                  'CNY',
                ]
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _currency = v ?? 'PKR'),
              ),
            FxObsidianFormField(
              controller: _amountCtrl,
              label: _isReceipt
                  ? 'Amount receiving ($_currency)'
                  : 'Pay amount',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) {
                if (_inlineError != null) {
                  setState(() => _inlineError = null);
                }
              },
              validator: _isReceipt
                  ? _validateReceiptAmount
                  : (v) =>
                      double.tryParse(v ?? '') == null ? 'Enter amount' : null,
            ),
            FxObsidianFormField(
              controller: _notesCtrl,
              label: 'Notes / reference no.',
              maxLines: 2,
            ),
            if (_inlineError != null) ...[
              const SizedBox(height: 8),
              Text(
                _inlineError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (!_isEdit) ...[
              const SizedBox(height: 12),
              FxPendingProofPicker(key: _proofPickerKey),
            ],
            const SizedBox(height: 24),
            FxObsidianActionBar(
              onCancel: () =>
                  fxSafePop(context, fallbackRoute: '/deals/${widget.dealId}'),
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
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_isReceipt) {
      if (_parentSourceLegId == null || _selectedSource == null) {
        setState(() => _inlineError = 'Select a source agent leg first.');
        return;
      }
      if (_partyId == null) {
        setState(
          () => _inlineError =
              'Source leg has no agent counterparty — fix the source leg first.',
        );
        return;
      }
    } else if (_partyId == null) {
      return;
    }

    final amount = double.parse(_amountCtrl.text.replaceAll(',', ''));
    if (_isReceipt && !_isEdit) {
      final remaining = _selectedSource!.remainingAmount > 0
          ? _selectedSource!.remainingAmount
          : (_selectedSource!.receiveAmount - _selectedSource!.paidAmount);
      if (amount > remaining + 0.0000001) {
        setState(() {
          _inlineError =
              'Amount ${_fmt.format(amount)} $_currency exceeds remaining '
              '${_fmt.format(remaining)} $_currency on the source leg.';
        });
        return;
      }
    }

    setState(() => _busy = true);
    String? opId;
    try {
      final notes = _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim();
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
        if (_isReceipt) {
          opId = await ClientOperationId.beginAmounted(
            'currency_receipt',
            widget.dealId,
            amount,
          );
        }
        final legId = await ref.read(dealRepositoryProvider).addLeg(
              dealId: widget.dealId,
              legType: widget.legType,
              counterpartyPartyId: _partyId,
              receiveCurrency: _isReceipt ? _currency : null,
              receiveAmount: _isReceipt ? amount : 0,
              payCurrency: _isReceipt ? null : _currency,
              payAmount: _isReceipt ? 0 : amount,
              parentLegId: _isReceipt ? _parentSourceLegId : null,
              notes: notes,
              clientOperationId: opId,
            );
        if (opId != null) {
          await ClientOperationId.completeAmounted(
            'currency_receipt',
            widget.dealId,
          );
        }
        final profile = await ref.read(currentProfileProvider.future);
        if (profile != null) {
          await uploadPendingProofsForLeg(
            ref: ref,
            companyId: profile.companyId,
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
      if (mounted) {
        // Preserve notes + pending attachments; show actionable inline copy.
        setState(() => _inlineError = friendlyDealPostingError(e));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyDealPostingError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SourceSummaryCard extends StatelessWidget {
  const _SourceSummaryCard({
    required this.source,
    required this.receiveCurrency,
    required this.receiveAmountText,
    required this.fmt,
  });

  final FxDealLeg source;
  final String receiveCurrency;
  final String receiveAmountText;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final already = source.paidAmount;
    final remaining = source.remainingAmount > 0
        ? source.remainingAmount
        : (source.receiveAmount - source.paidAmount);
    final entering = double.tryParse(receiveAmountText.replaceAll(',', ''));
    final style = Theme.of(context).textTheme.bodyMedium;
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Source summary', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              'Original: ${fmt.format(source.receiveAmount)} ${source.receiveCurrency ?? receiveCurrency}',
              style: style,
            ),
            Text(
              'Already received: ${fmt.format(already)} ${source.receiveCurrency ?? receiveCurrency}',
              style: style,
            ),
            Text(
              'Remaining receivable: ${fmt.format(remaining)} ${source.receiveCurrency ?? receiveCurrency}',
              style: style?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Receiving now: ${entering == null ? '—' : fmt.format(entering)} $receiveCurrency',
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}
