import 'package:accounts_manager/data/repositories/rate_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RateRepository.effectiveAtUtcIso', () {
    test('normalizes local datetime to UTC ISO', () {
      final local = DateTime(2026, 6, 10, 13, 49);
      final iso = RateRepository.effectiveAtUtcIso(local);
      expect(iso, local.toUtc().toIso8601String());
    });
  });

  group('RateEffectiveAtConflictException', () {
    test('has user-friendly message', () {
      expect(
        const RateEffectiveAtConflictException().toString(),
        RateEffectiveAtConflictException.message,
      );
    });
  });

  group('RateRepository._isMissingOptionalColumnError', () {
    test('detects missing rate_source column message', () {
      expect(
        RateRepository.isMissingOptionalColumnErrorForTest(
          message: "Could not find the 'rate_source' column",
        ),
        isTrue,
      );
    });

    test('does not treat duplicate key as missing column', () {
      expect(
        RateRepository.isMissingOptionalColumnErrorForTest(
          message: 'duplicate key value violates unique constraint',
        ),
        isFalse,
      );
    });
  });
}
