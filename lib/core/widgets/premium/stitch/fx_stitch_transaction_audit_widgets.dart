import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Centered audit trail badge per transaction_audit_chat mock.
class FxStitchAuditTrailBadge extends StatelessWidget {
  const FxStitchAuditTrailBadge({super.key, required this.threadId});

  final String threadId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: context.fx.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: context.fx.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          'Audit Trail Active • Thread ID: $threadId',
          style: AppTypography.labelCaps(
            context.fx.onSurfaceVariant,
            context: context,
          ).copyWith(fontSize: 10),
        ),
      ),
    );
  }
}

/// Inline ledger reference card inside a received bubble.
class FxStitchLedgerReferenceCard extends StatelessWidget {
  const FxStitchLedgerReferenceCard({
    super.key,
    required this.refLabel,
    required this.amountLabel,
    this.onTap,
  });

  final String refLabel;
  final String amountLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.fx.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: context.fx.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.fx.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: context.fx.onSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      refLabel,
                      style: AppTypography.bodySm(
                        context.fx.primary,
                        context: context,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      amountLabel,
                      style: AppTypography.bodySm(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ).copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, color: context.fx.outline, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal audit note bubble with left secondary border.
class FxStitchInternalAuditNoteCard extends StatelessWidget {
  const FxStitchInternalAuditNoteCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.fx.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
          border: Border(
            left: BorderSide(color: context.fx.secondary, width: 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, size: 16, color: context.fx.secondary),
                const SizedBox(width: 4),
                Text(
                  'INTERNAL AUDIT NOTE',
                  style: AppTypography.labelCaps(
                    context.fx.secondary,
                    context: context,
                  ).copyWith(fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTypography.bodyMd(
                context.fx.onSurface,
                context: context,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered italic system event line.
class FxStitchSystemChatEvent extends StatelessWidget {
  const FxStitchSystemChatEvent({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          message,
          style: AppTypography.bodySm(
            context.fx.outline,
            context: context,
          ).copyWith(fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}

/// Received bubble with optional ledger reference embed.
class FxStitchAuditReceivedBubble extends StatelessWidget {
  const FxStitchAuditReceivedBubble({
    super.key,
    required this.senderName,
    required this.timestamp,
    required this.message,
    this.ledgerRef,
    this.ledgerAmount,
  });

  final String senderName;
  final String timestamp;
  final String message;
  final String? ledgerRef;
  final String? ledgerAmount;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  senderName,
                  style: AppTypography.dataMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ).copyWith(fontSize: 12),
                ),
                const SizedBox(width: 8),
                Text(
                  timestamp,
                  style: AppTypography.bodySm(
                    context.fx.outline,
                    context: context,
                  ).copyWith(fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.fx.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(color: context.fx.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    message,
                    style: AppTypography.bodyMd(
                      context.fx.onSurface,
                      context: context,
                    ),
                  ),
                  if (ledgerRef != null && ledgerAmount != null) ...[
                    const SizedBox(height: 8),
                    FxStitchLedgerReferenceCard(
                      refLabel: ledgerRef!,
                      amountLabel: ledgerAmount!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sent bubble (navy) for audit chat.
class FxStitchAuditSentBubble extends StatelessWidget {
  const FxStitchAuditSentBubble({
    super.key,
    required this.senderName,
    required this.timestamp,
    required this.message,
  });

  final String senderName;
  final String timestamp;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  timestamp,
                  style: AppTypography.bodySm(
                    context.fx.outline,
                    context: context,
                  ).copyWith(fontSize: 10),
                ),
                const SizedBox(width: 8),
                Text(
                  senderName,
                  style: AppTypography.dataMd(
                    context.fx.primary,
                    context: context,
                  ).copyWith(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.fx.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                boxShadow: [
                  BoxShadow(
                    color: context.fx.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                message,
                style: AppTypography.bodyMd(
                  context.fx.onPrimary,
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
