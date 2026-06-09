class FxUserProfile {
  const FxUserProfile({
    required this.id,
    required this.companyId,
    required this.branchId,
    this.fullName,
    this.email,
    required this.isActive,
  });

  final String id;
  final String companyId;
  final String branchId;
  final String? fullName;
  final String? email;
  final bool isActive;

  factory FxUserProfile.fromJson(Map<String, dynamic> json) {
    return FxUserProfile(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      branchId: json['branch_id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
