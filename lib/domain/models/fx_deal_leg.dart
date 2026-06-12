import 'package:accounts_manager/domain/models/fx_deal.dart';

enum FxDealLegType {
  customerOrder('customer_order'),
  customerPayment('customer_payment'),
  sourcingRequirement('sourcing_requirement'),
  agentSource('agent_source'),
  crossCurrencySource('cross_currency_source'),
  agentPayment('agent_payment'),
  currencyReceipt('currency_receipt'),
  delivery('delivery'),
  adjustment('adjustment');

  const FxDealLegType(this.dbValue);
  final String dbValue;

  static FxDealLegType? fromDb(String? value) {
    if (value == null) return null;
    for (final t in values) {
      if (t.dbValue == value) return t;
    }
    return null;
  }

  String get label => switch (this) {
    customerOrder => 'Customer Order',
    customerPayment => 'Customer Payment',
    sourcingRequirement => 'Sourcing Requirement',
    agentSource => 'Agent Source',
    crossCurrencySource => 'Cross-Currency Source',
    agentPayment => 'Agent Payment',
    currencyReceipt => 'Currency Receipt',
    delivery => 'Delivery',
    adjustment => 'Adjustment',
  };
}

enum FxDealLegStatus {
  pending('pending'),
  partial('partial'),
  completed('completed'),
  failed('failed'),
  reversed('reversed');

  const FxDealLegStatus(this.dbValue);
  final String dbValue;

  static FxDealLegStatus? fromDb(String? value) {
    if (value == null) return null;
    for (final s in values) {
      if (s.dbValue == value) return s;
    }
    return null;
  }

  String get label => switch (this) {
    pending => 'Pending',
    partial => 'Partial',
    completed => 'Completed',
    failed => 'Failed',
    reversed => 'Reversed',
  };
}

enum FxDeliveryTarget {
  ourAccount('our_account'),
  directToCustomer('direct_to_customer'),
  tt('tt');

  const FxDeliveryTarget(this.dbValue);
  final String dbValue;

  static FxDeliveryTarget? fromDb(String? value) {
    if (value == null) return null;
    for (final t in values) {
      if (t.dbValue == value) return t;
    }
    return null;
  }

  String get label => switch (this) {
    ourAccount => 'Our Account',
    directToCustomer => 'Direct to Customer',
    tt => 'TT',
  };
}

class FxDealLeg {
  const FxDealLeg({
    required this.id,
    required this.dealId,
    required this.legNo,
    required this.legType,
    required this.status,
    this.counterpartyPartyId,
    this.counterpartyName,
    this.receiveCurrency,
    required this.receiveAmount,
    this.payCurrency,
    required this.payAmount,
    this.rateUsed,
    required this.paidAmount,
    required this.remainingAmount,
    this.deliveryTarget,
    this.linkedTransactionId,
    this.linkedTransactionNo,
    this.parentLegId,
    this.proofReference,
    this.notes,
    this.completedAt,
    this.createdAt,
    this.attachmentCount = 0,
  });

  final String id;
  final String dealId;
  final int legNo;
  final FxDealLegType legType;
  final FxDealLegStatus status;
  final String? counterpartyPartyId;
  final String? counterpartyName;
  final String? receiveCurrency;
  final double receiveAmount;
  final String? payCurrency;
  final double payAmount;
  final double? rateUsed;
  final double paidAmount;
  final double remainingAmount;
  final FxDeliveryTarget? deliveryTarget;
  final String? linkedTransactionId;
  final String? linkedTransactionNo;
  final String? parentLegId;
  final String? proofReference;
  final String? notes;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final int attachmentCount;

  factory FxDealLeg.fromJson(Map<String, dynamic> json) {
    return FxDealLeg(
      id: json['leg_id'] as String? ?? json['id'] as String,
      dealId: json['deal_id'] as String? ?? '',
      legNo: (json['leg_no'] as num).toInt(),
      legType:
          FxDealLegType.fromDb(json['leg_type'] as String?) ??
          FxDealLegType.adjustment,
      status:
          FxDealLegStatus.fromDb(
            json['leg_status'] as String? ?? json['status'] as String?,
          ) ??
          FxDealLegStatus.pending,
      counterpartyPartyId: json['counterparty_party_id'] as String?,
      counterpartyName:
          json['counterparty_name'] as String? ??
          (json['fx_parties'] as Map<String, dynamic>?)?['name'] as String?,
      receiveCurrency: json['receive_currency'] as String?,
      receiveAmount: (json['receive_amount'] as num?)?.toDouble() ?? 0,
      payCurrency: json['pay_currency'] as String?,
      payAmount: (json['pay_amount'] as num?)?.toDouble() ?? 0,
      rateUsed: (json['rate_used'] as num?)?.toDouble(),
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0,
      deliveryTarget: FxDeliveryTarget.fromDb(
        json['delivery_target'] as String?,
      ),
      linkedTransactionId: json['linked_transaction_id'] as String?,
      linkedTransactionNo: json['linked_transaction_no'] as String?,
      parentLegId: json['parent_leg_id'] as String?,
      proofReference: json['proof_reference'] as String?,
      notes: json['notes'] as String?,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      attachmentCount: (json['attachment_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class PartyDealOpenItem {
  const PartyDealOpenItem({
    required this.dealId,
    this.dealNo,
    required this.dealStatus,
    this.sellCurrency,
    required this.sellAmount,
    required this.payablePkr,
    required this.receivablePkr,
    required this.role,
  });

  final String dealId;
  final String? dealNo;
  final FxDealStatus dealStatus;
  final String? sellCurrency;
  final double sellAmount;
  final double payablePkr;
  final double receivablePkr;
  final String role;

  factory PartyDealOpenItem.fromJson(Map<String, dynamic> json) {
    return PartyDealOpenItem(
      dealId: json['deal_id'] as String,
      dealNo: json['deal_no'] as String?,
      dealStatus:
          FxDealStatus.fromDb(json['deal_status'] as String?) ??
          FxDealStatus.booked,
      sellCurrency: json['sell_currency'] as String?,
      sellAmount: (json['sell_amount'] as num?)?.toDouble() ?? 0,
      payablePkr: (json['customer_payable_pkr'] as num?)?.toDouble() ?? 0,
      receivablePkr: (json['customer_receivable_pkr'] as num?)?.toDouble() ?? 0,
      role: json['role'] as String? ?? 'customer',
    );
  }
}
