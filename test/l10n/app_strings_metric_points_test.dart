import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/l10n/app_strings.dart';

void main() {
  test('has Kazakh labels for metric point fields', () {
    expect(kkStrings.customCatMaxLabel, 'Апталық максимум:');
    expect(kkStrings.customCatScoringAmountLabel, 'Балл есептеу мөлшері');
    expect(
      kkStrings.customCatScoringAmountOptionalLabel,
      'Балл есептеу мөлшері (міндетті емес)',
    );
    expect(kkStrings.customCatPointsValueLabel, 'Осы мөлшер үшін балл');
  });
}
