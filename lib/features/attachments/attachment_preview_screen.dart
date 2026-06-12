import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_attachment_sidebar.dart';
import 'package:accounts_manager/data/repositories/attachment_repository.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final attachmentByIdProvider = FutureProvider.family<FxAttachment, String>((
  ref,
  id,
) async {
  return ref.read(attachmentRepositoryProvider).fetchById(id);
});

class AttachmentPreviewScreen extends ConsumerWidget {
  const AttachmentPreviewScreen({
    super.key,
    required this.attachmentId,
    this.dealId,
    this.entityType,
    this.entityId,
  });

  final String attachmentId;
  final String? dealId;
  final String? entityType;
  final String? entityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachmentAsync = ref.watch(attachmentByIdProvider(attachmentId));

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.surface,
        title: Text(
          'Preview Document',
          style: AppTypography.headlineSm(context.fx.primary, context: context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _download(context, ref),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: context.fx.error),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: attachmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (attachment) => FutureBuilder<String>(
          future: ref
              .read(attachmentRepositoryProvider)
              .signedUrl(attachment.storagePath),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final url = snap.data!;
            final lower = attachment.fileName.toLowerCase();
            final isImage = lower.endsWith('.png') ||
                lower.endsWith('.jpg') ||
                lower.endsWith('.jpeg') ||
                lower.endsWith('.gif') ||
                lower.endsWith('.webp');

            return LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                final preview = Stack(
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        minHeight: wide ? 600 : 400,
                      ),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: context.fx.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                        border: Border.all(
                          color: context.fx.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: isImage
                          ? InteractiveViewer(
                              child: Image.network(url, fit: BoxFit.contain),
                            )
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.insert_drive_file,
                                    size: 64,
                                    color: context.fx.outline,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(attachment.fileName),
                                  TextButton(
                                    onPressed: () => launchUrl(Uri.parse(url)),
                                    child: const Text('Open externally'),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Row(
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'zoom',
                            backgroundColor: context.fx.primary,
                            foregroundColor: context.fx.onPrimary,
                            onPressed: () {},
                            child: const Icon(Icons.zoom_in),
                          ),
                          const SizedBox(width: 8),
                          FloatingActionButton.small(
                            heroTag: 'fullscreen',
                            backgroundColor: context.fx.surface,
                            foregroundColor: context.fx.primary,
                            onPressed: () => launchUrl(Uri.parse(url)),
                            child: const Icon(Icons.fullscreen),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final mobileMeta = Row(
                  children: [
                    Expanded(
                      child: _MetaChip(
                        label: 'Deal ID',
                        value: dealId ?? attachment.dealId ?? '—',
                        valueColor: context.fx.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetaChip(
                        label: 'Status',
                        value: 'Verified',
                        valueColor: context.fx.tertiaryContainer,
                      ),
                    ),
                  ],
                );

                final sidebar = FxStitchAttachmentSidebar(
                  attachment: attachment,
                  dealId: dealId ?? attachment.dealId,
                  dealLabel: dealId ?? attachment.dealId,
                  onDownload: () => _download(context, ref),
                  onShareLink: entityType != null && entityId != null
                      ? () => context.push(
                          '/share/configure?entityType=$entityType&entityId=$entityId',
                        )
                      : null,
                );

                if (!wide) {
                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.marginMobile),
                    children: [
                      preview,
                      const SizedBox(height: 12),
                      mobileMeta,
                      const SizedBox(height: 16),
                      sidebar,
                    ],
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.marginMobile),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 8, child: preview),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: sidebar),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final attachment = await ref.read(attachmentByIdProvider(attachmentId).future);
    final url = await ref
        .read(attachmentRepositoryProvider)
        .signedUrl(attachment.storagePath);
    await launchUrl(Uri.parse(url));
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final attachment = await ref.read(attachmentByIdProvider(attachmentId).future);
    final url = await ref
        .read(attachmentRepositoryProvider)
        .signedUrl(attachment.storagePath);
    await SharePlus.instance.share(
      ShareParams(text: url, subject: attachment.fileName),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete attachment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete is not available for this attachment yet.')),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.fx.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.labelCaps(
              context.fx.onSurfaceVariant,
              context: context,
            ).copyWith(fontSize: 9),
          ),
          Text(
            value,
            style: AppTypography.dataMd(valueColor, context: context),
          ),
        ],
      ),
    );
  }
}
