class FxNotification {
  const FxNotification({
    required this.id,
    required this.eventType,
    required this.title,
    required this.body,
    this.remittanceId,
    this.readAt,
    required this.createdAt,
    this.payload = const {},
  });

  final String id;
  final String eventType;
  final String title;
  final String body;
  final String? remittanceId;
  final DateTime? readAt;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  bool get isUnread => readAt == null;

  factory FxNotification.fromJson(Map<String, dynamic> json) {
    return FxNotification(
      id: json['id'] as String,
      eventType: json['event_type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      remittanceId: json['remittance_id'] as String?,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }
}
