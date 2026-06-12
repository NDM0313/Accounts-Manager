import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/domain/models/fx_message.dart';
import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.isMine});

  final FxMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? context.fx.primary.withValues(alpha: 0.15)
              : context.fx.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.fx.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.messageType != FxMessageType.text)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.messageType.name,
                  style: AppTypography.labelCaps(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ).copyWith(fontSize: 9),
                ),
              ),
            Text(
              message.body,
              style: AppTypography.bodyMd(
                context.fx.onSurface,
                context: context,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
