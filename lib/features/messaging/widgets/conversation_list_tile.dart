import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/domain/models/fx_conversation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ConversationListTile extends StatelessWidget {
  const ConversationListTile({super.key, required this.conversation, required this.onTap});

  final FxConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = conversation.lastMessageAt != null
        ? DateFormat('d MMM HH:mm').format(conversation.lastMessageAt!.toLocal())
        : '';

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: context.fx.primary.withValues(alpha: 0.12),
        child: Icon(_iconForType(conversation.type), color: context.fx.primary, size: 20),
      ),
      title: Text(
        conversation.title ?? conversation.type.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(time, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11)),
      trailing: conversation.unreadCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.fx.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: TextStyle(color: context.fx.onPrimary, fontSize: 11),
              ),
            )
          : null,
    );
  }

  IconData _iconForType(FxConversationType type) => switch (type) {
        FxConversationType.deal => Icons.handshake_outlined,
        FxConversationType.party => Icons.person_outline,
        FxConversationType.transaction => Icons.receipt_long_outlined,
        FxConversationType.direct => Icons.chat_bubble_outline,
        FxConversationType.company => Icons.groups_outlined,
      };
}
