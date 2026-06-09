import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/utils/storage_path.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/data/repositories/attachment_repository.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class FxAttachmentsSection extends ConsumerStatefulWidget {
  const FxAttachmentsSection({
    super.key,
    required this.transactionId,
    required this.branchId,
    this.enabled = true,
  });

  final String transactionId;
  final String branchId;
  final bool enabled;

  @override
  ConsumerState<FxAttachmentsSection> createState() => _FxAttachmentsSectionState();
}

class _FxAttachmentsSectionState extends ConsumerState<FxAttachmentsSection> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file bytes.')),
          );
        }
        return;
      }
      await ref.read(attachmentRepositoryProvider).upload(
            transactionId: widget.transactionId,
            branchId: widget.branchId,
            fileName: sanitizeStorageFileName(file.name),
            displayFileName: file.name,
            bytes: bytes,
            mimeType: _mimeForName(file.name),
          );
      ref.invalidate(attachmentsForTransactionProvider(widget.transactionId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded ${file.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String? _mimeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return null;
  }

  Future<void> _openAttachment(FxAttachment attachment) async {
    try {
      final url = await ref.read(attachmentRepositoryProvider).signedUrl(attachment.storagePath);
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open attachment.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Open failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final attachmentsAsync = ref.watch(attachmentsForTransactionProvider(widget.transactionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FxSectionLabel(label: 'Attachment / Proof'),
        const SizedBox(height: 8),
        if (widget.enabled)
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickAndUpload,
            icon: _uploading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fx.onSurfaceVariant),
                  )
                : const Icon(Icons.upload_file, size: 18),
            label: Text(_uploading ? 'Uploading…' : 'Upload file'),
          ),
        const SizedBox(height: 8),
        attachmentsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Attachments: $e', style: AppTypography.bodyMd(fx.error, context: context)),
          data: (files) {
            if (files.isEmpty) {
              return Text(
                'No files attached.',
                style: AppTypography.bodyMd(fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
              );
            }
            return Column(
              children: files
                  .map(
                    (f) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.attach_file, size: 18, color: fx.onSurfaceVariant),
                      title: Text(f.fileName, style: AppTypography.bodyMd(fx.onSurface, context: context)),
                      trailing: Icon(Icons.open_in_new, size: 16, color: fx.onSurfaceVariant),
                      onTap: () => _openAttachment(f),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
