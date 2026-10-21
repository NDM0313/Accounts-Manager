import 'package:accounts_manager/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Env.validateSupabaseApiUrl', () {
    test('accepts home API https://api.ndmcore.com', () {
      final url = Env.validateSupabaseApiUrl(
        'https://api.ndmcore.com',
        allowDevelopmentEndpoints: false,
      );
      expect(url, 'https://api.ndmcore.com');
    });

    test('accepts legacy cloud host when explicitly configured', () {
      final url = Env.validateSupabaseApiUrl(
        'https://ygidlcqhupmxvsdjmvnf.supabase.co',
        allowDevelopmentEndpoints: false,
      );
      expect(url, 'https://ygidlcqhupmxvsdjmvnf.supabase.co');
    });

    test('rejects Studio db.ndmcore.com', () {
      expect(
        () => Env.validateSupabaseApiUrl(
          'https://db.ndmcore.com',
          allowDevelopmentEndpoints: false,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects db-stage Studio host', () {
      expect(
        () => Env.validateSupabaseApiUrl(
          'https://db-stage.ndmcore.com',
          allowDevelopmentEndpoints: false,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects unknown production host', () {
      expect(
        () => Env.validateSupabaseApiUrl(
          'https://evil.example.com',
          allowDevelopmentEndpoints: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects dincouture hosts', () {
      expect(
        () => Env.validateSupabaseApiUrl(
          'https://supabase.dincouture.pk',
          allowDevelopmentEndpoints: false,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects loopback without development mode', () {
      expect(
        () => Env.validateSupabaseApiUrl(
          'http://127.0.0.1:54321',
          allowDevelopmentEndpoints: false,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('allows loopback only in development mode', () {
      final url = Env.validateSupabaseApiUrl(
        'http://127.0.0.1:54321',
        allowDevelopmentEndpoints: true,
      );
      expect(url, 'http://127.0.0.1:54321');
    });

    test('rejects http for home API', () {
      expect(
        () => Env.validateSupabaseApiUrl(
          'http://api.ndmcore.com',
          allowDevelopmentEndpoints: false,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Env.assertNoPrivilegedSecretsInClientEnv', () {
    test('passes when only public keys present', () {
      expect(
        () => Env.assertNoPrivilegedSecretsInClientEnv({
          'SUPABASE_URL': 'https://api.ndmcore.com',
          'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_example',
        }),
        returnsNormally,
      );
    });

    test('fails closed when DB password present', () {
      expect(
        () => Env.assertNoPrivilegedSecretsInClientEnv({
          'SUPABASE_URL': 'https://api.ndmcore.com',
          'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_example',
          'SUPABASE_DB_PASSWORD': 'should-not-be-here',
        }),
        throwsA(isA<StateError>()),
      );
    });

    test('fails closed when service_role present', () {
      expect(
        () => Env.assertNoPrivilegedSecretsInClientEnv({
          'SUPABASE_SERVICE_ROLE_KEY': 'secret',
        }),
        throwsA(isA<StateError>()),
      );
    });
  });
}
