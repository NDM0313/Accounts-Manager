enum FxPartyType {
  customer('customer'),
  agent('agent'),
  supplier('supplier'),
  settlement('settlement');

  const FxPartyType(this.dbValue);
  final String dbValue;

  static FxPartyType? fromDb(String? value) {
    if (value == null) return null;
    for (final t in values) {
      if (t.dbValue == value) return t;
    }
    return null;
  }

  String get label => switch (this) {
        customer => 'Customer / client',
        agent => 'Agent',
        supplier => 'Supplier / counterparty',
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
    this.contactPerson,
    this.businessName,
    this.phone,
    this.phoneDisplay,
    this.phoneE164,
    this.phone2Display,
    this.phone2E164,
    this.whatsappDisplay,
    this.whatsappE164,
    this.email,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.province,
    this.postalCode,
    this.countryCode,
    this.website,
    this.notes,
    this.photoAttachmentId,
    this.socialLinks = const {},
    this.isActive = true,
  });

  final String id;
  final String companyId;
  final String? branchId;
  final FxPartyType partyType;
  final String code;
  final String name;
  final String? contactPerson;
  final String? businessName;
  final String? phone;
  final String? phoneDisplay;
  final String? phoneE164;
  final String? phone2Display;
  final String? phone2E164;
  final String? whatsappDisplay;
  final String? whatsappE164;
  final String? email;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? province;
  final String? postalCode;
  final String? countryCode;
  final String? website;
  final String? notes;
  final String? photoAttachmentId;
  final Map<String, dynamic> socialLinks;
  final bool isActive;

  String get primaryPhone =>
      (phoneDisplay ?? phone)?.trim().isNotEmpty == true
          ? (phoneDisplay ?? phone)!
          : '';

  factory FxParty.fromJson(Map<String, dynamic> json) {
    return FxParty(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      branchId: json['branch_id'] as String?,
      partyType:
          FxPartyType.fromDb(json['party_type'] as String?) ??
          FxPartyType.customer,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      contactPerson: json['contact_person'] as String?,
      businessName: json['business_name'] as String?,
      phone: json['phone'] as String?,
      phoneDisplay: json['phone_display'] as String?,
      phoneE164: json['phone_e164'] as String?,
      phone2Display: json['phone2_display'] as String?,
      phone2E164: json['phone2_e164'] as String?,
      whatsappDisplay: json['whatsapp_display'] as String?,
      whatsappE164: json['whatsapp_e164'] as String?,
      email: json['email'] as String?,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      postalCode: json['postal_code'] as String?,
      countryCode: json['country_code'] as String?,
      website: json['website'] as String?,
      notes: json['notes'] as String?,
      photoAttachmentId: json['photo_attachment_id'] as String?,
      socialLinks: (json['social_links'] as Map?)?.cast<String, dynamic>() ??
          const {},
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toUpsertPayload({
    String? companyId,
    String? branchId,
    String? clientOperationId,
    Map<String, dynamic>? opening,
  }) {
    final map = <String, dynamic>{
      if (id.isNotEmpty) 'id': id,
      'company_id': ?companyId,
      'branch_id': ?branchId,
      'party_type': partyType.dbValue,
      'name': name,
      if (code.trim().isNotEmpty) 'code': code.trim(),
      'contact_person': contactPerson,
      'business_name': businessName,
      'phone_display': phoneDisplay ?? phone,
      'phone_e164': phoneE164,
      'phone2_display': phone2Display,
      'phone2_e164': phone2E164,
      'whatsapp_display': whatsappDisplay,
      'whatsapp_e164': whatsappE164,
      'email': email,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'province': province,
      'postal_code': postalCode,
      'country_code': countryCode,
      'website': website,
      'notes': notes,
      'photo_attachment_id': photoAttachmentId,
      'social_links': socialLinks,
      'client_operation_id': ?clientOperationId,
      'opening': ?opening,
    };
    return map;
  }
}
