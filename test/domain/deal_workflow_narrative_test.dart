import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/services/deal_workflow_narrative.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final deal = FxDeal(
    id: 'deal-1',
    dealNo: 'DL-20260610-0001',
    customerPartyId: 'cust-1',
    customerName: 'ASAD',
    sellCurrencyCode: 'USD',
    sellAmount: 1000,
    saleRatePkr: 280,
    customerPayablePkr: 280000,
    customerPaidPkr: 0,
    customerReceivablePkr: 280000,
    deliveryMethod: FxDeliveryMethod.ownBalance,
    status: FxDealStatus.sourcingInProgress,
    allowShortPosition: false,
  );

  final legs = [
    FxDealLeg(
      id: 'leg-1',
      dealId: 'deal-1',
      legNo: 1,
      legType: FxDealLegType.customerOrder,
      status: FxDealLegStatus.completed,
      receiveAmount: 1000,
      receiveCurrency: 'USD',
      payAmount: 280000,
      payCurrency: 'PKR',
      paidAmount: 0,
      remainingAmount: 280000,
    ),
    FxDealLeg(
      id: 'leg-2',
      dealId: 'deal-1',
      legNo: 2,
      legType: FxDealLegType.sourcingRequirement,
      status: FxDealLegStatus.pending,
      receiveAmount: 1000,
      receiveCurrency: 'USD',
      payAmount: 0,
      paidAmount: 0,
      remainingAmount: 1000,
    ),
    FxDealLeg(
      id: 'leg-3',
      dealId: 'deal-1',
      legNo: 3,
      legType: FxDealLegType.agentSource,
      status: FxDealLegStatus.pending,
      counterpartyName: 'IRSHAD',
      receiveAmount: 1000,
      receiveCurrency: 'USD',
      payAmount: 128659,
      payCurrency: 'PKR',
      paidAmount: 0,
      remainingAmount: 128659,
    ),
  ];

  test('buildSummary includes customer order and sourcing sections', () {
    final sections = DealWorkflowNarrative.buildSummary(deal: deal, legs: legs);

    expect(sections.any((s) => s.title == 'Customer order'), isTrue);
    expect(sections.any((s) => s.title == 'Sourcing required'), isTrue);
    expect(sections.any((s) => s.title == 'Agent source'), isTrue);
    expect(sections.any((s) => s.title == 'Next action'), isTrue);

    final customer = sections.firstWhere((s) => s.title == 'Customer order');
    expect(customer.lines.any((l) => l.contains('ASAD')), isTrue);
    expect(customer.lines.any((l) => l.contains('280000')), isTrue);
  });

  test('buildHelp describes sourcing in progress status', () {
    final help = DealWorkflowNarrative.buildHelp(deal: deal, legs: legs);

    expect(help.statusMeaning, contains('sourcing'));
    expect(help.whatToDoNext, isNotEmpty);
    expect(help.statementsAffected, isNotEmpty);
    expect(help.statementsAffected.any((s) => s.contains('Customer statement')), isTrue);
  });

  test('DealLegTimelineActions suggests confirm received for currency receipt leg', () {
    final receiptLeg = FxDealLeg(
      id: 'leg-4',
      dealId: 'deal-1',
      legNo: 4,
      legType: FxDealLegType.currencyReceipt,
      status: FxDealLegStatus.pending,
      receiveAmount: 1000,
      receiveCurrency: 'USD',
      payAmount: 0,
      paidAmount: 0,
      remainingAmount: 1000,
    );

    final action = DealLegTimelineActions.forLeg(
      leg: receiptLeg,
      deal: deal,
      customerPartyId: deal.customerPartyId,
    );

    expect(action?.label, 'Confirm received');
    expect(action?.route, contains('currency-receipt'));
  });

  test('DealLegTimelineActions routes pending agent source to currency receipt', () {
    final agentLeg = FxDealLeg(
      id: 'leg-agent',
      dealId: 'deal-1',
      legNo: 3,
      legType: FxDealLegType.agentSource,
      status: FxDealLegStatus.pending,
      counterpartyName: 'WALI TT',
      receiveAmount: 3000,
      receiveCurrency: 'USD',
      payAmount: 8160,
      payCurrency: 'AED',
      paidAmount: 0,
      remainingAmount: 8160,
      attachmentCount: 1,
    );

    final action = DealLegTimelineActions.forLeg(
      leg: agentLeg,
      deal: deal,
      customerPartyId: deal.customerPartyId,
    );

    expect(action?.label, 'Confirm received');
    expect(action?.route, contains('currency-receipt'));
    expect(action?.onTapKind, isNull);
  });
}
