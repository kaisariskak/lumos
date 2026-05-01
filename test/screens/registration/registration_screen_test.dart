import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/screens/registration/registration_screen.dart';

void main() {
  testWidgets('submit button is disabled until both fields valid',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      // S.of(context) only reads Localizations.localeOf(context).languageCode,
      // so a plain MaterialApp with `locale` set is enough — no custom delegate.
      locale: const Locale('kk'),
      home: RegistrationScreen(
        onRegistered: (_) {},
        onLogout: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
      reason: 'button should be disabled with empty fields',
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'kaisar');
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
      reason: 'button still disabled — code missing',
    );

    await tester.enterText(fields.at(1), 'ADM-AB12CD');
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
      reason: 'button enabled when both fields valid',
    );
  });
}
