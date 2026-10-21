import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to **public** Flutter client environment variables.
///
/// Preferred names:
/// - [supabaseUrl] ← `SUPABASE_URL`
/// - [supabasePublishableKey] ← `SUPABASE_PUBLISHABLE_KEY`
///
/// Legacy fallback: `SUPABASE_ANON_KEY` (deprecated).
///
/// Never load `service_role`, DB passwords, JWT signing secrets, or tunnel
/// tokens into the Flutter client bundle.
abstract final class Env {
  /// Approved production / transitional API hosts (exact hostname match).
  ///
  /// - `api.ndmcore.com` — home mini-PC Supabase API gateway (intended target)
  /// - `ygidlcqhupmxvsdjmvnf.supabase.co` — legacy Cloud host (explicit only;
  ///   not a silent fallback if unset / unreachable)
  static const approvedApiHosts = <String>{
    'api.ndmcore.com',
    'ygidlcqhupmxvsdjmvnf.supabase.co',
  };

  /// Hostnames that look like Studio / admin UIs — never valid as client API.
  static const rejectedStudioHosts = <String>{
    'db.ndmcore.com',
    'db-stage.ndmcore.com',
  };

  /// Privileged keys that must never appear in Flutter dotenv.
  static const privilegedEnvKeys = <String>{
    'SUPABASE_DB_PASSWORD',
    'SUPABASE_SERVICE_ROLE_KEY',
    'SERVICE_ROLE_KEY',
    'SUPABASE_JWT_SECRET',
    'JWT_SECRET',
    'POSTGRES_PASSWORD',
    'DATABASE_URL',
    'SUPABASE_DB_URL',
    'CLOUDFLARED_TOKEN',
    'TUNNEL_TOKEN',
  };

  /// When true, loopback hosts are allowed for local Supabase stacks.
  static bool get allowDevelopmentEndpoints {
    final appEnv = (dotenv.env['APP_ENV'] ?? '').trim().toLowerCase();
    final flag = (dotenv.env['FX_ALLOW_DEV_ENDPOINTS'] ?? '')
        .trim()
        .toLowerCase();
    return appEnv == 'development' ||
        appEnv == 'dev' ||
        flag == '1' ||
        flag == 'true' ||
        flag == 'yes';
  }

  static String get supabaseUrl {
    assertNoPrivilegedSecretsInClientEnv();
    final value = dotenv.env['SUPABASE_URL'];
    if (value == null || value.isEmpty) {
      throw StateError('SUPABASE_URL is not set in client env');
    }
    return validateSupabaseApiUrl(
      value,
      allowDevelopmentEndpoints: allowDevelopmentEndpoints,
    );
  }

  static String get supabasePublishableKey {
    assertNoPrivilegedSecretsInClientEnv();
    final publishable = dotenv.env['SUPABASE_PUBLISHABLE_KEY'];
    if (publishable != null && publishable.isNotEmpty) {
      return publishable;
    }
    final legacy = dotenv.env['SUPABASE_ANON_KEY'];
    if (legacy != null && legacy.isNotEmpty) {
      return legacy;
    }
    throw StateError(
      'SUPABASE_PUBLISHABLE_KEY (or legacy SUPABASE_ANON_KEY) is not set',
    );
  }

  /// Hostname of the configured API URL (safe to log — not a secret).
  static String get supabaseApiHost {
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null || uri.host.isEmpty) {
      throw StateError('SUPABASE_URL is not a valid URL');
    }
    return uri.host;
  }

  /// Legacy alias used by settings UI. Prefer [supabaseApiHost].
  static String get supabaseProjectRef => supabaseApiHost;

  /// Fail closed if privileged secrets leaked into the client dotenv map.
  static void assertNoPrivilegedSecretsInClientEnv([
    Map<String, String>? env,
  ]) {
    final map = env ?? Map<String, String>.from(dotenv.env);
    final present = privilegedEnvKeys
        .where((k) => (map[k] ?? '').trim().isNotEmpty)
        .toList();
    if (present.isNotEmpty) {
      throw StateError(
        'Privileged secrets must not be loaded in Flutter client env: '
        '${present.join(', ')}. Use supabase/.env.migrations for server tools only.',
      );
    }
  }

  /// Pure URL validation for tests and tooling.
  static String validateSupabaseApiUrl(
    String value, {
    required bool allowDevelopmentEndpoints,
  }) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) {
      throw StateError('SUPABASE_URL is not a valid URL');
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw StateError('SUPABASE_URL must use http or https');
    }

    final host = uri.host.toLowerCase();

    if (host.contains('dincouture')) {
      throw StateError(
        'Forbidden legacy ERP/VPS Supabase host. Use https://api.ndmcore.com',
      );
    }

    if (rejectedStudioHosts.contains(host) ||
        host.startsWith('db.') ||
        host.contains('studio')) {
      throw StateError(
        'SUPABASE_URL must be the API gateway, not Studio/admin '
        '(rejected host: $host). Use https://api.ndmcore.com',
      );
    }

    if (approvedApiHosts.contains(host)) {
      if (host == 'api.ndmcore.com' && uri.scheme != 'https') {
        throw StateError('Home API https://api.ndmcore.com requires https');
      }
      return uri.toString();
    }

    final isLoopback = host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '10.0.2.2'; // Android emulator → host loopback
    if (isLoopback) {
      if (!allowDevelopmentEndpoints) {
        throw StateError(
          'Local Supabase endpoints require APP_ENV=development '
          'or FX_ALLOW_DEV_ENDPOINTS=true',
        );
      }
      return uri.toString();
    }

    throw StateError(
      'SUPABASE_URL host "$host" is not on the approved API allowlist. '
      'Approved: ${approvedApiHosts.join(', ')} '
      '(plus loopback in development mode only).',
    );
  }
}
