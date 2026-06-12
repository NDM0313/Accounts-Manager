import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_receive_payment_widgets.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Stitch receive_payment_1 layout — continues into draft transaction flow.
class ReceivePaymentScreen extends ConsumerStatefulWidget {
  const ReceivePaymentScreen({super.key, this.initialPartyId});

  final String? initialPartyId;

  @override
  ConsumerState<ReceivePaymentScreen> createState() =>
      _ReceivePaymentScreenState();
}

class _ReceivePaymentScreenState extends ConsumerState<ReceivePaymentScreen> {
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _dealCtrl = TextEditingController();
  String? _partyId;
  String? _currencyCode;
  String _paymentMethod = 'Bank Transfer';

  @override
  void initState() {
    super.initState();
    _partyId = widget.initialPartyId;
    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _dealCtrl.dispose();
    super.dispose();
  }

  double get _paymentAmount =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;

  void _postToLedger() {
    if (_partyId == null || _currencyCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select customer and currency')),
      );
      return;
    }
    final q = 'type=settlement_receive&mode=customer_receipt'
        '&partyId=$_partyId&currency=$_currencyCode';
    context.push('/transactions/new?$q');
  }

  @override
  Widget build(BuildContext context) {
    final partiesAsync = ref.watch(partiesProvider(FxPartyType.customer));
    final currenciesAsync = ref.watch(currenciesProvider);
    final fmt = NumberFormat('#,##0.00');
    final cur = _currencyCode ?? 'AED';
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final outstanding = _partyId == null
        ? 0.0
        : ref.watch(partyStatementProvider(_partyId!)).whenOrNull(
              data: (view) => view?.summary.netBalancePkr.abs(),
            ) ??
            84200.0;

    final remaining = (outstanding - _paymentAmount).clamp(0.0, double.infinity);
    final isFull = _paymentAmount > 0 && remaining <= 0;

    final formColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        partiesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (parties) => FxStitchReceivePaymentCustomerField(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _partyId,
                hint: const Text('Select Customer'),
                items: parties
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _partyId = v),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FxStitchReceivePaymentAmountCard(
          currencyCode: cur,
          amountField: TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTypography.currencyDisplay(
              color: context.fx.primary,
              mobile: true,
              context: context,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '0.00',
              hintStyle: AppTypography.currencyDisplay(
                color: context.fx.onPrimaryContainer,
                mobile: true,
                context: context,
              ),
            ),
          ),
          currencyField: currenciesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (currencies) => FxStitchReceivePaymentSelect(
              label: 'Currency',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _currencyCode,
                  hint: const Text('Select'),
                  items: currencies
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.code,
                          child: Text('${c.code} — ${c.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _currencyCode = v),
                ),
              ),
            ),
          ),
          methodField: FxStitchReceivePaymentSelect(
            label: 'Payment Method',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _paymentMethod,
                items: const [
                  DropdownMenuItem(
                    value: 'Bank Transfer',
                    child: Text('Bank Transfer'),
                  ),
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                ],
                onChanged: (v) =>
                    setState(() => _paymentMethod = v ?? 'Bank Transfer'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FxStitchReceivePaymentAllocationCard(
          outstandingLabel: _partyId == null
              ? '—'
              : '$cur ${fmt.format(outstanding)}',
          dealField: FxStitchReceivePaymentSelect(
            label: 'Link to Deal',
            child: TextField(
              controller: _dealCtrl,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '#FX-9942',
              ),
            ),
          ),
          referenceField: FxStitchReceivePaymentSelect(
            label: 'Reference Number',
            child: TextField(
              controller: _referenceCtrl,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'TXN-1092384',
              ),
            ),
          ),
          onAttachProof: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Attach proof on confirmation step')),
            );
          },
        ),
      ],
    );

    final summaryColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FxStitchPaymentSummaryCard(
          currencyCode: cur,
          originalBalance: outstanding,
          paymentApplied: _paymentAmount,
          remainingBalance: remaining,
          isFullSettlement: isFull,
        ),
        const SizedBox(height: 12),
        FxStitchReceivePaymentActions(
          onPost: _postToLedger,
          ledgerNote: 'Transaction will be recorded in Ledger',
        ),
        const SizedBox(height: 12),
        const FxStitchReceivePaymentFlowCard(),
      ],
    );

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.surface,
        foregroundColor: context.fx.primary,
        title: Text(
          'Receive Payment',
          style: AppTypography.headlineSm(
            context.fx.primary,
            context: context,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(partiesProvider(FxPartyType.customer));
              ref.invalidate(currenciesProvider);
              if (_partyId != null) {
                ref.invalidate(partyStatementProvider(_partyId!));
              }
            },
          ),
        ],
      ),
      body: FxStitchScaffold(
        padding: EdgeInsets.fromLTRB(
          isWide ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
          8,
          isWide ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
          24,
        ),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 8, child: formColumn),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: summaryColumn),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  formColumn,
                  const SizedBox(height: 16),
                  summaryColumn,
                ],
              ),
      ),
    );
  }
}
