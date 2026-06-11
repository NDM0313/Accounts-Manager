import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_user_profile.dart';

class ProfileRepository {
  Future<FxUserProfile?> fetchCurrentProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await supabase
        .from('fx_users_profiles')
        .select('id, company_id, branch_id, full_name, email, is_active')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return FxUserProfile.fromJson(response);
  }

  Future<CompanyAccountingContext> fetchCompanyAccountingContext(String companyId) async {
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
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await supabase
        .from('fx_users_profiles')
        .select(
          'branch_id, fx_branches(name, code, fx_companies(name, code))',
        )
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    final branch = response['fx_branches'] as Map<String, dynamic>?;
    if (branch == null) return null;
    final company = branch['fx_companies'] as Map<String, dynamic>?;
    return BranchContext(
      companyName: company?['name'] as String? ?? '',
      companyCode: company?['code'] as String? ?? '',
      branchName: branch['name'] as String? ?? '',
      branchCode: branch['code'] as String? ?? '',
    );
  }
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
