import 'package:accounts_manager/data/repositories/messaging_repository.dart';
import 'package:accounts_manager/domain/models/fx_conversation.dart';
import 'package:accounts_manager/domain/models/fx_message.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final messagingRepositoryProvider = Provider((ref) => MessagingRepository());

final messagingRefreshProvider =
    NotifierProvider<MessagingRefreshNotifier, int>(
      MessagingRefreshNotifier.new,
    );

class MessagingRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final conversationsListProvider = FutureProvider<List<FxConversation>>((
  ref,
) async {
  ref.watch(messagingRefreshProvider);
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null) return [];
  return ref
      .read(messagingRepositoryProvider)
      .listConversations(profile.branchId);
});

final messagesListProvider = FutureProvider.family<List<FxMessage>, String>((
  ref,
  conversationId,
) async {
  ref.watch(messagingRefreshProvider);
  return ref.read(messagingRepositoryProvider).listMessages(conversationId);
});

final totalUnreadProvider = FutureProvider<int>((ref) async {
  final list = await ref.watch(conversationsListProvider.future);
  return list.fold<int>(0, (s, c) => s + c.unreadCount);
});
