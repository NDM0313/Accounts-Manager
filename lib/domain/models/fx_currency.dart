import 'package:accounts_manager/domain/models/fx_currency.dart';

class FxCurrency {
  const FxCurrency({
    required this.id,
    required this.code,
    required this.name,
    required this.symbol,
    required this.isBase,
    required this.isActive,
    this.decimalPlaces = 2,
  });

  final String id;
  final String code;
  final String name;
  final String symbol;
  final bool isBase;
  final bool isActive;
  final int decimalPlaces;

  factory FxCurrency.fromJson(Map<String, dynamic> json) {
    return FxCurrency(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      symbol: (json['symbol'] as String?) ?? '',
      isBase: json['is_base'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      decimalPlaces: (json['decimal_places'] as num?)?.toInt() ?? 2,
    );
  }
}
