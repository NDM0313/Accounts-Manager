import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Screen 5 — Delivery confirmation.
class DeliveryConfirmationScreen extends ConsumerStatefulWidget {
  const DeliveryConfirmationScreen({super.key, required this.dealId});

  final String dealId;

  @override
  ConsumerState<DeliveryConfirmationScreen> createState() =>
      _DeliveryConfirmationScreenState();
}

class _DeliveryConfirmationScreenState
    extends ConsumerState<DeliveryConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _proofCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  FxDeliveryTarget _target = FxDeliveryTarget.directToCustomer;
  bool _busy = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _costCtrl.dispose();
    _proofCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dealAsync = ref.watch(dealDetailProvider(widget.dealId));
    final fmt = NumberFormat('#,##0.00');

    dealAsync.whenData((deal) {
      if (deal != null && _amountCtrl.text.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _amountCtrl.text.isEmpty) {
            _amountCtrl.text = deal.sellAmount.toString();
          }
        });
      }
    });

    return FxPageScaffold(
      fallbackRoute: '/deals/${widget.dealId}',
      title: const Text('Delivery Confirmation'),
      body: dealAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (deal) {
          if (deal == null) return const Center(child: Text('Deal not found'));
          final estProfit = deal.costBasisPkr != null
              ? deal.customerPayablePkr - deal.costBasisPkr!
              : null;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FxObsidianReportPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deal ${deal.dealNo}',
                        style: AppTypography.headlineMd(
                          context.fx.onSurface,
                          context: context,
                        ),
                      ),
                      Text(
                        'Customer: ${deal.customerName ?? '—'}',
                        style: AppTypography.bodyMd(
                          context.fx.onSurfaceVariant,
                          context: context,
                        ),
                      ),
                      Text(
                        'Sale: PKR ${fmt.format(deal.customerPayablePkr)}',
                        style: AppTypography.bodyMd(
                          context.fx.onSurface,
                          context: context,
                        ),
                      ),
                      if (estProfit != null)
                        Text(
                          'Est. profit: PKR ${fmt.format(estProfit)}',
                          style: AppTypography.bodyMd(
                            context.fx.primary,
                            context: context,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const FxSectionLabel(label: 'Delivery'),
                FxObsidianFormField(
                  controller: _amountCtrl,
                  label: 'Delivered amount',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? 'Enter amount' : null,
                ),
                DropdownButtonFormField<FxDeliveryTarget>(
                  initialValue: _target,
                  decoration: const InputDecoration(
                    labelText: 'Delivered to',
                    border: OutlineInputBorder(),
                  ),
                  items: FxDeliveryTarget.values
                      .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                      )
                      .toList(),
                  onChanged: (v) => setState(
                    () => _target = v ?? FxDeliveryTarget.directToCustomer,
                  ),
                ),
                FxObsidianFormField(
                  controller: _costCtrl,
                  label: 'Actual cost basis (PKR) — for P/L',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                FxObsidianFormField(
                  controller: _proofCtrl,
                  label: 'Proof / TT reference',
                ),
                FxObsidianFormField(
                  controller: _notesCtrl,
                  label: 'Notes',
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                FxObsidianActionBar(
                  onCancel: () => fxSafePop(
                    context,
                    fallbackRoute: '/deals/${widget.dealId}',
                  ),
                  onSave: _busy ? null : _submit,
                  saveLabel: 'Confirm delivery',
                  busy: _busy,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dealRepositoryProvider)
          .confirmDelivery(
            dealId: widget.dealId,
            deliveredAmount: double.parse(_amountCtrl.text),
            deliveryTarget: _target,
            costBasisPkr: double.tryParse(_costCtrl.text),
            proofReference: _proofCtrl.text.trim().isEmpty
                ? null
                : _proofCtrl.text.trim(),
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          );
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
