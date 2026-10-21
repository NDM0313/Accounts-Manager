import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class SlipOcrEngine {
  static const engineId = 'tesseract.js@5.1.1-selfhost';

  static bool get isSupported => true;

  /// Prefer same-origin `/ocr/*` assets. Falls back to pinned jsDelivr only
  /// if self-host load fails (still no paid API; processing stays in-browser).
  static Future<String> recognizeImageBytes(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
    Duration timeout = const Duration(seconds: 90),
    void Function(String stage)? onProgress,
  }) async {
    onProgress?.call('Loading OCR engine…');
    await _ensureTesseractLoaded();
    onProgress?.call('Running recognition…');

    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    try {
      final tesseract = web.window.getProperty('Tesseract'.toJS);
      if (tesseract == null) {
        throw StateError('Tesseract.js failed to load');
      }
      final recognize = (tesseract as JSObject).getProperty('recognize'.toJS);
      if (recognize == null) {
        throw StateError('Tesseract.recognize missing');
      }

      final opts = <String, Object>{
        'workerPath': '/ocr/worker.min.js',
        'corePath': '/ocr/tesseract-core.wasm.js',
        'langPath': '/ocr/lang',
        'logger': (JSObject m) {
          final status = m.getProperty('status'.toJS)?.dartify()?.toString();
          final prog = m.getProperty('progress'.toJS)?.dartify();
          if (status != null) {
            onProgress?.call(
              prog is num
                  ? '$status ${(prog * 100).toStringAsFixed(0)}%'
                  : status,
            );
          }
        }.toJS,
      }.jsify();

      final promise = (recognize as JSFunction).callAsFunction(
        tesseract,
        url.toJS,
        'eng'.toJS,
        opts,
      );
      if (promise == null) {
        throw StateError('Tesseract.recognize returned null');
      }
      final result = await (promise as JSPromise<JSAny?>)
          .toDart
          .timeout(timeout, onTimeout: () {
        throw TimeoutException(
          'OCR timed out after ${timeout.inSeconds}s — enter fields manually or retry',
        );
      });
      final data = (result as JSObject?)?.getProperty('data'.toJS) as JSObject?;
      final text = data?.getProperty('text'.toJS);
      final s = text?.dartify()?.toString() ?? '';
      if (s.trim().isEmpty) {
        throw StateError('OCR returned empty text — try clearer image or manual entry');
      }
      onProgress?.call('OCR complete');
      return s;
    } finally {
      web.URL.revokeObjectURL(url);
    }
  }

  static Future<void> _ensureTesseractLoaded() async {
    final existing = web.window.getProperty('Tesseract'.toJS);
    if (existing != null) return;

    Future<void> load(String src) async {
      final completer = Completer<void>();
      final script = web.HTMLScriptElement()
        ..src = src
        ..async = true;
      script.onload = (web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }.toJS;
      script.onerror = (web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(StateError('Failed loading $src'));
        }
      }.toJS;
      web.document.head!.append(script);
      await completer.future.timeout(const Duration(seconds: 30));
    }

    try {
      await load('/ocr/tesseract.min.js');
    } catch (_) {
      // Pinned CDN fallback — still client-side WASM, not a server OCR API.
      await load(
        'https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js',
      );
    }
    if (web.window.getProperty('Tesseract'.toJS) == null) {
      throw StateError(
        'OCR engine unavailable. Upload still works — enter fields manually.',
      );
    }
  }
}
