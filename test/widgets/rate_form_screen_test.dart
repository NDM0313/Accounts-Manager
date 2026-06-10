import 'package:accounts_manager/data/repositories/rate_repository.dart';
import 'package:accounts_manager/features/rates/rate_form_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RateFormMode.editVersion when rateId provided', () {
    const screen = RateFormScreen(rateId: 'abc');
    expect(screen.mode, RateFormMode.editVersion);
  });

  test('RateFormMode.duplicate when duplicateFromId provided', () {
    const screen = RateFormScreen(duplicateFromId: 'abc');
    expect(screen.mode, RateFormMode.duplicate);
  });

  test('RateFormMode.create for new rate', () {
    const screen = RateFormScreen();
    expect(screen.mode, RateFormMode.create);
  });

  test('edit and duplicate modes default effective time to now', () {
    expect(rateFormUsesNowForEffectiveAt(RateFormMode.editVersion), isTrue);
    expect(rateFormUsesNowForEffectiveAt(RateFormMode.duplicate), isTrue);
    expect(rateFormUsesNowForEffectiveAt(RateFormMode.create), isFalse);
  });

  test('conflict messages are user-friendly', () {
    expect(
      rateFormEffectiveAtConflictMessage,
      contains('already exists'),
    );
    expect(
      RateEffectiveAtConflictException.message,
      contains('already used'),
    );
  });
}