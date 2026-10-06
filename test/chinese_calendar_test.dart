import 'package:flutter_test/flutter_test.dart';
import 'package:ligy_medical/core/utils/chinese_calendar.dart';

void main() {
  test('普通日子显示阴历日，初一显示月份', () {
    final day = chineseDayInfo(DateTime(2026, 10, 6));
    expect(day.label, '廿六');
    expect(day.isFestival, isFalse);
    expect(chineseDayInfo(DateTime(2026, 10, 10)).label, '九月');
  });

  test('节日与节气优先显示名称，传统节日优先于公历节日', () {
    expect(chineseDayInfo(DateTime(2026, 2, 17)).label, '春节');
    expect(chineseDayInfo(DateTime(2026, 10, 1)).label, '国庆节');
    expect(chineseDayInfo(DateTime(2026, 9, 25)).label, '中秋节');
    expect(chineseDayInfo(DateTime(2026, 4, 5)).isFestival, isTrue);
  });

  test('法定放假与调休上班', () {
    expect(chineseDayInfo(DateTime(2026, 10, 3)).offDay, isTrue);
    expect(chineseDayInfo(DateTime(2026, 10, 10)).offDay, isFalse);
    expect(chineseDayInfo(DateTime(2026, 2, 14)).offDay, isFalse);
    expect(chineseDayInfo(DateTime(2026, 10, 12)).offDay, isNull);
  });
}
