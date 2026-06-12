import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/data/repositories/attachment_repository.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Proof / attachment section for transactions or deal legs.
class FxProofAttachmentsSection extends ConsumerStatefulWidget {
  const FxProofAttachmentsSection({
    super.key,
    required this.branchId,
    this.transactionId,
    this.dealId,
    this.dealLegId,
    this.enabled = true,
    this.title = 'Proof / attachments',
    this.attachmentType,
  });

  final String branchId;
  final String? transactionId;
  final String? dealId;
  final String? dealLegId;
  final bool enabled;
  final String title;
  final String? attachmentType;

  bool get canUpload =>
      enabled &&
      (transactionId != null || (dealId != null && dealLegId != null));

  @override
  ConsumerState<FxProofAttachmentsSection> createState() =>
      _FxProofAttachmentsSectionState();
}

class _FxProofAttachmentsSectionState
    extends ConsumerState<FxProofAttachmentsSection> {
  bool _uploading = false;
  List<FxAttachment>? _attachments;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FxProofAttachmentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transactionId != widget.transactionId ||
        oldWidget.dealLegId != widget.dealLegId) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.dealLegId != null) {
      final list = await ref
          .read(attachmentRepositoryProvider)
          .fetchForLeg(widget.dealLegId!);
      if (mounted) setState(() => _attachments = list);
    } else if (widget.transactionId != null) {
      final list = await ref
          .read(attachmentRepositoryProvider)
          .fetchForTransaction(widget.transactionId!);
      if (mounted) setState(() => _attachments = list);
    } else {
      if (mounted) setState(() => _attachments = []);
    }
  }

  Future<void> _pickAndUpload() async {
    if (!widget.canUpload) return;
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
      if (bytes == null) return;

      await ref
          .read(attachmentRepositoryProvider)
          .upload(
            branchId: widget.branchId,
            fileName: file.name,
            bytes: bytes,
            mimeType: _mimeForExtension(file.extension),
            transactionId: widget.transactionId,
            dealId: widget.dealId,
            dealLegId: widget.dealLegId,
            attachmentType: widget.attachmentType,
          );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String? _mimeForExtension(String? ext) {
    return switch (ext?.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => null,
    };
  }

  Future<void> _open(FxAttachment a) async {
    if (!mounted) return;
    final q = widget.dealId != null ? '?dealId=${widget.dealId}' : '';
    context.push('/attachments/${a.id}/preview$q');
  }

  @override
  Widget build(BuildContext context) {
    final list = _attachments ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FxSectionLabel(label: widget.title),
        if (!widget.canUpload && widget.dealLegId == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Save this step first, then add proof from the deal timeline.',
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 12),
            ),
          ),
        if (widget.canUpload)
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickAndUpload,
            icon: _uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file),
            label: Text(_uploading ? 'Uploading…' : 'Attach file / photo'),
          ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No proof attached yet.',
              style: AppTypography.bodyMd(
                context.fx.outline,
                context: context,
              ).copyWith(fontSize: 12),
            ),
          )
        else
          ...list.map(
            (a) => ListTile(
              dense: true,
              leading: Icon(
                Icons.insert_drive_file,
                color: context.fx.primary,
                size: 20,
              ),
              title: Text(
                a.fileName,
                style: AppTypography.bodyMd(
                  context.fx.onSurface,
                  context: context,
                ).copyWith(fontSize: 13),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new, size: 18),
                onPressed: () => _open(a),
              ),
              onTap: () => _open(a),
            ),
          ),
      ],
    );
  }
}
