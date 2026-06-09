import 'package:accounts_manager/core/utils/storage_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizeStorageFileName removes spaces and special chars', () {
    expect(
      sanitizeStorageFileName('Screenshot 2026-01-18 at 12.40.52 AM.png'),
      'Screenshot_2026-01-18_at_12.40.52_AM.png',
    );
  });

  test('sanitizeStorageFileName strips path segments', () {
    expect(sanitizeStorageFileName('/tmp/my file.pdf'), 'my_file.pdf');
  });

  test('sanitizeStoragePathSegment leaves UUIDs unchanged', () {
    const uuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
    expect(sanitizeStoragePathSegment(uuid), uuid);
  });

  test('full attachment key from screenshot filename has no spaces', () {
    const branchId = 'branch-uuid';
    const transactionId = 'txn-uuid';
    const original = 'Screenshot 2026-01-18 at 12.40.52 AM.png';
    final safeName = sanitizeStorageFileName(original);
    final path = '${sanitizeStoragePathSegment(branchId)}/${sanitizeStoragePathSegment(transactionId)}/1781045775209_$safeName';
    expect(path, contains('Screenshot_2026-01-18_at_12.40.52_AM.png'));
    expect(path, isNot(contains(' ')));
  });
}
