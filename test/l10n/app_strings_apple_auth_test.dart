import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/l10n/app_strings.dart';

void main() {
  testWidgets('Apple sign-in label is localized in Russian and Kazakh', (
    tester,
  ) async {
    Future<String> labelFor(Locale locale) async {
      late AppStrings strings;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('ru'), Locale('kk')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              strings = S.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return strings.signInApple;
    }

    expect(await labelFor(const Locale('ru')), 'Войти через Apple');
    expect(await labelFor(const Locale('kk')), 'Apple арқылы кіру');
  });
}
