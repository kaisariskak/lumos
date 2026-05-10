import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:reportdeepen/l10n/app_strings.dart';

void main() {
  testWidgets('has Kazakh labels for metric point fields', (tester) async {
    late AppStrings strings;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('kk'),
        home: Builder(
          builder: (context) {
            strings = S.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(strings.customCatMaxLabel, 'Апталық максимум:');
    expect(strings.customCatScoringAmountLabel, 'Балл есептеу мөлшері');
    expect(
      strings.customCatScoringAmountOptionalLabel,
      'Балл есептеу мөлшері (міндетті емес)',
    );
    expect(strings.customCatPointsValueLabel, 'Осы мөлшер үшін балл');
  });
}
