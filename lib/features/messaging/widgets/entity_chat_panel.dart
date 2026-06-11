import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/domain/models/fx_conversation.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/auth/providers/messaging_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Compact chat launcher embedded on deal / party / transaction screens.
class EntityChatPanel extends ConsumerWidget {
  const EntityChatPanel({
    super.key,
    required this.type,
    this.dealId,
    this.partyId,
    this.transactionId,
    this.title,
  });

  final FxConversationType type;
  final String? dealId;
  final String? partyId;
  final String? transactionId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.messagingEnabled) return const SizedBox.shrink();

    return OutlinedButton.icon(
      onPressed: () async {
        final profile = ref.read(currentProfileProvider).value;
        if (profile == null) return;
        try {
          final id = await ref.read(messagingRepositoryProvider).getOrCreateEntityConversation(
                branchId: profile.branchId,
                type: type,
                dealId: dealId,
                partyId: partyId,
                transactionId: transactionId,
                title: title,
              );
          ref.read(messagingRefreshProvider.notifier).refresh();
          if (context.mounted) context.push('/messages/$id');
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
        }
      },
      icon: Icon(Icons.chat_bubble_outline, size: 18, color: context.fx.primary),
      label: const Text('Team chat'),
    );
  }
}
