import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';

class PartyRepository {
  static const _selectCols = '''
id, company_id, branch_id, party_type, code, name,
contact_person, business_name, phone, phone_display, phone_e164,
phone2_display, phone2_e164, whatsapp_display, whatsapp_e164, email,
address_line1, address_line2, city, province, postal_code, country_code,
website, notes, photo_attachment_id, social_links, is_active
''';

  Future<List<FxParty>> fetchParties({
    required String companyId,
    FxPartyType? type,
    bool activeOnly = true,
  }) async {
    var q = supabase
        .from('fx_parties')
        .select(_selectCols)
        .eq('company_id', companyId);
    if (type != null) {
      q = q.eq('party_type', type.dbValue);
    }
    if (activeOnly) {
      q = q.eq('is_active', true);
    }
    final rows = await q.order('name');
    return (rows as List)
        .map((e) => FxParty.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<FxParty?> fetchParty(String id) async {
    final row = await supabase
        .from('fx_parties')
        .select(_selectCols)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return FxParty.fromJson(row);
  }

  Future<List<FxParty>> findPossiblePhoneDuplicates({
    required String companyId,
    required String phoneE164,
    String? excludePartyId,
  }) async {
    if (phoneE164.trim().isEmpty) return [];
    var q = supabase
        .from('fx_parties')
        .select(_selectCols)
        .eq('company_id', companyId)
        .eq('phone_e164', phoneE164)
        .eq('is_active', true);
    final rows = await q;
    return (rows as List)
        .map((e) => FxParty.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((p) => excludePartyId == null || p.id != excludePartyId)
        .toList();
  }

  Future<Map<String, dynamic>> upsertPartyProfile(
    Map<String, dynamic> payload,
  ) async {
    final result = await supabase.rpc(
      'fx_upsert_party_profile',
      params: {'p_payload': payload},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  /// Legacy create path — prefer [upsertPartyProfile].
  Future<FxParty> createParty(FxParty party) async {
    final result = await upsertPartyProfile(party.toUpsertPayload());
    final id = result['party_id'] as String;
    final loaded = await fetchParty(id);
    if (loaded == null) {
      throw StateError('Party created but not readable');
    }
    return loaded;
  }

  Future<void> updateParty({
    required String id,
    String? name,
    String? phone,
    String? notes,
    bool? isActive,
  }) async {
    final patch = <String, dynamic>{};
    if (name != null) patch['name'] = name;
    if (phone != null) {
      patch['phone'] = phone;
      patch['phone_display'] = phone;
    }
    if (notes != null) patch['notes'] = notes;
    if (isActive != null) patch['is_active'] = isActive;
    if (patch.isEmpty) return;
    await supabase.from('fx_parties').update(patch).eq('id', id);
  }

  Future<void> deactivateParty(String partyId) async {
    await supabase.rpc('fx_deactivate_party', params: {'p_party_id': partyId});
  }
}
