import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';

class PartyRepository {
  static const _select =
      'id, company_id, branch_id, party_type, code, name, phone, notes, is_active';

  Future<List<FxParty>> fetchParties({
    required String companyId,
    FxPartyType? partyType,
    bool activeOnly = true,
  }) async {
    var query = supabase.from('fx_parties').select(_select).eq('company_id', companyId);
    if (partyType != null) {
      query = query.eq('party_type', partyType.dbValue);
    }
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final rows = await query.order('name');
    return (rows as List).cast<Map<String, dynamic>>().map(FxParty.fromJson).toList();
  }

  Future<FxParty> fetchParty(String partyId) async {
    final row = await supabase.from('fx_parties').select(_select).eq('id', partyId).single();
    return FxParty.fromJson(row);
  }

  Future<FxParty> createParty(FxParty party) async {
    final row = await supabase.from('fx_parties').insert(party.toInsertJson()).select(_select).single();
    return FxParty.fromJson(row);
  }

  Future<FxParty> updateParty(String partyId, {String? name, String? phone, String? notes, bool? isActive}) async {
    final payload = <String, dynamic>{
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (notes != null) 'notes': notes,
      if (isActive != null) 'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await supabase.from('fx_parties').update(payload).eq('id', partyId).select(_select).single();
    return FxParty.fromJson(row);
  }
}
