import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
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
        appBar: AppBar(title: const Text('Messages')),
        body: const Center(child: Text('Messaging is disabled.')),
      );
    }

    final listAsync = ref.watch(conversationsListProvider);

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: context.fx.background,
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load conversations.\nApply migration 202606230003 if tables are missing.\n\n$e',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No conversations yet.\nOpen a deal, party, or transaction to start team chat.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
              ),
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
