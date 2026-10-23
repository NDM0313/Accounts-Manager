import 'dart:typed_data';

import 'package:accounts_manager/core/utils/image_compressor.dart';
import 'package:accounts_manager/core/utils/storage_path.dart';
import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class FxAttachment {
  const FxAttachment({
    required this.id,
    this.transactionId,
    this.dealId,
    this.dealLegId,
    this.messageId,
    this.remittanceId,
    this.remittanceEventId,
    this.slipImportId,
    required this.storagePath,
    required this.fileName,
    this.mimeType,
    this.fileSizeBytes,
    this.originalByteSize,
    this.storedByteSize,
    this.contentHash,
    this.compressionMeta,
    this.attachmentType,
  });

  final String id;
  final String? transactionId;
  final String? dealId;
  final String? dealLegId;
  final String? messageId;
  final String? remittanceId;
  final String? remittanceEventId;
  final String? slipImportId;
  final String storagePath;
  final String fileName;
  final String? mimeType;
  final int? fileSizeBytes;
  final int? originalByteSize;
  final int? storedByteSize;
  final String? contentHash;
  final Map<String, dynamic>? compressionMeta;
  final String? attachmentType;

  factory FxAttachment.fromJson(Map<String, dynamic> json) {
    return FxAttachment(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String?,
      dealId: json['deal_id'] as String?,
      dealLegId: json['deal_leg_id'] as String?,
      messageId: json['message_id'] as String?,
      remittanceId: json['remittance_id'] as String?,
      remittanceEventId: json['remittance_event_id'] as String?,
      slipImportId: json['slip_import_id'] as String?,
      storagePath: json['storage_path'] as String,
      fileName: json['file_name'] as String,
      mimeType: json['mime_type'] as String?,
      fileSizeBytes: json['file_size_bytes'] as int?,
      originalByteSize: json['original_byte_size'] as int?,
      storedByteSize: json['stored_byte_size'] as int?,
      contentHash: json['content_hash'] as String?,
      compressionMeta: json['compression_meta'] is Map
          ? Map<String, dynamic>.from(json['compression_meta'] as Map)
          : null,
      attachmentType: json['attachment_type'] as String?,
    );
  }
}

class AttachmentUploadRequest {
  const AttachmentUploadRequest({
    required this.fileName,
    required this.bytes,
    this.mimeType,
    this.preferHigherQuality = false,
  });

  final String fileName;
  final Uint8List bytes;
  final String? mimeType;
  final bool preferHigherQuality;
}

class AttachmentRepository {
  static const bucket = 'fx-attachments';
  static const _selectCols =
      'id, transaction_id, deal_id, deal_leg_id, message_id, remittance_id, remittance_event_id, slip_import_id, storage_path, file_name, mime_type, file_size_bytes, original_byte_size, stored_byte_size, content_hash, compression_meta, attachment_type';

  Future<FxAttachment> fetchById(String id) async {
    final row = await supabase
        .from('fx_attachments')
        .select(_selectCols)
        .eq('id', id)
        .single();
    return FxAttachment.fromJson(row);
  }

