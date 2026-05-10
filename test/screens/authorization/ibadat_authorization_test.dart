import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/screens/authorization/ibadat_authorization.dart';

void main() {
  Future<void> neverCompleteSignIn(String login, String password) {
    return Completer<void>().future;
  }

  Widget app() {
    return const MaterialApp(
      locale: Locale('ru'),
      home: IbadatAuthorization(),
    );
  }

  Widget appWithSignIn(Future<void> Function(String, String) signIn) {
    return MaterialApp(
      locale: const Locale('ru'),
      home: IbadatAuthorization(signInWithPassword: signIn),
    );
  }

  testWidgets('starts in username password sign-in mode', (tester) async {
    await tester.pumpWidget(app());

    expect(find.byKey(const ValueKey('auth-login-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-password-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-nickname-field')), findsNothing);
    expect(find.byKey(const ValueKey('auth-code-field')), findsNothing);
    expect(find.byKey(const ValueKey('auth-google-button')), findsOneWidget);
  });

  testWidgets('switching to registration shows profile and invite fields',
      (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.byKey(const ValueKey('auth-mode-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-login-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-password-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-nickname-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-code-field')), findsOneWidget);
  });

  testWidgets('submit remains disabled until registration fields are valid',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const ValueKey('auth-mode-toggle')));
    await tester.pumpAndSettle();

    ElevatedButton submit() => tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('auth-submit-button')),
        );

    expect(submit().onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('auth-login-field')),
      'kaisar',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'secret12',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-nickname-field')),
      'Kaisar',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-code-field')),
      'ADM-AB12CD',
    );
    await tester.pump();

    expect(submit().onPressed, isNotNull);
  });

  testWidgets('password sign-in loading does not show Google loading state',
      (tester) async {
    await tester.pumpWidget(appWithSignIn(neverCompleteSignIn));

    await tester.enterText(
      find.byKey(const ValueKey('auth-login-field')),
      'kaisar',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'secret12',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
    await tester.pump();

    final googleButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('auth-google-button')),
    );

    expect(googleButton.onPressed, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('auth-google-button')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
  });
}
