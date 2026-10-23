import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
import 'package:accounts_manager/features/auth/providers/messaging_providers.dart';
import 'package:accounts_manager/features/messaging/widgets/conversation_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MessagesInboxScreen extends ConsumerWidget {
  const MessagesInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.messagingEnabled) {
      return Scaffold(
        appBar: FxPageHeader.appBar(
          context: context,
          fallbackRoute: '/accounts-hub',
          title: const Text('Team Messages'),
        ),
        body: const FxEmptyState(message: 'Messaging is disabled.'),
      );
    }

    final listAsync = ref.watch(conversationsListProvider);

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: FxPageHeader.appBar(
        context: context,
        fallbackRoute: '/accounts-hub',
        title: const Text('Team Messages'),
      ),
      body: listAsync.when(
        loading: () => const FxLoadingState(),
        error: (e, _) => FxErrorState(
          message:
              'Unable to load conversations. Messaging tables may be missing.\n$e',
        ),
        data: (items) {
          if (items.isEmpty) {
            return const FxEmptyState(
              message:
                  'No conversations yet. Open a deal, party, or transaction to start team chat. Messages never post financial journals.',
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => ConversationListTile(
              conversation: items[i],
              onTap: () => context.push('/messages/${items[i].id}'),
            ),
          );
        },
      ),
    );
  }
}
