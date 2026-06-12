import 'package:accounts_manager/domain/models/fx_remittance.dart';

enum FxRemittanceEventType {
  created('created'),
  customerPayment('customer_payment'),
  sentToAgent('sent_to_agent'),
  payoutConfirmed('payout_confirmed'),
  agentSettlement('agent_settlement'),
  refund('refund'),
  note('note'),
  statusChange('status_change');

  const FxRemittanceEventType(this.dbValue);
  final String dbValue;

  static FxRemittanceEventType? fromDb(String? value) {
    if (value == null) return null;
    for (final t in values) {
      if (t.dbValue == value) return t;
    }
    return null;
  }

  String get label => switch (this) {
        created => 'Created',
        customerPayment => 'Customer Payment',
        sentToAgent => 'Sent to Agent',
        payoutConfirmed => 'Payout Confirmed',
        agentSettlement => 'Agent Settlement',
        refund => 'Refund',
        note => 'Note',
        statusChange => 'Status Change',
      };
}

class FxRemittanceEvent {
  const FxRemittanceEvent({
    required this.id,
    required this.eventNo,
    required this.eventType,
    this.statusAfter,
    this.amount,
    this.currencyCode,
    this.linkedTransactionId,
    this.proofReference,
    this.notes,
    this.createdAt,
    this.createdByName,
    this.branchName,
    this.actorRole,
    this.attachmentCount = 0,
  });

  final String id;
  final int eventNo;
  final FxRemittanceEventType eventType;
  final FxRemittanceStatus? statusAfter;
  final double? amount;
  final String? currencyCode;
  final String? linkedTransactionId;
  final String? proofReference;
  final String? notes;
  final DateTime? createdAt;
  final String? createdByName;
  final String? branchName;
  final String? actorRole;
  final int attachmentCount;

  factory FxRemittanceEvent.fromJson(Map<String, dynamic> json) {
    return FxRemittanceEvent(
      id: json['event_id'] as String? ?? json['id'] as String,
      eventNo: json['event_no'] as int,
      eventType: FxRemittanceEventType.fromDb(json['event_type'] as String?) ?? FxRemittanceEventType.note,
      statusAfter: FxRemittanceStatus.fromDb(json['status_after'] as String?),
      amount: (json['amount'] as num?)?.toDouble(),
      currencyCode: json['currency_code'] as String?,
      linkedTransactionId: json['linked_transaction_id'] as String?,
      proofReference: json['proof_reference'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      createdByName: json['created_by_name'] as String?,
      branchName: json['branch_name'] as String?,
      actorRole: json['actor_role'] as String?,
      attachmentCount: (json['attachment_count'] as num?)?.toInt() ?? 0,
    );
  }
}
