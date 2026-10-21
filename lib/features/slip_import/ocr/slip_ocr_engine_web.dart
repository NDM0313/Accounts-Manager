import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class SlipOcrEngine {
  static const engineId = 'tesseract.js@5-cdn';

  static bool get isSupported => true;

  static Future<String> recognizeImageBytes(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    await _ensureTesseractLoaded();
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    try {
      final tesseract = web.window.getProperty('Tesseract'.toJS);
      if (tesseract == null) {
        throw StateError('Tesseract.js failed to load from CDN');
      }
      final recognize = (tesseract as JSObject).getProperty('recognize'.toJS);
      if (recognize == null) {
        throw StateError('Tesseract.recognize missing');
      }
      final promise = (recognize as JSFunction).callAsFunction(
        tesseract,
        url.toJS,
        'eng'.toJS,
      );
      if (promise == null) {
        throw StateError('Tesseract.recognize returned null');
      }
      final result = await (promise as JSPromise<JSAny?>).toDart;
      final data = (result as JSObject?)?.getProperty('data'.toJS) as JSObject?;
      final text = data?.getProperty('text'.toJS);
      final s = text?.dartify()?.toString() ?? '';
      if (s.trim().isEmpty) {
        throw StateError('OCR returned empty text — try a clearer image');
      }
      return s;
    } finally {
      web.URL.revokeObjectURL(url);
    }
  }

  static Future<void> _ensureTesseractLoaded() async {
    final existing = web.window.getProperty('Tesseract'.toJS);
    if (existing != null) return;

    final completer = Completer<void>();
    final script = web.HTMLScriptElement()
      ..src =
          'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js'
      ..async = true;
    script.onload = (web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }.toJS;
    script.onerror = (web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Could not load Tesseract.js from CDN. Check network / CSP. '
            'Upload and manual review remain available.',
          ),
        );
      }
    }.toJS;
    web.document.head!.append(script);
    await completer.future.timeout(const Duration(seconds: 45));
  }
}
