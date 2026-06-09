class FxRate {
  const FxRate({
    required this.id,
    required this.currencyCode,
    required this.buyRate,
    required this.sellRate,
    required this.effectiveAt,
  });

  final String id;
  final String currencyCode;
  final double buyRate;
  final double sellRate;
  final DateTime effectiveAt;

  factory FxRate.fromJson(Map<String, dynamic> json) {
    return FxRate(
      id: json['id'] as String,
      currencyCode: json['currency_code'] as String,
      buyRate: (json['buy_rate'] as num).toDouble(),
      sellRate: (json['sell_rate'] as num).toDouble(),
      effectiveAt: DateTime.parse(json['effective_at'] as String),
    );
  }
}
