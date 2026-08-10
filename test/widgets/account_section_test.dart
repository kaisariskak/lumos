import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/l10n/app_strings.dart';
import 'package:reportdeepen/services/account_deletion_service.dart';
import 'package:reportdeepen/widgets/account_section.dart';

void main() {
  test('profile and admin screens include account section wiring', () {
    final profileSource =
        File('lib/screens/profile/profile_screen.dart').readAsStringSync();
    final adminSource =
        File('lib/screens/admin/admin_screen.dart').readAsStringSync();

    expect(profileSource, contains('AccountSection('));
    expect(adminSource, contains('AccountSection('));
    expect(profileSource, contains('canDeleteAccount: !widget.profile.isSuperAdmin'));
    expect(adminSource, contains('canDeleteAccount: !widget.profile.isSuperAdmin'));
  });

  Widget buildSubject({
    VoidCallback? onLogout,
    Future<AccountDeletionResult> Function()? onDeleteAccount,
    AccountDeletionSessionFinisher? onFinishDeletedAccountSession,
    VoidCallback? onDeleted,
    bool canDeleteAccount = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AccountSection(
          strings: AppStrings.ru,
          onLogout: onLogout ?? () {},
          onDeleteAccount: onDeleteAccount ??
              () async => const AccountDeletionResult(
                    status: AccountDeletionStatus.retryableFailure,
                  ),
          onFinishDeletedAccountSession: onFinishDeletedAccountSession,
          onDeleted: onDeleted,
          canDeleteAccount: canDeleteAccount,
        ),
      ),
    );
  }

  testWidgets('shows account actions', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Аккаунт'), findsOneWidget);
    expect(find.text('Выйти из аккаунта'), findsOneWidget);
    expect(find.text('Удалить аккаунт'), findsOneWidget);
  });

  testWidgets('tapping sign out calls logout', (tester) async {
    var logoutCount = 0;

    await tester.pumpWidget(
      buildSubject(onLogout: () => logoutCount++),
    );

    await tester.tap(find.text('Выйти из аккаунта'));

    expect(logoutCount, 1);
  });

  testWidgets('can hide delete while keeping sign out', (tester) async {
    await tester.pumpWidget(buildSubject(canDeleteAccount: false));

    expect(find.text(AppStrings.ru.signOutOfAccount), findsOneWidget);
    expect(find.text(AppStrings.ru.deleteAccount), findsNothing);
  });

  testWidgets('tapping delete shows confirmation dialog', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Удалить аккаунт'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить аккаунт?'), findsOneWidget);
    expect(find.text('Удалить навсегда'), findsOneWidget);
  });

  testWidgets('confirming delete calls delete once', (tester) async {
    var deleteCount = 0;

    await tester.pumpWidget(
      buildSubject(
        onDeleteAccount: () async {
          deleteCount++;
          return const AccountDeletionResult(
            status: AccountDeletionStatus.retryableFailure,
          );
        },
      ),
    );

    await tester.tap(find.text('Удалить аккаунт'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить навсегда'));
    await tester.pumpAndSettle();

    expect(deleteCount, 1);
  });

  testWidgets(
    'group ownership blocked result shows message and does not call onDeleted',
    (tester) async {
      var deletedCount = 0;

      await tester.pumpWidget(
        buildSubject(
          onDeleteAccount: () async => const AccountDeletionResult(
            status: AccountDeletionStatus.groupOwnershipBlocked,
          ),
          onDeleted: () => deletedCount++,
        ),
      );

      await tester.tap(find.text('Удалить аккаунт'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить навсегда'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Перед удалением аккаунта передайте группы другому администратору.',
        ),
        findsOneWidget,
      );
      expect(deletedCount, 0);
    },
  );

  testWidgets(
    'deleted with apple revoke pending shows manual message and calls onDeleted',
    (tester) async {
      var deletedCount = 0;
      var finishCount = 0;

      await tester.pumpWidget(
        buildSubject(
          onDeleteAccount: () async => const AccountDeletionResult(
            status: AccountDeletionStatus.deleted,
            appleRevoked: false,
            showAppleManualRevokeNote: true,
          ),
          onDeleted: () => deletedCount++,
          onFinishDeletedAccountSession: () async => finishCount++,
        ),
      );

      await tester.tap(find.text('Удалить аккаунт'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить навсегда'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Доступ через Apple также можно отозвать вручную в настройках Apple ID.',
        ),
        findsOneWidget,
      );
      expect(deletedCount, 1);
      expect(finishCount, 0);

      await tester.pump(const Duration(milliseconds: 900));

      expect(finishCount, 1);
    },
  );

  testWidgets(
    'deleted non-Apple account does not show Apple manual revoke message',
    (tester) async {
      var deletedCount = 0;

      await tester.pumpWidget(
        buildSubject(
          onDeleteAccount: () async => const AccountDeletionResult(
            status: AccountDeletionStatus.deleted,
            appleRevoked: false,
          ),
          onDeleted: () => deletedCount++,
          onFinishDeletedAccountSession: () async {},
        ),
      );

      await tester.tap(find.text('РЈРґР°Р»РёС‚СЊ Р°РєРєР°СѓРЅС‚'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('РЈРґР°Р»РёС‚СЊ РЅР°РІСЃРµРіРґР°'));
      await tester.pumpAndSettle();

      expect(find.text('РђРєРєР°СѓРЅС‚ СѓРґР°Р»С‘РЅ'), findsOneWidget);
      expect(
        find.text(
          'Р”РѕСЃС‚СѓРї С‡РµСЂРµР· Apple С‚Р°РєР¶Рµ РјРѕР¶РЅРѕ РѕС‚РѕР·РІР°С‚СЊ РІСЂСѓС‡РЅСѓСЋ РІ РЅР°СЃС‚СЂРѕР№РєР°С… Apple ID.',
        ),
        findsNothing,
      );
      expect(deletedCount, 1);
    },
  );
}
