import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';

abstract final class DealLegPermissions {
  static const _lockedTypes = {
    FxDealLegType.customerOrder,
    FxDealLegType.customerPayment,
    FxDealLegType.delivery,
  };

  static const _lockedDealStatuses = {
    FxDealStatus.completed,
    FxDealStatus.cancelled,
    FxDealStatus.voided,
  };

  static bool canModifyLeg(FxDealLeg leg, FxDeal deal) {
    if (_lockedDealStatuses.contains(deal.status)) return false;
    if (_lockedTypes.contains(leg.legType)) return false;
    if (leg.status != FxDealLegStatus.pending) return false;
    if (leg.linkedTransactionId != null) return false;
    return true;
  }

  static bool canEditLeg(FxDealLeg leg, FxDeal deal) => canModifyLeg(leg, deal);

  static bool canDeleteLeg(FxDealLeg leg, FxDeal deal) => canModifyLeg(leg, deal);

  static String? editRoute({required FxDealLeg leg, required FxDeal deal}) {
    if (!canEditLeg(leg, deal)) return null;
    return switch (leg.legType) {
      FxDealLegType.agentSource => '/deals/${deal.id}/legs/agent-source?legId=${leg.id}',
      FxDealLegType.agentPayment => '/deals/${deal.id}/legs/agent-payment?legId=${leg.id}',
      FxDealLegType.currencyReceipt => '/deals/${deal.id}/legs/currency-receipt?legId=${leg.id}',
      _ => null,
    };
  }

  static bool hasPendingLegOfType(List<FxDealLeg> legs, FxDealLegType type) {
    return legs.any((l) => l.legType == type && l.status == FxDealLegStatus.pending);
  }

  static FxDealLegType? legTypeForAddRoute(String route) {
    if (route.endsWith('/agent-source')) return FxDealLegType.agentSource;
    if (route.endsWith('/agent-payment')) return FxDealLegType.agentPayment;
    if (route.endsWith('/currency-receipt')) return FxDealLegType.currencyReceipt;
    return null;
  }
}
