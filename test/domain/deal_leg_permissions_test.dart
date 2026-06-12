import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/services/deal_leg_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const deal = FxDeal(
    id: 'deal-1',
    dealNo: 'DL-1',
    customerPartyId: 'cust-1',
    sellCurrencyCode: 'USD',
    sellAmount: 1000,
    saleRatePkr: 280,
    customerPayablePkr: 280000,
    customerPaidPkr: 0,
    customerReceivablePkr: 280000,
    deliveryMethod: FxDeliveryMethod.later,
    status: FxDealStatus.sourcingInProgress,
    allowShortPosition: false,
  );

  FxDealLeg pendingAgentSource({String id = 'leg-1'}) => FxDealLeg(
    id: id,
    dealId: 'deal-1',
    legNo: 2,
    legType: FxDealLegType.agentSource,
    status: FxDealLegStatus.pending,
    receiveAmount: 1000,
    receiveCurrency: 'USD',
    payAmount: 3659,
    payCurrency: 'AED',
    paidAmount: 0,
    remainingAmount: 3659,
  );

  test('pending agent source can be edited and deleted on open deal', () {
    final leg = pendingAgentSource();
    expect(DealLegPermissions.canEditLeg(leg, deal), isTrue);
    expect(DealLegPermissions.canDeleteLeg(leg, deal), isTrue);
    expect(
      DealLegPermissions.editRoute(leg: leg, deal: deal),
      contains('agent-source?legId=leg-1'),
    );
  });

  test('customer order and delivery cannot be modified', () {
    final order = FxDealLeg(
      id: 'leg-o',
      dealId: 'deal-1',
      legNo: 1,
      legType: FxDealLegType.customerOrder,
      status: FxDealLegStatus.completed,
      receiveAmount: 1000,
      payAmount: 280000,
      paidAmount: 0,
      remainingAmount: 0,
    );
    expect(DealLegPermissions.canDeleteLeg(order, deal), isFalse);

    final delivery = FxDealLeg(
      id: 'leg-d',
      dealId: 'deal-1',
      legNo: 5,
      legType: FxDealLegType.delivery,
      status: FxDealLegStatus.completed,
      receiveAmount: 1000,
      payAmount: 0,
      paidAmount: 0,
      remainingAmount: 0,
      linkedTransactionId: 'tx-1',
    );
    expect(DealLegPermissions.canDeleteLeg(delivery, deal), isFalse);
  });

  test('linked transaction blocks delete', () {
    final leg = pendingAgentSource(id: 'leg-x');
    final linked = FxDealLeg(
      id: leg.id,
      dealId: leg.dealId,
      legNo: leg.legNo,
      legType: leg.legType,
      status: leg.status,
      receiveAmount: leg.receiveAmount,
      payAmount: leg.payAmount,
      paidAmount: leg.paidAmount,
      remainingAmount: leg.remainingAmount,
      linkedTransactionId: 'tx-99',
    );
    expect(DealLegPermissions.canDeleteLeg(linked, deal), isFalse);
  });

  test('completed deal blocks leg changes', () {
    const closed = FxDeal(
      id: 'deal-1',
      dealNo: 'DL-1',
      customerPartyId: 'cust-1',
      sellCurrencyCode: 'USD',
      sellAmount: 1000,
      saleRatePkr: 280,
      customerPayablePkr: 280000,
      customerPaidPkr: 280000,
      customerReceivablePkr: 0,
      deliveryMethod: FxDeliveryMethod.later,
      status: FxDealStatus.completed,
      allowShortPosition: false,
    );
    expect(
      DealLegPermissions.canDeleteLeg(pendingAgentSource(), closed),
      isFalse,
    );
  });

  test('legTypeForAddRoute maps menu routes', () {
    expect(
      DealLegPermissions.legTypeForAddRoute('/deals/x/legs/agent-source'),
      FxDealLegType.agentSource,
    );
    expect(
      DealLegPermissions.hasPendingLegOfType([
        pendingAgentSource(),
      ], FxDealLegType.agentSource),
      isTrue,
    );
  });
}
