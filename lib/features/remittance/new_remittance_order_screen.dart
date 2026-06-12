import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/premium/fx_amount_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_bottom_action_bar.dart';
import 'package:accounts_manager/core/widgets/premium/fx_help_tip_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/core/widgets/premium/fx_section_header.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NewRemittanceOrderScreen extends ConsumerStatefulWidget {
  const NewRemittanceOrderScreen({super.key});

  @override
  ConsumerState<NewRemittanceOrderScreen> createState() =>
      _NewRemittanceOrderScreenState();
}

class _NewRemittanceOrderScreenState
    extends ConsumerState<NewRemittanceOrderScreen> {
  String? _senderId;
  String? _agentId;
  final _receiverName = TextEditingController();
  final _receiverPhone = TextEditingController();
  final _receiverCity = TextEditingController();
  final _receiverCountry = TextEditingController();
  final _receiveAmount = TextEditingController();
  final _payoutAmount = TextEditingController();
  final _exchangeRate = TextEditingController(text: '1');
  final _commission = TextEditingController(text: '0');
  final _notes = TextEditingController();
  String _receiveCurrency = 'PKR';
  String _payoutCurrency = 'PKR';
  FxRemittanceCommissionMode _commissionMode =
      FxRemittanceCommissionMode.customerPaid;
  bool _saving = false;

  double get _totalPayablePreview {
    final recv = double.tryParse(_receiveAmount.text) ?? 0;
    final comm = double.tryParse(_commission.text) ?? 0;
    return recv +
        (_commissionMode == FxRemittanceCommissionMode.customerPaid ? comm : 0);
  }

  @override
  void dispose() {
    _receiverName.dispose();
    _receiverPhone.dispose();
    _receiverCity.dispose();
    _receiverCountry.dispose();
    _receiveAmount.dispose();
    _payoutAmount.dispose();
    _exchangeRate.dispose();
    _commission.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null || _senderId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select sender/customer')));
      return;
    }
    final recv = double.tryParse(_receiveAmount.text);
    final payout = double.tryParse(_payoutAmount.text);
    final rate = double.tryParse(_exchangeRate.text) ?? 1;
    final comm = double.tryParse(_commission.text) ?? 0;
    if (recv == null || recv <= 0 || payout == null || payout <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter valid amounts')));
      return;
    }
    if (_receiverName.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Receiver name required')));
      return;
    }

    setState(() => _saving = true);
    try {
      final id = await ref
          .read(remittanceRepositoryProvider)
          .createRemittance(
            branchId: profile.branchId,
            senderPartyId: _senderId!,
            receiverName: _receiverName.text.trim(),
            receiverPhone: _receiverPhone.text.trim().isEmpty
                ? null
                : _receiverPhone.text.trim(),
            receiverCity: _receiverCity.text.trim().isEmpty
                ? null
                : _receiverCity.text.trim(),
            receiverCountry: _receiverCountry.text.trim().isEmpty
                ? null
                : _receiverCountry.text.trim(),
            payoutAgentPartyId: _agentId,
            receiveCurrency: _receiveCurrency,
            receiveAmount: recv,
            payoutCurrency: _payoutCurrency,
            payoutAmount: payout,
            exchangeRate: rate,
            commissionAmount: comm,
            commissionMode: _commissionMode,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      ref.read(remittancesRefreshProvider.notifier).refresh();
      if (mounted) context.go('/remittance/$id');
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
    final customersAsync = ref.watch(partiesProvider(FxPartyType.customer));
    final agentsAsync = ref.watch(partiesProvider(FxPartyType.agent));

    return FxPremiumScaffold(
      title: const Text('New Remittance'),
      fallbackRoute: '/remittance',
      bottomBar: FxBottomActionBar(
        primaryLabel: 'Book Order',
        onPrimary: _saving ? null : _save,
        secondaryLabel: 'Cancel',
        onSecondary: () => context.pop(),
        isLoading: _saving,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FxSectionHeader(label: 'Sender / customer'),
          const SizedBox(height: 8),
          customersAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (parties) => DropdownButtonFormField<String>(
              initialValue: _senderId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: parties
                  .map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _senderId = v),
            ),
          ),
          const SizedBox(height: 16),
          const FxSectionHeader(label: 'Receiver'),
          const SizedBox(height: 8),
          FxObsidianFormField(
            controller: _receiverName,
            label: 'Receiver name',
          ),
          FxObsidianFormField(controller: _receiverPhone, label: 'Phone'),
          FxObsidianFormField(controller: _receiverCity, label: 'City'),
          FxObsidianFormField(controller: _receiverCountry, label: 'Country'),
          const SizedBox(height: 16),
          const FxSectionHeader(label: 'Payout agent (optional)'),
          agentsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (parties) => DropdownButtonFormField<String?>(
              initialValue: _agentId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Assign later'),
                ),
                ...parties.map(
                  (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                ),
              ],
              onChanged: (v) => setState(() => _agentId = v),
            ),
          ),
          const SizedBox(height: 16),
          const FxSectionHeader(label: 'Amounts'),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _receiveCurrency,
                  items: const [
                    DropdownMenuItem(value: 'PKR', child: Text('PKR')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'AED', child: Text('AED')),
                  ],
                  onChanged: (v) =>
                      setState(() => _receiveCurrency = v ?? 'PKR'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FxObsidianFormField(
                  controller: _receiveAmount,
                  label: 'Receive amount',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _payoutCurrency,
                  items: const [
                    DropdownMenuItem(value: 'PKR', child: Text('PKR')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'AED', child: Text('AED')),
                  ],
                  onChanged: (v) =>
                      setState(() => _payoutCurrency = v ?? 'PKR'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FxObsidianFormField(
                  controller: _payoutAmount,
                  label: 'Payout amount',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          FxObsidianFormField(
            controller: _exchangeRate,
            label: 'Exchange rate',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          FxObsidianFormField(
            controller: _commission,
            label: 'Commission',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          SegmentedButton<FxRemittanceCommissionMode>(
            segments: const [
              ButtonSegment(
                value: FxRemittanceCommissionMode.customerPaid,
                label: Text('Customer pays'),
              ),
              ButtonSegment(
                value: FxRemittanceCommissionMode.internal,
                label: Text('Internal'),
              ),
            ],
            selected: {_commissionMode},
            onSelectionChanged: (s) =>
                setState(() => _commissionMode = s.first),
          ),
          const SizedBox(height: 4),
          Text(
            _commissionMode.label,
            style: AppTypography.bodyMd(
              context.fx.onSurfaceVariant,
              context: context,
            ).copyWith(fontSize: 12),
          ),
          const SizedBox(height: 8),
          FxAmountCard(
            label: 'Total payable preview',
            amountLabel:
                '${_totalPayablePreview.toStringAsFixed(2)} $_receiveCurrency',
            trendLabel: _commissionMode.label,
          ),
          const SizedBox(height: 8),
          const FxHelpTipCard(
            title: 'Commission mode',
            body:
                'Customer pays: total includes commission. Internal: customer pays receive amount only; commission tracked internally.',
          ),
          const SizedBox(height: 8),
          FxObsidianFormField(controller: _notes, label: 'Notes', maxLines: 2),
        ],
      ),
    );
  }
}
