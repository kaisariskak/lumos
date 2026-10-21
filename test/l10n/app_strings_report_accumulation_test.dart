import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/l10n/app_strings.dart';

void main() {
  test('Russian report accumulation strings', () {
    final s = AppStrings.ru;
    expect(s.reportAddLabel, 'Добавить');
    expect(s.reportNoChanges, 'Нет новых данных');
    expect(s.reportResultPreview(18, 'стр.'), 'станет: 18 стр.');
  });

  test('Kazakh report accumulation strings', () {
    final s = AppStrings.kk;
    expect(s.reportAddLabel, 'Қосу');
    expect(s.reportNoChanges, 'Жаңа деректер жоқ');
    expect(s.reportResultPreview(18, 'бет'), 'болады: 18 бет');
  });
}
