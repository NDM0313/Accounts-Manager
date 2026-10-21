import 'package:accounts_manager/core/config/client_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizeError redacts JWT-shaped tokens', () {
    const jwt =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.signature';
    final out = ClientConfig.sanitizeError('failed $jwt load');
    expect(out.contains('eyJ'), isFalse);
    expect(out.contains('[redacted]'), isTrue);
  });

  test('allowedKeys covers public client fields only', () {
    expect(ClientConfig.allowedKeys.contains('SUPABASE_URL'), isTrue);
    expect(ClientConfig.allowedKeys.contains('SUPABASE_PUBLISHABLE_KEY'), isTrue);
    expect(ClientConfig.allowedKeys.contains('SUPABASE_SERVICE_ROLE_KEY'), isFalse);
    expect(ClientConfig.allowedKeys.contains('POSTGRES_PASSWORD'), isFalse);
  });
}
