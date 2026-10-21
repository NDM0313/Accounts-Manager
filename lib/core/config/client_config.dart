import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads **public** browser/client configuration from a JSON asset.
///
/// Preferred over `*.env` filenames: many static servers (including default
/// nginx images) refuse or mishandle `.env` paths/permissions.
///
/// Allowed keys only: API URL, publishable/anon key, non-secret flags.
abstract final class ClientConfig {
  static const assetPath = 'assets/config/client_config.json';

  static const allowedKeys = <String>{
    'SUPABASE_URL',
    'SUPABASE_PUBLISHABLE_KEY',
    'SUPABASE_ANON_KEY',
    'APP_ENV',
    'FX_ALLOW_DEV_ENDPOINTS',
    'FX_SCHEMA_READY',
  };

  /// Loads [assetPath] into [dotenv.env] (overwriting matching keys).
  static Future<void> loadIntoDotenv({String? assetOverride}) async {
    final path = assetOverride ?? assetPath;
    late final String raw;
    try {
      raw = await rootBundle.loadString(path);
    } catch (e) {
      throw StateError(
        'Public client config asset missing ($path). '
        'Copy assets/config/client_config.json.example and fill public keys only.',
      );
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Client config must be a JSON object');
    }

    final unknown = decoded.keys
        .where((k) => !allowedKeys.contains(k))
        .toList(growable: false);
    if (unknown.isNotEmpty) {
      throw StateError(
        'Client config contains unsupported keys: ${unknown.join(', ')}',
      );
    }

    final lines = <String>[];
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value == null) continue;
      // Escape not needed for our public URL/key values; reject newlines.
      final s = value.toString();
      if (s.contains('\n') || s.contains('\r')) {
        throw StateError('Client config value for ${entry.key} contains newline');
      }
      lines.add('${entry.key}=$s');
    }
    dotenv.loadFromString(envString: '${lines.join('\n')}\n');
  }

  /// Human-readable startup failure (never includes key material).
  static String sanitizeError(Object error) {
    final text = error.toString();
    // Strip JWT-shaped and long opaque tokens if any leaked into messages.
    return text
        .replaceAll(RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'), '[redacted]')
        .replaceAll(RegExp(r'sb_[a-z]+_[A-Za-z0-9]+'), '[redacted]');
  }
}
