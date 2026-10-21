import 'dart:typed_data';

class SlipOcrEngine {
  static const engineId = 'unavailable';

  static bool get isSupported => false;

  static Future<String> recognizeImageBytes(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    throw UnsupportedError(
      'OCR is available on Flutter web (Safari/Chrome). '
      'Upload the slip and enter fields manually, or open the web app.',
    );
  }
}
