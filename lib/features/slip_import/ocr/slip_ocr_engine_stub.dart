import 'dart:typed_data';

class SlipOcrEngine {
  static const engineId = 'unavailable';

  static bool get isSupported => false;

  static Future<String> recognizeImageBytes(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
    Duration timeout = const Duration(seconds: 90),
    void Function(String stage)? onProgress,
  }) async {
    throw UnsupportedError(
      'OCR runs in Flutter web with self-hosted Tesseract.js under /ocr/. '
      'Open https://fx.ndmcore.com — upload still works for manual entry.',
    );
  }
}
