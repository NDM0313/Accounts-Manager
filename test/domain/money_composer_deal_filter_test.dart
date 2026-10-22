import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors composer eligibility: open deal, same customer, positive outstanding, PKR.
bool allocatable({
  required FxDeal deal,
  required String partyId,
  required String currencyCode,
}) {
  if (deal.customerPartyId != partyId) return false;
  if (!deal.status.isOpen) return false;
  if (deal.customerReceivablePkr <= 0.005) return false;
  if (currencyCode != 'PKR') return false;
  return true;
}

FxDeal deal({
  required String id,
  required String customerId,
  required double receivable,
  FxDealStatus status = FxDealStatus.booked,
}) {
  return FxDeal(
    id: id,
    customerPartyId: customerId,
    sellCurrencyCode: 'USD',
    sellAmount: 100,
    saleRatePkr: 280,
    customerPayablePkr: 28000,
    customerPaidPkr: 28000 - receivable,
    customerReceivablePkr: receivable,
    deliveryMethod: FxDeliveryMethod.later,
    status: status,
    dealNo: 'D-$id',
  );
}

void main() {
  test('allocatable deals require party, open status, outstanding, PKR', () {
    final open = deal(id: '1', customerId: 'c1', receivable: 5000);
    final paid = deal(id: '2', customerId: 'c1', receivable: 0);
    final other = deal(id: '3', customerId: 'c2', receivable: 5000);
    final cancelled = deal(
      id: '4',
      customerId: 'c1',
      receivable: 5000,
      status: FxDealStatus.cancelled,
    );

    expect(allocatable(deal: open, partyId: 'c1', currencyCode: 'PKR'), isTrue);
    expect(allocatable(deal: paid, partyId: 'c1', currencyCode: 'PKR'), isFalse);
    expect(allocatable(deal: other, partyId: 'c1', currencyCode: 'PKR'), isFalse);
    expect(
      allocatable(deal: cancelled, partyId: 'c1', currencyCode: 'PKR'),
      isFalse,
    );
    expect(allocatable(deal: open, partyId: 'c1', currencyCode: 'USD'), isFalse);
  });
}
