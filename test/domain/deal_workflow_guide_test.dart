import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/services/deal_workflow_guide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sourcing required deal suggests agent source', () {
    const deal = FxDeal(
      id: 'd1',
      dealNo: 'DL-1',
      customerPartyId: 'c1',
      sellCurrencyCode: 'USD',
      sellAmount: 10000,
      saleRatePkr: 280,
      customerPayablePkr: 2800000,
      customerPaidPkr: 0,
      customerReceivablePkr: 2800000,
      deliveryMethod: FxDeliveryMethod.later,
      status: FxDealStatus.sourcingRequired,
      allowShortPosition: false,
      bookedAt: null,
      createdAt: null,
    );
    final legs = [
      FxDealLeg(
        id: 'l1',
        dealId: 'd1',
        legNo: 1,
        legType: FxDealLegType.customerOrder,
        status: FxDealLegStatus.completed,
        receiveAmount: 10000,
        payAmount: 2800000,
        paidAmount: 0,
        remainingAmount: 0,
      ),
      FxDealLeg(
        id: 'l2',
        dealId: 'd1',
        legNo: 2,
        legType: FxDealLegType.sourcingRequirement,
        status: FxDealLegStatus.pending,
        receiveAmount: 10000,
        payAmount: 0,
        paidAmount: 0,
        remainingAmount: 10000,
      ),
    ];

    final view = DealWorkflowGuide.build(deal: deal, legs: legs);
    expect(view.nextActionTitle, contains('agent'));
    expect(view.warningText, isNotNull);
  });

  test('pending agent source with no receipt suggests currency receipt', () {
    const deal = FxDeal(
      id: 'd2',
      dealNo: 'DL-2',
      customerPartyId: 'c1',
      sellCurrencyCode: 'USD',
      sellAmount: 3000,
      saleRatePkr: 282,
      customerPayablePkr: 846000,
      customerPaidPkr: 500000,
      customerReceivablePkr: 346000,
      deliveryMethod: FxDeliveryMethod.tt,
      status: FxDealStatus.sourcingInProgress,
      allowShortPosition: false,
      bookedAt: null,
      createdAt: null,
    );
    final legs = [
      FxDealLeg(
        id: 'l1',
        dealId: 'd2',
        legNo: 1,
        legType: FxDealLegType.customerOrder,
        status: FxDealLegStatus.completed,
        receiveAmount: 3000,
        payAmount: 846000,
        paidAmount: 0,
        remainingAmount: 0,
      ),
      FxDealLeg(
        id: 'l2',
        dealId: 'd2',
        legNo: 2,
        legType: FxDealLegType.agentSource,
        status: FxDealLegStatus.pending,
        receiveAmount: 3000,
        payAmount: 8160,
        paidAmount: 0,
        remainingAmount: 8160,
      ),
    ];

    final view = DealWorkflowGuide.build(deal: deal, legs: legs);
    expect(view.nextActionTitle, contains('Confirm currency received'));
    expect(view.nextActionRoute, contains('currency-receipt'));

    final agentStep = view.steps.firstWhere((s) => s.key == 'agent_source');
    expect(agentStep.status, DealWorkflowStepStatus.partial);
  });

  test('agent source step completed when currency receipt leg exists', () {
    const deal = FxDeal(
      id: 'd3',
      dealNo: 'DL-3',
      customerPartyId: 'c1',
      sellCurrencyCode: 'USD',
      sellAmount: 3000,
      saleRatePkr: 282,
      customerPayablePkr: 846000,
      customerPaidPkr: 846000,
      customerReceivablePkr: 0,
      deliveryMethod: FxDeliveryMethod.tt,
      status: FxDealStatus.currencyReceived,
      allowShortPosition: false,
      bookedAt: null,
      createdAt: null,
    );
    final legs = [
      FxDealLeg(
        id: 'l1',
        dealId: 'd3',
        legNo: 1,
        legType: FxDealLegType.customerOrder,
        status: FxDealLegStatus.completed,
        receiveAmount: 3000,
        payAmount: 846000,
        paidAmount: 0,
        remainingAmount: 0,
      ),
      FxDealLeg(
        id: 'l2',
        dealId: 'd3',
        legNo: 2,
        legType: FxDealLegType.agentSource,
        status: FxDealLegStatus.pending,
        receiveAmount: 3000,
        payAmount: 8160,
        paidAmount: 0,
        remainingAmount: 8160,
      ),
      FxDealLeg(
        id: 'l3',
        dealId: 'd3',
        legNo: 3,
        legType: FxDealLegType.currencyReceipt,
        status: FxDealLegStatus.completed,
        receiveAmount: 3000,
        payAmount: 0,
        paidAmount: 0,
        remainingAmount: 0,
      ),
    ];

    final view = DealWorkflowGuide.build(deal: deal, legs: legs);
    final agentStep = view.steps.firstWhere((s) => s.key == 'agent_source');
    expect(agentStep.status, DealWorkflowStepStatus.completed);
  });
}
