import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
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

    return FxPageScaffold(
      title: const Text('Customer Payment'),
      fallbackRoute: '/remittance/${widget.remittanceId}',
      bottomBar: FxObsidianActionBar(
        onCancel: () => context.pop(),
        onSave: _saving ? null : _save,
        saveLabel: 'Post Payment',
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
              Text(
                'Balance due: ${r.balanceDue.toStringAsFixed(2)} ${r.receiveCurrency}',
              ),
              const SizedBox(height: 8),
              Text(r.commissionMode.label),
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
