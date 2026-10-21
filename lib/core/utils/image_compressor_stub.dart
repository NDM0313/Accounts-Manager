import 'dart:typed_data';

class CompressionResult {
  const CompressionResult({
    required this.bytes,
    required this.mimeType,
    required this.originalBytes,
    required this.keptOriginal,
    required this.meta,
  });

  final Uint8List bytes;
  final String mimeType;
  final int originalBytes;
  final bool keptOriginal;
  final Map<String, dynamic> meta;

  int get storedBytes => bytes.length;
}

class ImageCompressor {
  static const targetBytes = 160 * 1024;

  static Future<CompressionResult> compressIfNeeded({
    required Uint8List input,
    required String fileName,
    String? mimeType,
    bool preferHigherQuality = false,
  }) async {
    final lower = fileName.toLowerCase();
    final isPdf = lower.endsWith('.pdf') || mimeType == 'application/pdf';
    if (isPdf) {
      return CompressionResult(
        bytes: input,
        mimeType: 'application/pdf',
        originalBytes: input.length,
        keptOriginal: true,
        meta: {'action': 'passthrough_pdf'},
      );
    }
    return CompressionResult(
      bytes: input,
      mimeType: mimeType ?? 'application/octet-stream',
      originalBytes: input.length,
      keptOriginal: true,
      meta: {
        'action': 'passthrough_non_web',
        'note': 'Image compression runs in Flutter web via canvas',
      },
    );
  }

  static String formatBytes(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).round()} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
