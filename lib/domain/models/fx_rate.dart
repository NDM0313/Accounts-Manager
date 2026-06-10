class FxRate {
  const FxRate({
    required this.id,
    required this.currencyCode,
    required this.buyRate,
    required this.sellRate,
    required this.effectiveAt,
    this.currencyId,
    this.midRate,
    this.source = 'manual',
    this.notes,
    this.isActive = true,
    this.effectiveTo,
    this.updatedByName,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String currencyCode;
  final String? currencyId;
  final double buyRate;
  final double sellRate;
  final DateTime effectiveAt;
  final double? midRate;
  final String source;
  final String? notes;
  final bool isActive;
  final DateTime? effectiveTo;
  final String? updatedByName;
  final String? createdBy;
  final DateTime? createdAt;

  double get referenceRate => midRate ?? (buyRate + sellRate) / 2;

  FxRate copyWith({
    DateTime? effectiveTo,
    bool? isActive,
  }) {
    return FxRate(
      id: id,
      currencyCode: currencyCode,
      currencyId: currencyId,
      buyRate: buyRate,
      sellRate: sellRate,
      effectiveAt: effectiveAt,
      midRate: midRate,
      source: source,
      notes: notes,
      isActive: isActive ?? this.isActive,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      updatedByName: updatedByName,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

  factory FxRate.fromJson(Map<String, dynamic> json) {
    final buy = (json['buy_rate'] as num).toDouble();
    final sell = (json['sell_rate'] as num).toDouble();
    final mid = json['mid_rate'] as num?;
    return FxRate(
      id: json['id'] as String,
      currencyCode: json['currency_code'] as String,
      currencyId: json['currency_id'] as String?,
      buyRate: buy,
      sellRate: sell,
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      midRate: mid?.toDouble(),
      source: json['rate_source'] as String? ?? json['source'] as String? ?? 'manual',
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      effectiveTo: json['effective_to'] != null ? DateTime.parse(json['effective_to'] as String) : null,
      updatedByName: json['updated_by_name'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
}
