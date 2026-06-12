import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/premium/fx_amount_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_bottom_action_bar.dart';
import 'package:accounts_manager/core/widgets/premium/fx_help_tip_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:accounts_manager/features/remittance/widgets/remittance_attachments_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RemittanceCustomerPaymentScreen extends ConsumerStatefulWidget {
  const RemittanceCustomerPaymentScreen({
    super.key,
    required this.remittanceId,
  });

  final String remittanceId;

  @override
  ConsumerState<RemittanceCustomerPaymentScreen> createState() =>
      _RemittanceCustomerPaymentScreenState();
}

class _RemittanceCustomerPaymentScreenState
    extends ConsumerState<RemittanceCustomerPaymentScreen> {
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  bool _prefilled = false;

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
          .recordCustomerPayment(
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
    final detailAsync = ref.watch(
      remittanceDetailProvider(widget.remittanceId),
    );
    final profile = ref.watch(currentProfileProvider).value;

    return FxPremiumScaffold(
      title: const Text('Customer Payment'),
      fallbackRoute: '/remittance/${widget.remittanceId}',
      bottomBar: FxBottomActionBar(
        primaryLabel: 'Post Payment',
        onPrimary: _saving ? null : _save,
        secondaryLabel: 'Cancel',
        onSecondary: () => context.pop(),
        isLoading: _saving,
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (r) {
          if (r == null) return const Center(child: Text('Not found'));
          if (!_prefilled && r.balanceDue > 0) {
            _prefilled = true;
            _amount.text = r.balanceDue.toStringAsFixed(2);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FxAmountCard(
                label: 'Balance due',
                amountLabel:
                    '${r.balanceDue.toStringAsFixed(2)} ${r.receiveCurrency}',
                trendLabel: r.commissionMode.label,
              ),
              const SizedBox(height: 12),
              const FxHelpTipCard(
                title: 'Full payment required',
                body:
                    'Partial payments keep status Awaiting Payment. Send to Agent is only enabled after paid amount equals total payable.',
              ),
              const SizedBox(height: 12),
              FxObsidianFormField(
                controller: _amount,
                label: 'Amount received',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              FxObsidianFormField(
                controller: _notes,
                label: 'Notes',
                maxLines: 2,
              ),
              if (profile != null) ...[
                const SizedBox(height: 16),
                RemittanceAttachmentsSection(
                  remittanceId: widget.remittanceId,
                  branchId: profile.branchId,
                  attachmentType: 'payment_receipt',
                  title: 'Payment receipt / proof',
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
