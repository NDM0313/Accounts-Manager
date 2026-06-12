import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to environment variables.
///
/// Standard names (preferred):
/// - [supabaseUrl] ← `SUPABASE_URL`
/// - [supabasePublishableKey] ← `SUPABASE_PUBLISHABLE_KEY`
///
/// Legacy fallback: `SUPABASE_ANON_KEY` (deprecated, remove after migration).
///
/// Never add `service_role` key here — Flutter/mobile must not use it.
abstract final class Env {
  static String get supabaseUrl {
    final value = dotenv.env['SUPABASE_URL'];
    if (value == null || value.isEmpty) {
      throw StateError('SUPABASE_URL is not set in .env');
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      throw StateError('SUPABASE_URL is not a valid URL');
    }
    if (uri.host.contains('dincouture')) {
      throw StateError(
        'Forbidden old VPS Supabase URL. Use https://ygidlcqhupmxvsdjmvnf.supabase.co',
      );
    }
    if (!uri.host.endsWith('.supabase.co')) {
      throw StateError(
        'SUPABASE_URL must be a Supabase Cloud URL (*.supabase.co)',
      );
    }
    return value;
  }

  static String get supabasePublishableKey {
    final publishable = dotenv.env['SUPABASE_PUBLISHABLE_KEY'];
    if (publishable != null && publishable.isNotEmpty) {
      return publishable;
    }
    final legacy = dotenv.env['SUPABASE_ANON_KEY'];
    if (legacy != null && legacy.isNotEmpty) {
      return legacy;
    }
    throw StateError(
      'SUPABASE_PUBLISHABLE_KEY (or legacy SUPABASE_ANON_KEY) is not set in .env',
    );
  }

  /// Project ref extracted from SUPABASE_URL (e.g. `ygidlcqhupmxvsdjmvnf`).
  /// Safe to log — not a secret.
  static String get supabaseProjectRef {
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null || uri.host.isEmpty) {
      throw StateError('SUPABASE_URL is not a valid URL');
    }
    final ref = uri.host.split('.').first;
    if (ref.isEmpty) {
      throw StateError('Could not extract project ref from SUPABASE_URL');
    }
    return ref;
  }
}
