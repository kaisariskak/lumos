import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:reportdeepen/repositories/profile_repository.dart';
import 'package:reportdeepen/screens/authorization/ibadat_authorization.dart';

void main() {
  Future<void> neverCompleteSignIn(String login, String password) {
    return Completer<void>().future;
  }

  Finder inputInside(String key) {
    return find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(EditableText),
    );
  }

  Widget app() {
    return const MaterialApp(
      locale: Locale('ru'),
      supportedLocales: [Locale('ru')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: IbadatAuthorization(),
    );
  }

  Widget appWithSignIn(Future<void> Function(String, String) signIn) {
    return MaterialApp(
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: IbadatAuthorization(signInWithPassword: signIn),
    );
  }

  Widget appWithRegistration({
    required Future<void> Function(
      String login,
      String password,
      String nickname,
      String code,
    )
    register,
    Future<void> Function(String nickname, String code)? preflight,
    Future<void> Function()? rollback,
  }) {
    return MaterialApp(
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: IbadatAuthorization(
        registerWithPassword: register,
        preflightRegistration: preflight,
        rollbackFailedRegistration: rollback,
      ),
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

  testWidgets('registration shows a clear error when login is an email',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const ValueKey('auth-mode-toggle')));
    await tester.pumpAndSettle();

    await tester.enterText(inputInside('auth-login-field'), 'user@mail.com');
    await tester.pumpAndSettle();

    expect(find.text('user@mail.com'), findsOneWidget);
    final loginField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('auth-login-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(loginField.decoration?.errorText, 'Введите логин, не email');
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

  testWidgets('wrong invite code stays on registration form and shows code error',
      (tester) async {
    var rollbackCalled = false;

    await tester.pumpWidget(
      appWithRegistration(
        register: (_, _, _, _) async {
          throw const RegistrationException('invalid_code');
        },
        rollback: () async {
          rollbackCalled = true;
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('auth-mode-toggle')));
    await tester.pumpAndSettle();

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
      'BADCODE',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
    await tester.pump();
    await tester.pump();

    expect(rollbackCalled, isTrue);
    expect(find.byKey(const ValueKey('auth-nickname-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-code-field')), findsOneWidget);
    expect(find.text('Код не найден'), findsOneWidget);
  });

  testWidgets('wrong invite code is rejected before username sign-up',
      (tester) async {
    var signUpCalled = false;

    await tester.pumpWidget(
      appWithRegistration(
        preflight: (_, _) async {
          throw const RegistrationException('invalid_code');
        },
        register: (_, _, _, _) async {
          signUpCalled = true;
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('auth-mode-toggle')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('auth-login-field')),
      'kaiser',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'secret12',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-nickname-field')),
      'Kas',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-code-field')),
      'AM-FREE',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
    await tester.pump();
    await tester.pump();

    expect(signUpCalled, isFalse);
    expect(find.text('Код не найден'), findsOneWidget);
  });
}
