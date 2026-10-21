class FxWorkspace {
  const FxWorkspace({
    required this.companyId,
    required this.companyCode,
    required this.companyName,
    required this.branchId,
    required this.branchCode,
    required this.branchName,
    required this.isDemo,
    required this.isActiveWorkspace,
  });

  final String companyId;
  final String companyCode;
  final String companyName;
  final String branchId;
  final String branchCode;
  final String branchName;
  final bool isDemo;
  final bool isActiveWorkspace;

  factory FxWorkspace.fromJson(Map<String, dynamic> json) {
    return FxWorkspace(
      companyId: json['company_id'] as String,
      companyCode: json['company_code'] as String? ?? '',
      companyName: json['company_name'] as String? ?? '',
      branchId: json['branch_id'] as String,
      branchCode: json['branch_code'] as String? ?? '',
      branchName: json['branch_name'] as String? ?? '',
      isDemo: json['is_demo'] as bool? ?? false,
      isActiveWorkspace: json['is_active_workspace'] as bool? ?? false,
    );
  }
}
