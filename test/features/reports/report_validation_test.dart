import 'package:bisindo_app/features/reports/domain/report.dart';
import 'package:flutter_test/flutter_test.dart';

/// REP-01: kategori "Lainnya" wajib keterangan ≥ 5 karakter; maks 1000.
void main() {
  test('Lainnya wajib ≥ 5 karakter', () {
    expect(validateReportDescription(ReportCategory.other, ''), isNotNull);
    expect(validateReportDescription(ReportCategory.other, ' abcd '), isNotNull);
    expect(validateReportDescription(ReportCategory.other, 'abcde'), isNull);
  });

  test('kategori lain: keterangan opsional; maksimal 1000', () {
    expect(validateReportDescription(ReportCategory.wrongSign, ''), isNull);
    expect(validateReportDescription(ReportCategory.wrongSign, 'a' * 1001), isNotNull);
  });

  test('target & kategori dipetakan ke nilai DB', () {
    expect(ReportTargetType.parse('sign')!.column, 'sign_id');
    expect(ReportTargetType.parse('lesson')!.column, 'lesson_id');
    expect(ReportTargetType.parse('x'), isNull);
    expect(ReportCategory.parse('wrong_meaning'), ReportCategory.wrongMeaning);
  });
}
