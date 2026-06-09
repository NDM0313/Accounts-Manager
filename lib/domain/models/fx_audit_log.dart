class AuditLogRow {
  const AuditLogRow({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.reason,
    this.oldValue,
    this.newValue,
    required this.createdAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String action;
  final String? reason;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final DateTime createdAt;

  factory AuditLogRow.fromJson(Map<String, dynamic> json) {
    return AuditLogRow(
      id: json['id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      action: json['action'] as String,
      reason: json['reason'] as String?,
      oldValue: json['old_value'] as Map<String, dynamic>?,
      newValue: json['new_value'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Field keys present in both old and new payloads for diff rendering.
  Iterable<MapEntry<String, (dynamic oldVal, dynamic newVal)>> get changedFields sync* {
    if (oldValue == null || newValue == null) return;
    final keys = {...oldValue!.keys, ...newValue!.keys};
    for (final key in keys) {
      final oldVal = oldValue![key];
      final newVal = newValue![key];
      if (oldVal != newVal) {
        yield MapEntry(key, (oldVal, newVal));
      }
    }
  }
}
