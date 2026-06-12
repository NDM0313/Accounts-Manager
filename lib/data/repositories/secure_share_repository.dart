import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SecureShareLink {
  const SecureShareLink({
    required this.linkId,
    required this.token,
    required this.shareUrl,
  });

  final String linkId;
  final String token;
  final String shareUrl;

  factory SecureShareLink.fromJson(Map<String, dynamic> json) {
    return SecureShareLink(
      linkId: json['link_id'] as String,
      token: json['token'] as String,
      shareUrl: json['share_url'] as String,
    );
  }
}

class SecureShareRepository {
  Future<SecureShareLink> createLink({
    required String entityType,
    required String entityId,
    required DateTime expiresAt,
    bool allowDownload = true,
    String? password,
  }) async {
    final res = await supabase.rpc(
      'fx_create_secure_share_link',
      params: {
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_expires_at': expiresAt.toUtc().toIso8601String(),
        'p_allow_download': allowDownload,
        'p_password': password,
      },
    );
    final row = (res as List).first as Map<String, dynamic>;
    return SecureShareLink.fromJson(row);
  }

  Future<void> revokeLink(String linkId) async {
    await supabase.rpc(
      'fx_revoke_secure_share_link',
      params: {'p_link_id': linkId},
    );
  }
}

final secureShareRepositoryProvider = Provider<SecureShareRepository>(
  (ref) => SecureShareRepository(),
);
