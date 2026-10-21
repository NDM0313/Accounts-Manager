import 'package:accounts_manager/data/supabase/supabase_client.dart';

class FxPartyBankAccount {
  const FxPartyBankAccount({
    required this.id,
    required this.partyId,
    required this.companyId,
    this.bankName,
    this.accountTitle,
    this.accountNumber,
    this.iban,
    this.currencyCode,
    required this.isPrimary,
    required this.isActive,
  });

  final String id;
  final String partyId;
  final String companyId;
  final String? bankName;
  final String? accountTitle;
  final String? accountNumber;
  final String? iban;
  final String? currencyCode;
  final bool isPrimary;
  final bool isActive;

  String get maskedIdentifier {
    final raw = (iban ?? accountNumber ?? '').replaceAll(' ', '');
    if (raw.isEmpty) return '—';
    if (raw.length <= 4) return '****$raw';
    return '${raw.substring(0, 2)}****${raw.substring(raw.length - 4)}';
  }

  factory FxPartyBankAccount.fromJson(Map<String, dynamic> json) {
    return FxPartyBankAccount(
      id: json['id'] as String,
      partyId: json['party_id'] as String,
      companyId: json['company_id'] as String,
      bankName: json['bank_name'] as String?,
      accountTitle: json['account_title'] as String?,
      accountNumber: json['account_number'] as String?,
      iban: json['iban'] as String?,
      currencyCode: json['currency_code'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class PartyBankRepository {
  Future<List<FxPartyBankAccount>> fetchForParty(String partyId) async {
    final rows = await supabase
        .from('fx_party_bank_accounts')
        .select()
        .eq('party_id', partyId)
        .eq('is_active', true)
        .order('is_primary', ascending: false)
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FxPartyBankAccount.fromJson)
        .toList();
  }

  Future<FxPartyBankAccount> upsert({
    String? id,
    required String companyId,
    required String partyId,
    String? bankName,
    String? accountTitle,
    String? accountNumber,
    String? iban,
    String currencyCode = 'PKR',
    bool isPrimary = false,
  }) async {
    final payload = <String, dynamic>{
      if (id != null) 'id': id,
      'company_id': companyId,
      'party_id': partyId,
      'bank_name': bankName,
      'account_title': accountTitle,
      'account_number': accountNumber,
      'iban': iban,
      'currency_code': currencyCode,
      'is_primary': isPrimary,
      'is_active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await supabase
        .from('fx_party_bank_accounts')
        .upsert(payload)
        .select()
        .single();
    return FxPartyBankAccount.fromJson(row);
  }

  Future<void> deactivate(String id) async {
    await supabase.from('fx_party_bank_accounts').update({
      'is_active': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }
}
