enum FxMessageType {
  text('text'),
  image('image'),
  file('file'),
  link('link'),
  dealRef('deal_ref'),
  transactionRef('transaction_ref'),
  partyRef('party_ref'),
  system('system');

  const FxMessageType(this.dbValue);
  final String dbValue;

  static FxMessageType? fromDb(String? v) {
    if (v == null) return null;
    for (final t in values) {
      if (t.dbValue == v) return t;
    }
    return null;
  }
}

class FxMessage {
  const FxMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.messageType,
    required this.body,
    this.metadata = const {},
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final FxMessageType messageType;
  final String body;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory FxMessage.fromJson(Map<String, dynamic> json) {
    return FxMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      messageType:
          FxMessageType.fromDb(json['message_type'] as String?) ??
          FxMessageType.text,
      body: json['body'] as String? ?? '',
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
