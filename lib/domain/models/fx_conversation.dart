enum FxConversationType {
  direct('direct'),
  deal('deal'),
  party('party'),
  transaction('transaction'),
  company('company');

  const FxConversationType(this.dbValue);
  final String dbValue;

  static FxConversationType? fromDb(String? v) {
    if (v == null) return null;
    for (final t in values) {
      if (t.dbValue == v) return t;
    }
    return null;
  }
}

class FxConversation {
  const FxConversation({
    required this.id,
    required this.type,
    this.title,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  final String id;
  final FxConversationType type;
  final String? title;
  final DateTime? lastMessageAt;
  final int unreadCount;

  factory FxConversation.fromJson(Map<String, dynamic> json) {
    return FxConversation(
      id: json['conversation_id'] as String? ?? json['id'] as String,
      type:
          FxConversationType.fromDb(json['conversation_type'] as String?) ??
          FxConversationType.company,
      title: json['title'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
