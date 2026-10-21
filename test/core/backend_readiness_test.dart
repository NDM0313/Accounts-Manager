import 'package:accounts_manager/core/config/backend_readiness.dart';
import 'package:accounts_manager/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home API gates money ops until FX_SCHEMA_READY', () {
    final r = BackendReadiness.evaluate(
      apiUrlOverride: 'https://api.ndmcore.com',
      schemaReadyOverride: '',
    );
    expect(r.apiHost, 'api.ndmcore.com');
    expect(r.blocksMoneyOperations, isTrue);
    expect(r.level, BackendReadinessLevel.homeApiAwaitingSchema);
  });

  test('legacy cloud is explicit and gated', () {
    final r = BackendReadiness.evaluate(
      apiUrlOverride: 'https://ygidlcqhupmxvsdjmvnf.supabase.co',
    );
    expect(r.level, BackendReadinessLevel.legacyCloudConfigured);
    expect(r.blocksMoneyOperations, isTrue);
  });

  test('FX_SCHEMA_READY ungates home API money ops flag', () {
    final r = BackendReadiness.evaluate(
      apiUrlOverride: 'https://api.ndmcore.com',
      schemaReadyOverride: 'true',
    );
    expect(r.blocksMoneyOperations, isFalse);
  });

  test('Env still rejects studio host', () {
    expect(
      () => Env.validateSupabaseApiUrl(
        'https://db.ndmcore.com',
        allowDevelopmentEndpoints: false,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
