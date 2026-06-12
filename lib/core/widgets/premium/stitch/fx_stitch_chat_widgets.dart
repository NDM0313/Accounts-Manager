import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Centered day divider pill.
class FxStitchChatDayDivider extends StatelessWidget {
  const FxStitchChatDayDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: context.fx.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTypography.labelCaps(
            context.fx.onSurfaceVariant,
            context: context,
          ),
        ),
      ),
    );
  }
}

/// Linked transaction context card (glass style).
class FxStitchLinkedTransactionCard extends StatelessWidget {
  const FxStitchLinkedTransactionCard({
    super.key,
    required this.refLabel,
    required this.subtitle,
    required this.amountLabel,
    this.rateLabel,
    this.statusLabel = 'PENDING APPROVAL',
    this.onTap,
  });

  final String refLabel;
  final String subtitle;
  final String amountLabel;
  final String? rateLabel;
  final String statusLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.fx.surfaceContainerLowest.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(color: context.fx.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link, color: context.fx.secondary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Linked Transaction',
                    style: AppTypography.dataMd(
                      context.fx.secondary,
                      context: context,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.fx.tertiaryFixedDim,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: AppTypography.labelCaps(
                        context.fx.onTertiary,
                        context: context,
                      ).copyWith(fontSize: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: context.fx.outlineVariant, height: 1),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          refLabel,
                          style: AppTypography.headlineSm(
                            context.fx.primary,
                            context: context,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: AppTypography.bodySm(
                            context.fx.onSurfaceVariant,
                            context: context,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amountLabel,
                        style: AppTypography.dataLg(
                          context.fx.primary,
                          context: context,
                        ),
                      ),
                      if (rateLabel != null)
                        Text(
                          rateLabel!,
                          style: AppTypography.bodySm(
                            context.fx.outline,
                            context: context,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Voice note attachment bubble.
class FxStitchVoiceNoteBubble extends StatelessWidget {
  const FxStitchVoiceNoteBubble({
    super.key,
    this.durationLabel = '0:14',
    this.fileSizeLabel = 'Voice Memo • 1.2MB',
    this.onPlay,
  });

  final String durationLabel;
  final String fileSizeLabel;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: 40),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.fx.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(color: context.fx.outlineVariant),
                ),
                child: Row(
                  children: [
                    Material(
                      color: context.fx.secondary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onPlay,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 24,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(12, (i) {
                            final h = [4.0, 8.0, 6.0, 14.0, 10.0, 12.0, 5.0, 16.0, 8.0, 18.0, 10.0, 6.0][i % 12];
                            return Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Container(
                                width: 3,
                                height: h,
                                decoration: BoxDecoration(
                                  color: i < 8
                                      ? context.fx.secondary
                                      : context.fx.outlineVariant,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    Text(
                      durationLabel,
                      style: AppTypography.dataMd(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 40, top: 4),
          child: Text(
            fileSizeLabel,
            style: AppTypography.labelCaps(
              context.fx.onSurfaceVariant,
              context: context,
            ),
          ),
        ),
      ],
    );
  }
}

/// Chat input dock per internal_team_chat mock.
class FxStitchChatInputDock extends StatelessWidget {
  const FxStitchChatInputDock({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.sending = false,
    this.hintText = 'Type a message...',
    this.useMicTrailing = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final bool sending;
  final String hintText;
  final bool useMicTrailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAttach,
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    useMicTrailing ? Icons.add_circle_outline : Icons.attach_file,
                    color: context.fx.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: context.fx.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: context.fx.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: AppTypography.bodyMd(
                            context.fx.outline,
                            context: context,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: sending ? null : (_) => onSend(),
                      ),
                    ),
                    if (useMicTrailing)
                      IconButton(
                        icon: Icon(
                          Icons.mic_none_outlined,
                          color: context.fx.onSurfaceVariant,
                          size: 22,
                        ),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.sentiment_satisfied_outlined,
                          color: context.fx.onSurfaceVariant,
                          size: 22,
                        ),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: context.fx.secondary,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                onTap: sending ? null : onSend,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
