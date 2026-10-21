import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

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

/// Browser canvas JPEG compression (~120–200 KB target). Strips EXIF/GPS by re-encode.
class ImageCompressor {
  static const targetBytes = 160 * 1024;
  static const maxDimension = 1800;

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
        meta: {
          'action': 'passthrough_pdf',
          'note': 'PDF kept original — no flatten',
        },
      );
    }

    try {
      final bitmap = await _decode(input, mimeType ?? 'image/jpeg');
      final origW = bitmap.width;
      final origH = bitmap.height;
      final longest = origW > origH ? origW : origH;
      final targetDim = preferHigherQuality ? 2200 : maxDimension;
      var w = origW;
      var h = origH;
      if (longest > targetDim) {
        final scale = targetDim / longest;
        w = (origW * scale).round();
        h = (origH * scale).round();
      }

      final qualities = preferHigherQuality
          ? <double>[0.92, 0.85, 0.78]
          : <double>[0.85, 0.75, 0.65, 0.55];
      Uint8List? best;
      var usedQ = qualities.first;
      for (final q in qualities) {
        final encoded = await _encodeJpeg(bitmap, w, h, q);
        if (encoded == null) continue;
        best = encoded;
        usedQ = q;
        if (encoded.length <= targetBytes) break;
      }
      bitmap.close();

      if (best == null) {
        return CompressionResult(
          bytes: input,
          mimeType: mimeType ?? 'image/jpeg',
          originalBytes: input.length,
          keptOriginal: true,
          meta: {'action': 'passthrough_encode_failed'},
        );
      }

      return CompressionResult(
        bytes: best,
        mimeType: 'image/jpeg',
        originalBytes: input.length,
        keptOriginal: false,
        meta: {
          'action': 'canvas_jpeg',
          'original_width': origW,
          'original_height': origH,
          'stored_width': w,
          'stored_height': h,
          'jpeg_quality': usedQ,
          'original_bytes': input.length,
          'stored_bytes': best.length,
          'target_bytes': targetBytes,
          'exif_stripped': true,
          'not_byte_identical_original': true,
        },
      );
    } catch (e) {
      return CompressionResult(
        bytes: input,
        mimeType: mimeType ?? 'application/octet-stream',
        originalBytes: input.length,
        keptOriginal: true,
        meta: {
          'action': 'passthrough_error',
          'error': e.toString(),
        },
      );
    }
  }

  static Future<web.ImageBitmap> _decode(Uint8List bytes, String mime) async {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mime),
    );
    return web.window.createImageBitmap(blob).toDart;
  }

  static Future<Uint8List?> _encodeJpeg(
    web.ImageBitmap bitmap,
    int width,
    int height,
    double quality,
  ) async {
    final canvas = web.HTMLCanvasElement()
      ..width = width
      ..height = height;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (ctx == null) return null;
    ctx.drawImage(bitmap, 0, 0, width.toDouble(), height.toDouble());
    final completer = Completer<Uint8List?>();
    canvas.toBlob(
      (web.Blob? blob) {
        if (blob == null) {
          completer.complete(null);
          return;
        }
        final reader = web.FileReader();
        reader.onloadend = (web.ProgressEvent _) {
          final result = reader.result;
          if (result == null) {
            completer.complete(null);
            return;
          }
          final ab = (result as JSArrayBuffer).toDart;
          completer.complete(ab.asUint8List());
        }.toJS;
        reader.readAsArrayBuffer(blob);
      }.toJS,
      'image/jpeg',
      quality.toJS,
    );
    return completer.future;
  }

  static String formatBytes(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).round()} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
