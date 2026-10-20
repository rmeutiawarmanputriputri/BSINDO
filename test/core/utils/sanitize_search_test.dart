import 'package:bisindo_app/core/utils/sanitize_search.dart';
import 'package:bisindo_app/core/utils/uuid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DICT-01 escape ilike', () {
    test('% _ \\ di-escape sehingga tidak menjadi wildcard', () {
      expect(escapeLike('50%'), r'50\%');
      expect(escapeLike('a_b'), r'a\_b');
      expect(escapeLike(r'c\d'), r'c\\d');
      expect(containsPattern('  Halo_%  '), r'%halo\_\%%');
    });

    test('dipotong 80 karakter dan dinormalisasi', () {
      final long = 'A' * 100;
      expect(normalizeSearch(long).length, kMaxSearchLength);
      expect(normalizeSearch('  TeRiMa KaSiH '), 'terima kasih');
    });
  });

  group('uuid', () {
    test('uuidV4 valid & unik', () {
      final a = uuidV4();
      final b = uuidV4();
      expect(isUuid(a), isTrue);
      expect(a, isNot(b));
      expect(a[14], '4');
    });

    test('isUuid menolak input tidak valid', () {
      expect(isUuid(null), isFalse);
      expect(isUuid('new'), isFalse);
      expect(isUuid('../../etc'), isFalse);
      expect(isUuid('aaaaaaaa-0000-0000-0000-00000000000a'), isTrue);
    });
  });
}
