import 'dart:typed_data';

import 'package:accounts_manager/core/utils/storage_path.dart';
import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FxAttachment {
  const FxAttachment({
    required this.id,
    this.transactionId,
    this.dealId,
    this.dealLegId,
    this.messageId,
    this.remittanceId,
    this.remittanceEventId,
    required this.storagePath,
    required this.fileName,
    this.mimeType,
    this.fileSizeBytes,
    this.attachmentType,
  });

  final String id;
  final String? transactionId;
  final String? dealId;
  final String? dealLegId;
  final String? messageId;
  final String? remittanceId;
  final String? remittanceEventId;
  final String storagePath;
  final String fileName;
  final String? mimeType;
  final int? fileSizeBytes;
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
      storagePath: json['storage_path'] as String,
      fileName: json['file_name'] as String,
      mimeType: json['mime_type'] as String?,
      fileSizeBytes: json['file_size_bytes'] as int?,
      attachmentType: json['attachment_type'] as String?,
    );
  }
}

class AttachmentRepository {
  static const bucket = 'fx-attachments';
  static const _selectCols =
      'id, transaction_id, deal_id, deal_leg_id, message_id, remittance_id, remittance_event_id, storage_path, file_name, mime_type, file_size_bytes, attachment_type';

  Future<List<FxAttachment>> fetchForTransaction(String transactionId) async {
    final rows = await supabase.from('fx_attachments').select(_selectCols).eq('transaction_id', transactionId).order('created_at');
    return (rows as List).cast<Map<String, dynamic>>().map(FxAttachment.fromJson).toList();
  }

  Future<List<FxAttachment>> fetchForLeg(String dealLegId) async {
    final rows = await supabase.from('fx_attachments').select(_selectCols).eq('deal_leg_id', dealLegId).order('created_at');
    return (rows as List).cast<Map<String, dynamic>>().map(FxAttachment.fromJson).toList();
  }

  Future<List<FxAttachment>> fetchForRemittance(String remittanceId) async {
    final rows = await supabase.from('fx_attachments').select(_selectCols).eq('remittance_id', remittanceId).order('created_at');
    return (rows as List).cast<Map<String, dynamic>>().map(FxAttachment.fromJson).toList();
  }

  Future<List<FxAttachment>> fetchForRemittanceEvent(String remittanceEventId) async {
    final rows = await supabase.from('fx_attachments').select(_selectCols).eq('remittance_event_id', remittanceEventId).order('created_at');
    return (rows as List).cast<Map<String, dynamic>>().map(FxAttachment.fromJson).toList();
  }

  Future<Set<String>> fetchTransactionIdsWithAttachments(List<String> transactionIds) async {
    if (transactionIds.isEmpty) return {};
    final rows = await supabase.from('fx_attachments').select('transaction_id').inFilter('transaction_id', transactionIds);
    return (rows as List).cast<Map<String, dynamic>>().where((r) => r['transaction_id'] != null).map((r) => r['transaction_id'] as String).toSet();
  }

  Future<Map<String, int>> fetchLegAttachmentCounts(List<String> legIds) async {
    if (legIds.isEmpty) return {};
    final rows = await supabase.from('fx_attachments').select('deal_leg_id').inFilter('deal_leg_id', legIds);
    final counts = <String, int>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final id = row['deal_leg_id'] as String?;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<FxAttachment> upload({
    required String branchId,
    required String fileName,
    required Uint8List bytes,
    String? displayFileName,
    String? mimeType,
    String? transactionId,
    String? dealId,
    String? dealLegId,
    String? messageId,
    String? remittanceId,
    String? remittanceEventId,
    String? attachmentType,
  }) async {
    assert(
      transactionId != null || dealLegId != null || messageId != null || remittanceId != null,
      'Need transactionId, dealLegId, messageId, or remittanceId',
    );

    final safeName = sanitizeStorageFileName(fileName);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = messageId != null
        ? '${sanitizeStoragePathSegment(branchId)}/messages/${sanitizeStoragePathSegment(messageId)}/${ts}_$safeName'
        : remittanceId != null
            ? '${sanitizeStoragePathSegment(branchId)}/remittance/${sanitizeStoragePathSegment(remittanceId)}/${ts}_$safeName'
            : dealLegId != null && dealId != null
                ? '${sanitizeStoragePathSegment(branchId)}/deals/${sanitizeStoragePathSegment(dealId)}/legs/${sanitizeStoragePathSegment(dealLegId)}/${ts}_$safeName'
                : '${sanitizeStoragePathSegment(branchId)}/${sanitizeStoragePathSegment(transactionId!)}/${ts}_$safeName';

    await supabase.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mimeType));

    final insert = <String, dynamic>{
      'storage_path': path,
      'file_name': displayFileName ?? fileName,
      'mime_type': mimeType,
      'file_size_bytes': bytes.length,
      'uploaded_by': supabase.auth.currentUser?.id,
    };
    if (transactionId != null) insert['transaction_id'] = transactionId;
    if (dealId != null) insert['deal_id'] = dealId;
    if (dealLegId != null) insert['deal_leg_id'] = dealLegId;
    if (messageId != null) insert['message_id'] = messageId;
    if (remittanceId != null) insert['remittance_id'] = remittanceId;
    if (remittanceEventId != null) insert['remittance_event_id'] = remittanceEventId;
    if (attachmentType != null) insert['attachment_type'] = attachmentType;

    final row = await supabase.from('fx_attachments').insert(insert).select(_selectCols).single();
    return FxAttachment.fromJson(row);
  }

  Future<String> signedUrl(String storagePath) async {
    return supabase.storage.from(bucket).createSignedUrl(storagePath, 3600);
  }
}
