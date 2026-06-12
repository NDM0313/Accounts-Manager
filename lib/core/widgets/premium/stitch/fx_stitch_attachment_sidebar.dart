import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/data/repositories/attachment_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Attachment preview sidebar per Stitch mock.
class FxStitchAttachmentSidebar extends StatelessWidget {
  const FxStitchAttachmentSidebar({
    super.key,
    required this.attachment,
    this.dealId,
    this.dealLabel,
    this.onDownload,
    this.onShareLink,
  });

  final FxAttachment attachment;
  final String? dealId;
  final String? dealLabel;
  final VoidCallback? onDownload;
  final VoidCallback? onShareLink;

  @override
  Widget build(BuildContext context) {
    final typeLabel = attachment.attachmentType ?? 'Document';
    final uploaded = DateFormat('MMM d, yyyy').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FxStitchCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Attachment Info',
                    style: AppTypography.headlineSm(
                      context.fx.primary,
                      context: context,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.info_outline, color: context.fx.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 16),
              _field(
                context,
                'Document Type',
                Row(
                  children: [
                    Icon(Icons.description, size: 18, color: context.fx.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        typeLabel,
                        style: AppTypography.bodyMd(
                          context.fx.onSurface,
                          context: context,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      context,
                      'Uploaded Date',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            uploaded,
                            style: AppTypography.dataMd(
                              context.fx.onSurface,
                              context: context,
                            ),
                          ),
                          Text(
                            DateFormat('HH:mm').format(DateTime.now()),
                            style: AppTypography.bodySm(
                              context.fx.onSurfaceVariant,
                              context: context,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _field(
                      context,
                      'Deal Association',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dealLabel ?? dealId ?? '—',
                            style: AppTypography.dataMd(
                              context.fx.secondary,
                              context: context,
                            ),
                          ),
                          if (dealId != null)
                            Text(
                              dealId!,
                              style: AppTypography.bodySm(
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
              const Divider(height: 24),
              _field(
                context,
                'Step',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.dealLegId != null
                          ? 'Deal Leg Proof'
                          : 'Customer Payment',
                      style: AppTypography.dataMd(
                        context.fx.onSurface,
                        context: context,
                      ),
                    ),
                    Text(
                      attachment.fileName,
                      style: AppTypography.bodySm(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (onDownload != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onDownload,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.fx.secondary,
                      foregroundColor: context.fx.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.download),
                    label: const Text('Download Document'),
                  ),
                ),
              if (onShareLink != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onShareLink,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: context.fx.outlineVariant),
                    ),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share Secure Link'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        FxStitchCard(
          color: context.fx.surfaceContainerLowest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DOCUMENT AUDIT',
                style: AppTypography.labelCaps(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
              const SizedBox(height: 12),
              _auditStep(context, 'Uploaded', 'File stored securely', done: true),
              _auditStep(context, 'Auto-Scanned (OCR)', 'Success', done: true),
              _auditStep(
                context,
                'Compliance Review',
                'Awaiting Approver',
                done: false,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(BuildContext context, String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelCaps(
            context.fx.onSurfaceVariant,
            context: context,
          ).copyWith(fontSize: 9),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _auditStep(
    BuildContext context,
    String title,
    String subtitle, {
    required bool done,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? context.fx.secondary : context.fx.surface,
                  border: done
                      ? null
                      : Border.all(color: context.fx.outlineVariant),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    color: context.fx.outlineVariant,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMd(
                      done
                          ? context.fx.onSurface
                          : context.fx.onSurfaceVariant,
                      context: context,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySm(
                      context.fx.onSurfaceVariant,
                      context: context,
                    ).copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
