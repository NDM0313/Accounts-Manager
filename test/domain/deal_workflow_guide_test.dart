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
}
