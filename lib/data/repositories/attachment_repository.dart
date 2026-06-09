import 'dart:typed_data';

import 'package:accounts_manager/core/utils/storage_path.dart';
import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FxAttachment {
  const FxAttachment({
    required this.id,
    required this.transactionId,
    required this.storagePath,
    required this.fileName,
    this.mimeType,
    this.fileSizeBytes,
  });

  final String id;
  final String transactionId;
  final String storagePath;
  final String fileName;
  final String? mimeType;
  final int? fileSizeBytes;

  factory FxAttachment.fromJson(Map<String, dynamic> json) {
    return FxAttachment(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String,
      storagePath: json['storage_path'] as String,
      fileName: json['file_name'] as String,
      mimeType: json['mime_type'] as String?,
      fileSizeBytes: json['file_size_bytes'] as int?,
    );
  }
}

class AttachmentRepository {
  static const bucket = 'fx-attachments';

  Future<List<FxAttachment>> fetchForTransaction(String transactionId) async {
    final rows = await supabase
        .from('fx_attachments')
        .select('id, transaction_id, storage_path, file_name, mime_type, file_size_bytes')
        .eq('transaction_id', transactionId)
        .order('created_at');
    return (rows as List).cast<Map<String, dynamic>>().map(FxAttachment.fromJson).toList();
  }

  Future<FxAttachment> upload({
    required String transactionId,
    required String branchId,
    required String fileName,
    String? displayFileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final safeName = sanitizeStorageFileName(fileName);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path =
        '${sanitizeStoragePathSegment(branchId)}/${sanitizeStoragePathSegment(transactionId)}/${ts}_$safeName';
    await supabase.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mimeType));

    final row = await supabase
        .from('fx_attachments')
        .insert({
          'transaction_id': transactionId,
          'storage_path': path,
          'file_name': displayFileName ?? fileName,
          'mime_type': mimeType,
          'file_size_bytes': bytes.length,
          'uploaded_by': supabase.auth.currentUser?.id,
        })
        .select('id, transaction_id, storage_path, file_name, mime_type, file_size_bytes')
        .single();

    return FxAttachment.fromJson(row);
  }

  Future<String> signedUrl(String storagePath) async {
    return supabase.storage.from(bucket).createSignedUrl(storagePath, 3600);
  }
}
