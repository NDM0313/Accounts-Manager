import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/data/repositories/attachment_repository.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class RemittanceAttachmentsSection extends ConsumerStatefulWidget {
  const RemittanceAttachmentsSection({
    super.key,
    required this.remittanceId,
    required this.branchId,
    this.remittanceEventId,
    this.enabled = true,
    this.title = 'Attachments',
    this.attachmentType,
  });

  final String remittanceId;
  final String branchId;
  final String? remittanceEventId;
  final bool enabled;
  final String title;
  final String? attachmentType;

  @override
  ConsumerState<RemittanceAttachmentsSection> createState() => _RemittanceAttachmentsSectionState();
}

class _RemittanceAttachmentsSectionState extends ConsumerState<RemittanceAttachmentsSection> {
  bool _uploading = false;
  List<FxAttachment>? _attachments;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(attachmentRepositoryProvider);
    final list = widget.remittanceEventId != null
        ? await repo.fetchForRemittanceEvent(widget.remittanceEventId!)
        : await repo.fetchForRemittance(widget.remittanceId);
    if (mounted) setState(() => _attachments = list);
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() => _uploading = true);
    try {
      await ref.read(attachmentRepositoryProvider).upload(
            branchId: widget.branchId,
            fileName: file.name,
            bytes: file.bytes!,
            remittanceId: widget.remittanceId,
            remittanceEventId: widget.remittanceEventId,
            attachmentType: widget.attachmentType,
          );
      await _load();
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _attachments ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: FxSectionLabel(label: widget.title)),
            if (widget.enabled)
              TextButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: _uploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.attach_file, size: 18),
                label: const Text('Add'),
              ),
          ],
        ),
        if (list.isEmpty)
          Text('No attachments', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context))
        else
          ...list.map((a) => ListTile(
                dense: true,
                title: Text(a.fileName, style: AppTypography.bodyMd(context.fx.onSurface, context: context)),
                subtitle: a.attachmentType != null ? Text(a.attachmentType!) : null,
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () async {
                  final url = await ref.read(attachmentRepositoryProvider).signedUrl(a.storagePath);
                  await launchUrl(Uri.parse(url));
                },
              )),
      ],
    );
  }
}
