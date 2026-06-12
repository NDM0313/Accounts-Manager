import 'dart:typed_data';

import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PendingProofFile {
  const PendingProofFile({
    required this.fileName,
    required this.bytes,
    this.mimeType,
  });

  final String fileName;
  final Uint8List bytes;
  final String? mimeType;
}

Future<void> uploadPendingProofsForLeg({
  required WidgetRef ref,
  required String branchId,
  required String dealId,
  required String legId,
  required List<PendingProofFile> files,
  String? attachmentType,
}) async {
  if (files.isEmpty) return;
  final repo = ref.read(attachmentRepositoryProvider);
  for (final f in files) {
    await repo.upload(
      branchId: branchId,
      dealId: dealId,
      dealLegId: legId,
      fileName: f.fileName,
      bytes: f.bytes,
      mimeType: f.mimeType,
      attachmentType: attachmentType ?? 'proof',
    );
  }
}
