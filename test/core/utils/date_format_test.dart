import 'package:bisindo_app/core/utils/date_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('format tanggal Indonesia', () {
    final d = DateTime(2026, 10, 20, 14, 5);
    expect(formatDateId(d), '20 Oktober 2026');
    expect(formatDateTimeId(d), '20 Okt 2026, 14.05');
    expect(parseDate('2026-10-20T00:00:00Z'), isNotNull);
    expect(parseDate(42), isNull);
  });
}
