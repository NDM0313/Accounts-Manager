import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_conversation.dart';
import 'package:accounts_manager/domain/models/fx_message.dart';

class MessagingRepository {
  Future<List<FxConversation>> listConversations(String branchId) async {
    final rows = await supabase.rpc(
      'fx_list_conversations',
      params: {'p_branch_id': branchId},
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FxConversation.fromJson)
        .toList();
  }

  Future<String> getOrCreateEntityConversation({
    required String branchId,
    required FxConversationType type,
    String? dealId,
    String? partyId,
    String? transactionId,
    String? title,
  }) async {
    final id = await supabase.rpc(
      'fx_get_or_create_entity_conversation',
      params: {
        'p_branch_id': branchId,
        'p_type': type.dbValue,
        'p_context_deal_id': dealId,
        'p_context_party_id': partyId,
        'p_context_transaction_id': transactionId,
        'p_title': title,
      },
    );
    return id as String;
  }

  Future<List<FxMessage>> listMessages(
    String conversationId, {
    int limit = 100,
  }) async {
    final rows = await supabase.rpc(
      'fx_list_messages',
      params: {'p_conversation_id': conversationId, 'p_limit': limit},
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FxMessage.fromJson)
        .toList();
  }

  Future<String> sendMessage({
    required String conversationId,
    required String body,
    FxMessageType type = FxMessageType.text,
    Map<String, dynamic> metadata = const {},
  }) async {
    final id = await supabase.rpc(
      'fx_send_message',
      params: {
        'p_conversation_id': conversationId,
        'p_body': body,
        'p_message_type': type.dbValue,
        'p_metadata': metadata,
      },
    );
    return id as String;
  }

  Future<void> markRead(String conversationId) async {
    await supabase.rpc(
      'fx_mark_conversation_read',
      params: {'p_conversation_id': conversationId},
    );
  }
}
