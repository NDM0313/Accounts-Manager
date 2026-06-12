import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Stitch internal_team_chat message bubble.
class FxChatBubble extends StatelessWidget {
  const FxChatBubble({
    super.key,
    required this.message,
    required this.timestamp,
    this.isSelf = false,
    this.senderName,
    this.avatarUrl,
    this.readReceipt,
  });

  final String message;
  final String timestamp;
  final bool isSelf;
  final String? senderName;
  final String? avatarUrl;
  final String? readReceipt;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isSelf
        ? context.fx.primary
        : context.fx.surfaceContainerHigh;
    final textColor = isSelf ? context.fx.onPrimary : context.fx.onSurface;

    final bubble = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isSelf ? 16 : 4),
          bottomRight: Radius.circular(isSelf ? 4 : 16),
        ),
        border: isSelf ? null : Border.all(color: context.fx.outlineVariant),
      ),
      child: Text(
        message,
        style: AppTypography.bodyMd(textColor, context: context),
      ),
    );

    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Column(
          crossAxisAlignment:
              isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isSelf)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: context.fx.surfaceContainer,
                    child: Text(
                      (senderName ?? '?').substring(0, 1).toUpperCase(),
                      style: AppTypography.labelCaps(
                        context.fx.primary,
                        context: context,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: bubble),
                ],
              )
            else
              bubble,
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: isSelf ? 0 : 40),
              child: Text(
                readReceipt != null ? '$timestamp • $readReceipt' : timestamp,
                style: AppTypography.labelCaps(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