  Future<List<FxAttachment>> fetchForTransaction(String transactionId) async {
    final rows = await supabase
        .from('fx_attachments')
        .select(_selectCols)
        .eq('transaction_id', transactionId)
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FxAttachment.fromJson)
        .toList();
  }

  Future<List<FxAttachment>> fetchForLeg(String dealLegId) async {
    final rows = await supabase
        .from('fx_attachments')
        .select(_selectCols)
        .eq('deal_leg_id', dealLegId)
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FxAttachment.fromJson)
        .toList();
  }

  Future<List<FxAttachment>> fetchForRemittance(String remittanceId) async {
    final rows = await supabase
        .from('fx_attachments')
        .select(_selectCols)
        .eq('remittance_id', remittanceId)
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FxAttachment.fromJson)
        .toList();
  }

  Future<List<FxAttachment>> fetchForRemittanceEvent(
    String remittanceEventId,
  ) async {
    final rows = await supabase
        .from('fx_attachments')
        .select(_selectCols)
        .eq('remittance_event_id', remittanceEventId)
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FxAttachment.fromJson)
        .toList();
  }

  Future<List<FxAttachment>> fetchForSlipImport(String slipImportId) async {
    final rows = await supabase
        .from('fx_attachments')
        .select(_selectCols)
        .eq('slip_import_id', slipImportId)
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FxAttachment.fromJson)
        .toList();
  }

  Future<Set<String>> fetchTransactionIdsWithAttachments(
    List<String> transactionIds,
  ) async {
    final counts = await fetchTransactionAttachmentCounts(transactionIds);
    return counts.keys.toSet();
  }

  Future<Map<String, int>> fetchTransactionAttachmentCounts(
    List<String> transactionIds,
  ) async {
    if (transactionIds.isEmpty) return {};
    final rows = await supabase
        .from('fx_attachments')
        .select('transaction_id')
        .inFilter('transaction_id', transactionIds);
    final counts = <String, int>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final id = row['transaction_id'] as String?;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, int>> fetchLegAttachmentCounts(List<String> legIds) async {
    if (legIds.isEmpty) return {};
    final rows = await supabase
        .from('fx_attachments')
        .select('deal_leg_id')
        .inFilter('deal_leg_id', legIds);
    final counts = <String, int>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final id = row['deal_leg_id'] as String?;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<FxAttachment?> findByContentHash({
    required String companyId,
    required String contentHash,
  }) async {
    final row = await supabase
        .from('fx_attachments')
        .select(_selectCols)
        .eq('company_id', companyId)
        .eq('content_hash', contentHash)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return FxAttachment.fromJson(row);
  }

  Future<List<FxAttachment>> uploadMany({
    required String companyId,
    required String branchId,
    required List<AttachmentUploadRequest> files,
    String? transactionId,
    String? dealId,
    String? dealLegId,
    String? messageId,
    String? remittanceId,
    String? remittanceEventId,
    String? slipImportId,
    String? attachmentType,
    void Function(int index, CompressionResult compression)? onCompressed,
  }) async {
    final out = <FxAttachment>[];
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      final att = await upload(
        companyId: companyId,
        branchId: branchId,
        fileName: f.fileName,
        bytes: f.bytes,
        mimeType: f.mimeType,
        preferHigherQuality: f.preferHigherQuality,
        transactionId: transactionId,
        dealId: dealId,
        dealLegId: dealLegId,
        messageId: messageId,
        remittanceId: remittanceId,
        remittanceEventId: remittanceEventId,
        slipImportId: slipImportId,
        attachmentType: attachmentType,
        onCompressed: onCompressed == null
            ? null
            : (c) => onCompressed(i, c),
      );
      out.add(att);
    }
    return out;
  }

  Future<FxAttachment> upload({
    required String companyId,
    required String branchId,
    required String fileName,
    required Uint8List bytes,
    String? displayFileName,
    String? mimeType,
    bool preferHigherQuality = false,
    String? transactionId,
    String? dealId,
    String? dealLegId,
    String? messageId,
    String? remittanceId,
    String? remittanceEventId,
    String? slipImportId,
    String? attachmentType,
    void Function(CompressionResult compression)? onCompressed,
  }) async {
    assert(
      transactionId != null ||
          dealLegId != null ||
          messageId != null ||
          remittanceId != null ||
          slipImportId != null,
      'Need a link target (transaction, deal leg, remittance, message, or slip import)',
    );

    final contentHash = sha256.convert(bytes).toString();
    final compression = await ImageCompressor.compressIfNeeded(
      input: bytes,
      fileName: fileName,
      mimeType: mimeType,
      preferHigherQuality: preferHigherQuality,
    );
    onCompressed?.call(compression);

    final safeName = sanitizeStorageFileName(
      compression.mimeType == 'image/jpeg' && !fileName.toLowerCase().endsWith('.pdf')
          ? '${fileName.replaceAll(RegExp(r'\.[^.]+$'), '')}.jpg'
          : fileName,
    );
    final uuid = const Uuid().v4();
    // Company-scoped private path — RLS still required; UUID is not auth.
    final path = [
      sanitizeStoragePathSegment(companyId),
      sanitizeStoragePathSegment(branchId),
      if (slipImportId != null) 'slips/${sanitizeStoragePathSegment(slipImportId)}',
      if (messageId != null) 'messages/${sanitizeStoragePathSegment(messageId)}',
      if (remittanceId != null)
        'remittance/${sanitizeStoragePathSegment(remittanceId)}',
      if (dealLegId != null && dealId != null)
        'deals/${sanitizeStoragePathSegment(dealId)}/legs/${sanitizeStoragePathSegment(dealLegId)}',
      if (transactionId != null) 'tx/${sanitizeStoragePathSegment(transactionId)}',
      '${uuid}_$safeName',
    ].where((s) => s.isNotEmpty).join('/');

    try {
      await supabase.storage.from(bucket).uploadBinary(
            path,
            compression.bytes,
            fileOptions: FileOptions(contentType: compression.mimeType),
          );
    } catch (e) {
      // Do not insert DB row if storage failed.
      rethrow;
    }

    try {
      final insert = <String, dynamic>{
        'company_id': companyId,
        'storage_path': path,
        'file_name': displayFileName ?? fileName,
        'mime_type': compression.mimeType,
        'file_size_bytes': compression.storedBytes,
        'original_byte_size': compression.originalBytes,
        'stored_byte_size': compression.storedBytes,
        'content_hash': contentHash,
        'compression_meta': compression.meta,
        'uploaded_by': supabase.auth.currentUser?.id,
      };
      if (transactionId != null) insert['transaction_id'] = transactionId;
      if (dealId != null) insert['deal_id'] = dealId;
      if (dealLegId != null) insert['deal_leg_id'] = dealLegId;
      if (messageId != null) insert['message_id'] = messageId;
      if (remittanceId != null) insert['remittance_id'] = remittanceId;
      if (remittanceEventId != null) {
        insert['remittance_event_id'] = remittanceEventId;
      }
      if (slipImportId != null) insert['slip_import_id'] = slipImportId;
      if (attachmentType != null) insert['attachment_type'] = attachmentType;

      final row = await supabase
          .from('fx_attachments')
          .insert(insert)
          .select(_selectCols)
          .single();
      return FxAttachment.fromJson(row);
    } catch (e) {
      // Best-effort cleanup of orphaned storage object.
      try {
        await supabase.storage.from(bucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<String> signedUrl(String storagePath) async {
    return supabase.storage.from(bucket).createSignedUrl(storagePath, 3600);
  }

  /// Link an existing slip/proof attachment to a posted transaction.
  Future<void> linkToTransaction({
    required String attachmentId,
    required String transactionId,
  }) async {
    await supabase.from('fx_attachments').update({
      'transaction_id': transactionId,
    }).eq('id', attachmentId);
  }
}
