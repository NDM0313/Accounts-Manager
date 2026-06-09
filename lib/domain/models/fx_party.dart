enum FxPartyType {
  customer('customer'),
  agent('agent'),
  settlement('settlement');

  const FxPartyType(this.dbValue);
  final String dbValue;

  static FxPartyType? fromDb(String value) {
    for (final t in values) {
      if (t.dbValue == value) return t;
    }
    return null;
  }

  String get label => switch (this) {
        customer => 'Customer',
        agent => 'Agent',
        settlement => 'Settlement',
      };
}

class FxParty {
  const FxParty({
    required this.id,
    required this.companyId,
    this.branchId,
    required this.partyType,
    required this.code,
    required this.name,
    this.phone,
    this.notes,
    required this.isActive,
  });

  final String id;
  final String companyId;
  final String? branchId;
  final FxPartyType partyType;
  final String code;
  final String name;
  final String? phone;
  final String? notes;
  final bool isActive;

  factory FxParty.fromJson(Map<String, dynamic> json) {
    return FxParty(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      branchId: json['branch_id'] as String?,
      partyType: FxPartyType.fromDb(json['party_type'] as String)!,
      code: json['code'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'company_id': companyId,
        if (branchId != null) 'branch_id': branchId,
        'party_type': partyType.dbValue,
        'code': code,
        'name': name,
        if (phone != null) 'phone': phone,
        if (notes != null) 'notes': notes,
        'is_active': isActive,
      };
}
