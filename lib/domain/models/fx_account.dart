class FxAccount {
  const FxAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.accountType,
    required this.isActive,
    this.parentId,
    this.currencyCode,
  });

  final String id;
  final String code;
  final String name;
  final String accountType;
  final bool isActive;
  final String? parentId;
  final String? currencyCode;

  factory FxAccount.fromJson(Map<String, dynamic> json) {
    final currencyJoin = json['fx_currencies'];
    String? currencyCode = json['currency_code'] as String?;
    if (currencyCode == null && currencyJoin is Map<String, dynamic>) {
      currencyCode = currencyJoin['code'] as String?;
    }
    return FxAccount(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      accountType: json['account_type'] as String,
      isActive: json['is_active'] as bool? ?? true,
      parentId: json['parent_id'] as String?,
      currencyCode: currencyCode,
    );
  }
}
