import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/utils/week_utils.dart';

void main() {
  test('formats month label in Russian when locale is Russian', () {
    expect(
      WeekUtils.monthLabel(7, 2026, languageCode: 'ru'),
      '\u0418\u044E\u043B\u044C 2026',
    );
  });

  test('keeps Kazakh month labels by default', () {
    expect(
      WeekUtils.monthLabel(7, 2026),
      '\u0428\u0456\u043B\u0434\u0435 2026',
    );
  });
}
