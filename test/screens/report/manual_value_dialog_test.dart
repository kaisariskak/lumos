import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/screens/report/manual_value_dialog.dart';

Widget _host(Widget dialog) {
  return MaterialApp(
    home: Scaffold(body: Builder(builder: (context) => dialog)),
  );
}

void main() {
  testWidgets('shows title, prefilled value, and hint with max/unit', (tester) async {
    await tester.pumpWidget(_host(
      Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => showDialog<int>(
            context: context,
            builder: (_) => const ManualValueDialog(
              current: 7,
              max: 10,
              unitLabel: 'стр.',
              color: Color(0xFF6366F1),
              title: 'Ввести значение',
              hint: 'Обычный диапазон: 0..10 стр.',
              saveLabel: 'Сохранить',
              cancelLabel: 'Отмена',
            ),
          ),
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Ввести значение'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Обычный диапазон: 0..10 стр.'), findsOneWidget);
  });

  testWidgets('save button is disabled when field is empty', (tester) async {
    await tester.pumpWidget(_host(
      Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => showDialog<int>(
            context: context,
            builder: (_) => const ManualValueDialog(
              current: 5,
              max: 10,
              unitLabel: 'раз',
              color: Color(0xFF6366F1),
              title: 'T',
              hint: 'H',
              saveLabel: 'Сохранить',
              cancelLabel: 'Отмена',
            ),
          ),
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    final saveBtn = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Сохранить'),
    );
    expect(saveBtn.onPressed, isNull);
  });

  testWidgets('returns entered integer via Navigator.pop', (tester) async {
    int? result;
    await tester.pumpWidget(_host(
      Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () async {
            result = await showDialog<int>(
              context: context,
              builder: (_) => const ManualValueDialog(
                current: 3,
                max: 10,
                unitLabel: 'раз',
                color: Color(0xFF6366F1),
                title: 'T',
                hint: 'H',
                saveLabel: 'Сохранить',
                cancelLabel: 'Отмена',
              ),
            );
          },
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Сохранить'));
    await tester.pumpAndSettle();

    expect(result, 123);
  });

  testWidgets('cancel returns null', (tester) async {
    int? result = -1;
    await tester.pumpWidget(_host(
      Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () async {
            result = await showDialog<int>(
              context: context,
              builder: (_) => const ManualValueDialog(
                current: 3,
                max: 10,
                unitLabel: 'раз',
                color: Color(0xFF6366F1),
                title: 'T',
                hint: 'H',
                saveLabel: 'Сохранить',
                cancelLabel: 'Отмена',
              ),
            );
          },
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
