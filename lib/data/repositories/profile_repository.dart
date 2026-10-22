import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_user_profile.dart';
import 'package:accounts_manager/domain/models/fx_workspace.dart';

class ProfileRepository {
  /// Prefer SECURITY DEFINER RPC (overlays active workspace). Fall back to
  /// direct select (requires self-select RLS). Distinguishes true absence from
  /// query failures by rethrowing unexpected errors.
  Future<FxUserProfile?> fetchCurrentProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final rpc = await supabase.rpc('fx_current_profile');
      if (rpc == null) return null;
      if (rpc is Map) {
        final map = Map<String, dynamic>.from(rpc);
        if (map['id'] == null) return null;
        return FxUserProfile.fromJson(map);
      }
    } catch (_) {
      // Fall through to table select — older backends or transient RPC issues.
    }

    try {
      final response = await supabase
          .from('fx_users_profiles')
          .select('id, company_id, branch_id, full_name, email, is_active')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return FxUserProfile.fromJson(response);
    } catch (e) {
      // Do not convert network/RLS/schema failures into "missing profile".
      throw ProfileLookupException(
        'Could not load your FX profile. Check connection and try again.',
        cause: e,
      );
    }
  }

  Future<List<FxWorkspace>> listMyWorkspaces() async {
    final response = await supabase.rpc('fx_list_my_workspaces');
    final rows = (response as List?) ?? const [];
    return rows
        .whereType<Map>()
        .map((row) => FxWorkspace.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Server enforces membership; client must not invent company access.
  Future<FxWorkspace> switchWorkspace({
    required String companyId,
    required String branchId,
  }) async {
    final response = await supabase.rpc(
      'fx_switch_workspace',
      params: {
        'p_company_id': companyId,
        'p_branch_id': branchId,
      },
    );
    final map = Map<String, dynamic>.from(response as Map);
    return FxWorkspace(
      companyId: map['company_id'] as String,
      companyCode: map['company_code'] as String? ?? '',
      companyName: map['company_name'] as String? ?? '',
      branchId: map['branch_id'] as String,
      branchCode: map['branch_code'] as String? ?? '',
      branchName: map['branch_name'] as String? ?? '',
      isDemo: map['is_demo'] as bool? ?? false,
      isActiveWorkspace: true,
    );
  }

  Future<CompanyAccountingContext> fetchCompanyAccountingContext(
    String companyId,
  ) async {
    final company = await supabase
        .from('fx_companies')
        .select('base_currency_code')
        .eq('id', companyId)
        .maybeSingle();

    final posted = await supabase
        .from('fx_transactions')
        .select('id')
        .eq('company_id', companyId)
        .eq('status', 'posted')
        .limit(1);

    return CompanyAccountingContext(
      baseCurrencyCode: company?['base_currency_code'] as String? ?? 'PKR',
      hasPostedTransactions: (posted as List).isNotEmpty,
    );
  }

  Future<BranchContext?> fetchBranchContext() async {
    final profile = await fetchCurrentProfile();
    if (profile == null) return null;

    final response = await supabase
        .from('fx_branches')
        .select('name, code, fx_companies(name, code)')
        .eq('id', profile.branchId)
        .maybeSingle();

    if (response == null) return null;
    final company = response['fx_companies'] as Map<String, dynamic>?;
    return BranchContext(
      companyName: company?['name'] as String? ?? '',
      companyCode: company?['code'] as String? ?? '',
      branchName: response['name'] as String? ?? '',
      branchCode: response['code'] as String? ?? '',
    );
  }
}

class ProfileLookupException implements Exception {
  ProfileLookupException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class BranchContext {
  const BranchContext({
    required this.companyName,
    required this.companyCode,
    required this.branchName,
    required this.branchCode,
  });

  final String companyName;
  final String companyCode;
  final String branchName;
  final String branchCode;
}

class CompanyAccountingContext {
  const CompanyAccountingContext({
    required this.baseCurrencyCode,
    required this.hasPostedTransactions,
  });

  final String baseCurrencyCode;
  final bool hasPostedTransactions;
}
