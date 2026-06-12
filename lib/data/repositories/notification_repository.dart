import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_notification.dart';

class NotificationRepository {
  Future<List<FxNotification>> fetchList({bool unreadOnly = false}) async {
    final rows = await supabase.rpc('fx_list_notifications', params: {
      'p_unread_only': unreadOnly,
    });
    return (rows as List).cast<Map<String, dynamic>>().map(FxNotification.fromJson).toList();
  }

  Future<void> markRead(String notificationId) async {
    await supabase.rpc('fx_mark_notification_read', params: {
      'p_notification_id': notificationId,
    });
  }

  Future<int> unreadCount() async {
    final list = await fetchList(unreadOnly: true);
    return list.length;
  }
}
