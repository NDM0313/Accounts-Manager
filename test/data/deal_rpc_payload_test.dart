import 'package:accounts_manager/data/repositories/deal_rpc_payload.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DealRpcPayload', () {
    test('bookCustomerDeal uses JSON keys without p_ prefix', () {
      final payload = DealRpcPayload.bookCustomerDeal(
        branchId: 'b1',
        customerPartyId: 'c1',
        sellCurrencyCode: 'USD',
        sellAmount: 1000,
        saleRatePkr: 280,
      );
      expect(payload['branch_id'], 'b1');
      expect(payload['sell_currency_code'], 'USD');
      expect(payload.containsKey('p_branch_id'), false);
    });

    test('addLeg normalizes RMB to CNY', () {
      final payload = DealRpcPayload.addLeg(
        dealId: 'd1',
        legType: FxDealLegType.agentSource,
        receiveCurrency: 'RMB',
        receiveAmount: 5000,
        payCurrency: 'AED',
        payAmount: 500,
      );
      expect(payload['receive_currency'], 'CNY');
      expect(payload['leg_type'], 'agent_source');
    });
  });
}
