# Account Deletion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add App Store-compliant account deletion for regular users and admins through Flutter UI and a Supabase Edge Function.

**Architecture:** Flutter owns presentation, confirmation, local cleanup, and a typed call to the `delete-account` Edge Function. The Edge Function validates the user's JWT, blocks `super_admin`, deletes personal data with the service-role key, preserves shared group data, then deletes the Supabase Auth user.

**Tech Stack:** Flutter/Dart, Supabase Flutter, Supabase Edge Functions on Deno, TypeScript, Flutter test.

---

## File Structure

- Create: `lib/services/account_deletion_service.dart`
  - Typed deletion result, typed error codes, injected function caller/session reader for tests, production wrapper around `Supabase.instance.client.functions.invoke`.
- Modify: `lib/services/auth_logout_service.dart`
  - Add reusable local cleanup and a deletion-safe session finish method.
- Create: `lib/widgets/account_section.dart`
  - Shared account UI section, confirmation dialog, loading state, localized messages.
- Modify: `lib/screens/profile/profile_screen.dart`
  - Replace the standalone logout button with the shared account section.
- Modify: `lib/screens/admin/admin_screen.dart`
  - Replace `_buildLogoutButton()` usage for non-super-admin admin screens with the shared account section.
- Modify: `lib/l10n/app_strings.dart`
  - Add Russian and Kazakh strings for account deletion.
- Create: `supabase/functions/delete-account/index.ts`
  - Trusted deletion function using `SUPABASE_SERVICE_ROLE_KEY`.
- Create: `supabase/functions/delete-account/README.md`
  - Deployment notes and required environment variables.
- Create: `test/services/account_deletion_service_test.dart`
  - Pure unit tests for result mapping and success cleanup behavior.
- Modify: `test/services/auth_logout_service_test.dart`
  - Verify local cleanup hook order.
- Create: `test/widgets/account_section_test.dart`
  - Widget tests for destructive confirmation plus source-level screen wiring checks.
- Create: `test/supabase_delete_account_function_test.dart`
  - Source-level safety tests for function existence, service-role isolation, `super_admin` block, and delete ordering.

---

### Task 1: Account Deletion Service Model

**Files:**
- Create: `lib/services/account_deletion_service.dart`
- Test: `test/services/account_deletion_service_test.dart`

- [ ] **Step 1: Write failing tests for result parsing**

Create `test/services/account_deletion_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/services/account_deletion_service.dart';

void main() {
  group('AccountDeletionService', () {
    test('returns success and apple revoke flag from function response', () async {
      final calls = <String>[];
      final service = AccountDeletionService(
        currentAccessToken: () => 'jwt-1',
        invokeDeleteAccount: ({required accessToken}) async {
          calls.add(accessToken);
          return const AccountDeletionFunctionResponse(
            status: 200,
            body: {'ok': true, 'appleRevoked': false},
          );
        },
        localCleanup: () async => calls.add('cleanup'),
      );

      final result = await service.deleteAccount();

      expect(result.status, AccountDeletionStatus.deleted);
      expect(result.appleRevoked, isFalse);
      expect(calls, ['jwt-1', 'cleanup']);
    });

    test('returns noSession without calling function', () async {
      final service = AccountDeletionService(
        currentAccessToken: () => null,
        invokeDeleteAccount: ({required accessToken}) async {
          throw StateError('should not call function');
        },
        localCleanup: () async {},
      );

      final result = await service.deleteAccount();

      expect(result.status, AccountDeletionStatus.noSession);
    });

    test('maps super admin forbidden response', () async {
      final service = AccountDeletionService(
        currentAccessToken: () => 'jwt-1',
        invokeDeleteAccount: ({required accessToken}) async {
          return const AccountDeletionFunctionResponse(
            status: 403,
            body: {'ok': false, 'code': 'super_admin_forbidden'},
          );
        },
        localCleanup: () async => throw StateError('cleanup should not run'),
      );

      final result = await service.deleteAccount();

      expect(result.status, AccountDeletionStatus.superAdminForbidden);
    });

    test('maps group ownership blocked response', () async {
      final service = AccountDeletionService(
        currentAccessToken: () => 'jwt-1',
        invokeDeleteAccount: ({required accessToken}) async {
          return const AccountDeletionFunctionResponse(
            status: 409,
            body: {'ok': false, 'code': 'group_ownership_blocked'},
          );
        },
        localCleanup: () async => throw StateError('cleanup should not run'),
      );

      final result = await service.deleteAccount();

      expect(result.status, AccountDeletionStatus.groupOwnershipBlocked);
    });

    test('maps thrown function failure to retryable failure', () async {
      final service = AccountDeletionService(
        currentAccessToken: () => 'jwt-1',
        invokeDeleteAccount: ({required accessToken}) async {
          throw Exception('network down');
        },
        localCleanup: () async => throw StateError('cleanup should not run'),
      );

      final result = await service.deleteAccount();

      expect(result.status, AccountDeletionStatus.retryableFailure);
    });
  });
}
```

- [ ] **Step 2: Run service tests and verify failure**

Run:

```powershell
flutter test test/services/account_deletion_service_test.dart
```

Expected: FAIL because `AccountDeletionService` does not exist.

- [ ] **Step 3: Implement the service**

Create `lib/services/account_deletion_service.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_logout_service.dart';

enum AccountDeletionStatus {
  deleted,
  noSession,
  superAdminForbidden,
  groupOwnershipBlocked,
  retryableFailure,
  unknownFailure,
}

class AccountDeletionResult {
  final AccountDeletionStatus status;
  final bool appleRevoked;

  const AccountDeletionResult({
    required this.status,
    this.appleRevoked = false,
  });
}

class AccountDeletionFunctionResponse {
  final int status;
  final Map<String, dynamic>? body;

  const AccountDeletionFunctionResponse({
    required this.status,
    required this.body,
  });
}

typedef AccountDeletionTokenReader = String? Function();
typedef AccountDeletionFunctionInvoker = Future<AccountDeletionFunctionResponse>
    Function({required String accessToken});
typedef AccountDeletionCleanup = Future<void> Function();

class AccountDeletionService {
  final AccountDeletionTokenReader _currentAccessToken;
  final AccountDeletionFunctionInvoker _invokeDeleteAccount;
  final AccountDeletionCleanup _localCleanup;

  AccountDeletionService({
    AccountDeletionTokenReader? currentAccessToken,
    AccountDeletionFunctionInvoker? invokeDeleteAccount,
    AccountDeletionCleanup? localCleanup,
  })  : _currentAccessToken = currentAccessToken ??
            (() => Supabase.instance.client.auth.currentSession?.accessToken),
        _invokeDeleteAccount = invokeDeleteAccount ?? _invokeSupabaseFunction,
        _localCleanup =
            localCleanup ?? AuthLogoutService.finishDeletedAccountSession;

  Future<AccountDeletionResult> deleteAccount() async {
    final accessToken = _currentAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return const AccountDeletionResult(
        status: AccountDeletionStatus.noSession,
      );
    }

    AccountDeletionFunctionResponse response;
    try {
      response = await _invokeDeleteAccount(accessToken: accessToken);
    } catch (_) {
      return const AccountDeletionResult(
        status: AccountDeletionStatus.retryableFailure,
      );
    }

    final body = response.body;
    if (body?['ok'] == true) {
      await _localCleanup();
      return AccountDeletionResult(
        status: AccountDeletionStatus.deleted,
        appleRevoked: body?['appleRevoked'] == true,
      );
    }

    return AccountDeletionResult(
      status: _statusForCode(body?['code'] as String?),
    );
  }

  static AccountDeletionStatus _statusForCode(String? code) {
    return switch (code) {
      'no_session' => AccountDeletionStatus.noSession,
      'super_admin_forbidden' => AccountDeletionStatus.superAdminForbidden,
      'group_ownership_blocked' => AccountDeletionStatus.groupOwnershipBlocked,
      'function_unavailable' => AccountDeletionStatus.retryableFailure,
      _ => AccountDeletionStatus.unknownFailure,
    };
  }

  static Future<AccountDeletionFunctionResponse> _invokeSupabaseFunction({
    required String accessToken,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'delete-account',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final data = response.data;
    return AccountDeletionFunctionResponse(
      status: response.status,
      body: data is Map<String, dynamic> ? data : null,
    );
  }
}
```

- [ ] **Step 4: Run service tests and verify pass**

Run:

```powershell
flutter test test/services/account_deletion_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add -- lib/services/account_deletion_service.dart test/services/account_deletion_service_test.dart
git commit -m "feat: add account deletion service"
```

---

### Task 2: Shared Local Cleanup

**Files:**
- Modify: `lib/services/auth_logout_service.dart`
- Modify: `test/services/auth_logout_service_test.dart`

- [ ] **Step 1: Extend failing logout cleanup test**

Update `test/services/auth_logout_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/services/auth_logout_service.dart';

void main() {
  test('signs out from Supabase and Google provider', () async {
    final calls = <String>[];

    await AuthLogoutService.signOut(
      supabaseSignOut: () async => calls.add('supabase'),
      googleSignOut: () async => calls.add('google'),
      localCleanup: () async => calls.add('cleanup'),
    );

    expect(calls, ['cleanup', 'supabase', 'google']);
  });

  test('can run only local cleanup after server-side account deletion', () async {
    final calls = <String>[];

    await AuthLogoutService.clearLocalAccountState(
      clearPin: () async => calls.add('pin'),
    );

    expect(calls, ['pin']);
  });

  test('finishes deleted account session without surfacing provider failures', () async {
    final calls = <String>[];

    await AuthLogoutService.finishDeletedAccountSession(
      localCleanup: () async => calls.add('cleanup'),
      supabaseSignOut: () async => throw Exception('already deleted'),
      googleSignOut: () async => calls.add('google'),
    );

    expect(calls, ['cleanup', 'google']);
  });
}
```

- [ ] **Step 2: Run logout service test and verify failure**

Run:

```powershell
flutter test test/services/auth_logout_service_test.dart
```

Expected: FAIL because `localCleanup`, `clearLocalAccountState`, and `finishDeletedAccountSession` do not exist.

- [ ] **Step 3: Implement shared cleanup**

Update `lib/services/auth_logout_service.dart`:

```dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pin_service.dart';

typedef AsyncLogoutStep = Future<void> Function();

class AuthLogoutService {
  AuthLogoutService._();

  static Future<void> signOut({
    AsyncLogoutStep? supabaseSignOut,
    AsyncLogoutStep? googleSignOut,
    AsyncLogoutStep? localCleanup,
  }) async {
    await (localCleanup ?? clearLocalAccountState)();
    await (supabaseSignOut ?? Supabase.instance.client.auth.signOut)();
    await (googleSignOut ?? GoogleSignIn.instance.signOut)();
  }

  static Future<void> finishDeletedAccountSession({
    AsyncLogoutStep? localCleanup,
    AsyncLogoutStep? supabaseSignOut,
    AsyncLogoutStep? googleSignOut,
  }) async {
    await (localCleanup ?? clearLocalAccountState)();
    await _ignoreFailure(supabaseSignOut ?? Supabase.instance.client.auth.signOut);
    await _ignoreFailure(googleSignOut ?? GoogleSignIn.instance.signOut);
  }

  static Future<void> clearLocalAccountState({
    AsyncLogoutStep? clearPin,
  }) async {
    await (clearPin ?? PinService.clearPin)();
  }

  static Future<void> _ignoreFailure(AsyncLogoutStep step) async {
    try {
      await step();
    } catch (_) {
      // Account deletion already happened on the server; local navigation must continue.
    }
  }
}
```

- [ ] **Step 4: Run affected service tests**

Run:

```powershell
flutter test test/services/auth_logout_service_test.dart test/services/account_deletion_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add -- lib/services/auth_logout_service.dart test/services/auth_logout_service_test.dart
git commit -m "feat: share local account cleanup"
```

---

### Task 3: Localization Strings

**Files:**
- Modify: `lib/l10n/app_strings.dart`
- Create: `test/l10n/app_strings_account_deletion_test.dart`

- [ ] **Step 1: Write localization test**

Create `test/l10n/app_strings_account_deletion_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/l10n/app_strings.dart';

void main() {
  test('Russian account deletion strings are present', () {
    final s = AppStrings.ru;

    expect(s.accountSectionTitle, 'Аккаунт');
    expect(s.signOutOfAccount, 'Выйти из аккаунта');
    expect(s.deleteAccount, 'Удалить аккаунт');
    expect(s.deleteAccountTitle, 'Удалить аккаунт?');
    expect(
      s.deleteAccountBody,
      'Аккаунт и связанные с ним данные будут удалены без возможности восстановления.',
    );
    expect(s.deleteForever, 'Удалить навсегда');
    expect(s.deleteAccountAppleManualRevoke, contains('Apple ID'));
  });

  test('Kazakh account deletion strings are present', () {
    final s = AppStrings.kk;

    expect(s.accountSectionTitle, 'Аккаунт');
    expect(s.signOutOfAccount, 'Аккаунттан шығу');
    expect(s.deleteAccount, 'Аккаунтты жою');
    expect(s.deleteAccountTitle, 'Аккаунтты жою?');
    expect(s.deleteForever, 'Біржола жою');
    expect(s.deleteAccountAppleManualRevoke, contains('Apple ID'));
  });
}
```

- [ ] **Step 2: Run localization test and verify failure**

Run:

```powershell
flutter test test/l10n/app_strings_account_deletion_test.dart
```

Expected: FAIL because new string fields do not exist.

- [ ] **Step 3: Add fields to AppStrings**

In `lib/l10n/app_strings.dart`, add these fields after `logout`:

```dart
  final String accountSectionTitle;
  final String signOutOfAccount;
  final String deleteAccount;
  final String deleteAccountTitle;
  final String deleteAccountBody;
  final String deleteForever;
  final String deletingAccount;
  final String deleteAccountSuccess;
  final String deleteAccountNoSession;
  final String deleteAccountSuperAdminForbidden;
  final String deleteAccountGroupOwnershipBlocked;
  final String deleteAccountRetryableFailure;
  final String deleteAccountUnknownFailure;
  final String deleteAccountAppleManualRevoke;
```

Add matching required constructor parameters after `logout`.

Add public static getters near the top of `AppStrings` so tests can read both locales without building a widget tree:

```dart
  static AppStrings get kk => _kk;
  static AppStrings get ru => _ru;
```

Add Kazakh values to `_kk` after `logout: 'Шығу',`:

```dart
  accountSectionTitle: 'Аккаунт',
  signOutOfAccount: 'Аккаунттан шығу',
  deleteAccount: 'Аккаунтты жою',
  deleteAccountTitle: 'Аккаунтты жою?',
  deleteAccountBody:
      'Аккаунт және оған байланысты деректер қалпына келтіру мүмкіндігінсіз жойылады.',
  deleteForever: 'Біржола жою',
  deletingAccount: 'Аккаунт жойылуда...',
  deleteAccountSuccess: 'Аккаунт жойылды',
  deleteAccountNoSession: 'Сессия табылмады. Қайта кіріңіз.',
  deleteAccountSuperAdminForbidden:
      'Бұл рөл үшін аккаунтты жою қолжетімді емес.',
  deleteAccountGroupOwnershipBlocked:
      'Аккаунтты жою үшін алдымен топтарды басқа администраторға беріңіз.',
  deleteAccountRetryableFailure:
      'Аккаунтты жою мүмкін болмады. Кейін қайталап көріңіз.',
  deleteAccountUnknownFailure: 'Аккаунтты жою кезінде қате пайда болды.',
  deleteAccountAppleManualRevoke:
      'Apple арқылы кіру рұқсатын Apple ID баптауларынан қолмен қайтарып алуға болады.',
```

Add Russian values to `_ru` after `logout: 'Выйти',`:

```dart
  accountSectionTitle: 'Аккаунт',
  signOutOfAccount: 'Выйти из аккаунта',
  deleteAccount: 'Удалить аккаунт',
  deleteAccountTitle: 'Удалить аккаунт?',
  deleteAccountBody:
      'Аккаунт и связанные с ним данные будут удалены без возможности восстановления.',
  deleteForever: 'Удалить навсегда',
  deletingAccount: 'Удаляем аккаунт...',
  deleteAccountSuccess: 'Аккаунт удалён',
  deleteAccountNoSession: 'Сессия не найдена. Войдите снова.',
  deleteAccountSuperAdminForbidden:
      'Удаление аккаунта недоступно для этой роли.',
  deleteAccountGroupOwnershipBlocked:
      'Перед удалением аккаунта передайте группы другому администратору.',
  deleteAccountRetryableFailure:
      'Не удалось удалить аккаунт. Попробуйте позже.',
  deleteAccountUnknownFailure: 'При удалении аккаунта произошла ошибка.',
  deleteAccountAppleManualRevoke:
      'Доступ через Apple также можно отозвать вручную в настройках Apple ID.',
```

- [ ] **Step 4: Run localization test and verify pass**

Run:

```powershell
flutter test test/l10n/app_strings_account_deletion_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add -- lib/l10n/app_strings.dart test/l10n/app_strings_account_deletion_test.dart
git commit -m "feat: localize account deletion flow"
```

---

### Task 4: Shared Account Section Widget

**Files:**
- Create: `lib/widgets/account_section.dart`
- Create: `test/widgets/account_section_test.dart`

- [ ] **Step 1: Write widget tests**

Create `test/widgets/account_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/l10n/app_strings.dart';
import 'package:reportdeepen/services/account_deletion_service.dart';
import 'package:reportdeepen/widgets/account_section.dart';

void main() {
  testWidgets('shows account actions and confirms destructive delete', (tester) async {
    var logoutCount = 0;
    var deleteCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountSection(
            strings: AppStrings.ru,
            onLogout: () => logoutCount++,
            onDeleteAccount: () async {
              deleteCount++;
              return const AccountDeletionResult(
                status: AccountDeletionStatus.deleted,
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Аккаунт'), findsOneWidget);
    expect(find.text('Выйти из аккаунта'), findsOneWidget);
    expect(find.text('Удалить аккаунт'), findsOneWidget);

    await tester.tap(find.text('Выйти из аккаунта'));
    expect(logoutCount, 1);

    await tester.tap(find.text('Удалить аккаунт'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить аккаунт?'), findsOneWidget);
    expect(find.text('Удалить навсегда'), findsOneWidget);

    await tester.tap(find.text('Удалить навсегда'));
    await tester.pumpAndSettle();

    expect(deleteCount, 1);
  });

  testWidgets('keeps user signed in and shows blocked group message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountSection(
            strings: AppStrings.ru,
            onLogout: () {},
            onDeleteAccount: () async {
              return const AccountDeletionResult(
                status: AccountDeletionStatus.groupOwnershipBlocked,
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Удалить аккаунт'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить навсегда'));
    await tester.pumpAndSettle();

    expect(
      find.text('Перед удалением аккаунта передайте группы другому администратору.'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run widget test and verify failure**

Run:

```powershell
flutter test test/widgets/account_section_test.dart
```

Expected: FAIL because `AccountSection` does not exist.

- [ ] **Step 3: Implement AccountSection**

Create `lib/widgets/account_section.dart`:

```dart
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/account_deletion_service.dart';

class AccountSection extends StatefulWidget {
  final AppStrings strings;
  final VoidCallback onLogout;
  final Future<AccountDeletionResult> Function() onDeleteAccount;
  final VoidCallback? onDeleted;

  const AccountSection({
    super.key,
    required this.strings,
    required this.onLogout,
    required this.onDeleteAccount,
    this.onDeleted,
  });

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  bool _isDeleting = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.strings.deleteAccountTitle),
        content: Text(widget.strings.deleteAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(widget.strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: Text(widget.strings.deleteForever),
          ),
        ],
      ),
    );
    if (confirmed != true || _isDeleting) return;

    setState(() => _isDeleting = true);
    final result = await widget.onDeleteAccount();
    if (!mounted) return;
    setState(() => _isDeleting = false);
    _showResult(result);
  }

  void _showResult(AccountDeletionResult result) {
    final message = switch (result.status) {
      AccountDeletionStatus.deleted => result.appleRevoked
          ? widget.strings.deleteAccountSuccess
          : widget.strings.deleteAccountAppleManualRevoke,
      AccountDeletionStatus.noSession => widget.strings.deleteAccountNoSession,
      AccountDeletionStatus.superAdminForbidden =>
        widget.strings.deleteAccountSuperAdminForbidden,
      AccountDeletionStatus.groupOwnershipBlocked =>
        widget.strings.deleteAccountGroupOwnershipBlocked,
      AccountDeletionStatus.retryableFailure =>
        widget.strings.deleteAccountRetryableFailure,
      AccountDeletionStatus.unknownFailure =>
        widget.strings.deleteAccountUnknownFailure,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

    if (result.status == AccountDeletionStatus.deleted) {
      widget.onDeleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_circle_rounded,
                color: Color(0xFF94A3B8),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                widget.strings.accountSectionTitle,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isDeleting ? null : widget.onLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: Text(widget.strings.signOutOfAccount),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE2E8F0),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isDeleting ? null : _confirmDelete,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline, size: 18),
              label: Text(
                _isDeleting
                    ? widget.strings.deletingAccount
                    : widget.strings.deleteAccount,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                backgroundColor:
                    const Color(0xFFEF4444).withValues(alpha: 0.08),
                side: BorderSide(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run widget and service tests**

Run:

```powershell
flutter test test/widgets/account_section_test.dart test/services/account_deletion_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add -- lib/widgets/account_section.dart test/widgets/account_section_test.dart
git commit -m "feat: add shared account section"
```

---

### Task 5: Wire Account Section Into Profile and Admin

**Files:**
- Modify: `lib/screens/profile/profile_screen.dart`
- Modify: `lib/screens/admin/admin_screen.dart`
- Test: `test/widgets/account_section_test.dart`

- [ ] **Step 1: Add source tests for screen wiring**

Add `import 'dart:io';` at the top of `test/widgets/account_section_test.dart`, before Flutter imports. Then add this test inside the existing `main()` block:

```dart
  test('profile and admin screens use shared account section', () {
    final profileSource =
        File('lib/screens/profile/profile_screen.dart').readAsStringSync();
    final adminSource =
        File('lib/screens/admin/admin_screen.dart').readAsStringSync();

    expect(profileSource, contains('AccountSection('));
    expect(adminSource, contains('AccountSection('));
    expect(adminSource, contains('if (!widget.profile.isSuperAdmin)'));
  });
```

- [ ] **Step 2: Run wiring test and verify failure**

Run:

```powershell
flutter test test/widgets/account_section_test.dart
```

Expected: FAIL because the screens do not yet use `AccountSection`.

- [ ] **Step 3: Update ProfileScreen**

In `lib/screens/profile/profile_screen.dart`:

Add imports:

```dart
import '../../services/account_deletion_service.dart';
import '../../widgets/account_section.dart';
```

Add a service field inside `_ProfileScreenState`:

```dart
  final _accountDeletionService = AccountDeletionService();
```

Replace the existing standalone logout button with:

```dart
          AccountSection(
            strings: s,
            onLogout: widget.onLogout,
            onDeleteAccount: _accountDeletionService.deleteAccount,
          ),
```

- [ ] **Step 4: Update AdminScreen**

In `lib/screens/admin/admin_screen.dart`:

Add imports:

```dart
import '../../services/account_deletion_service.dart';
import '../../widgets/account_section.dart';
```

Add a service field inside `_AdminScreenState`:

```dart
  final _accountDeletionService = AccountDeletionService();
```

Replace `_buildLogoutButton()` body with:

```dart
  Widget _buildLogoutButton() {
    if (widget.profile.isSuperAdmin) {
      return const SizedBox.shrink();
    }
    return AccountSection(
      strings: S.of(context),
      onLogout: widget.onLogout,
      onDeleteAccount: _accountDeletionService.deleteAccount,
    );
  }
```

Keep existing calls to `_buildLogoutButton()` so layout changes stay small.

- [ ] **Step 5: Run analyze for changed Flutter files**

Run:

```powershell
flutter analyze --no-pub lib/services/account_deletion_service.dart lib/services/auth_logout_service.dart lib/widgets/account_section.dart lib/screens/profile/profile_screen.dart lib/screens/admin/admin_screen.dart lib/l10n/app_strings.dart
```

Expected: exits with code 0.

- [ ] **Step 6: Run affected tests**

Run:

```powershell
flutter test test/services/account_deletion_service_test.dart test/services/auth_logout_service_test.dart test/l10n/app_strings_account_deletion_test.dart test/widgets/account_section_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add -- lib/screens/profile/profile_screen.dart lib/screens/admin/admin_screen.dart test/widgets/account_section_test.dart
git commit -m "feat: show account section in profile and admin"
```

---

### Task 6: Supabase Edge Function

**Files:**
- Create: `supabase/functions/delete-account/index.ts`
- Create: `supabase/functions/delete-account/README.md`
- Create: `test/supabase_delete_account_function_test.dart`

- [ ] **Step 1: Write source-level safety test**

Create `test/supabase_delete_account_function_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delete-account edge function exists and uses service role only server-side', () {
    final file = File('supabase/functions/delete-account/index.ts');

    expect(file.existsSync(), isTrue);
    final source = file.readAsStringSync();

    expect(source, contains('SUPABASE_SERVICE_ROLE_KEY'));
    expect(source, contains('auth.getUser'));
    expect(source, contains("role === 'super_admin'"));
    expect(source, contains('group_ownership_blocked'));
    expect(source, contains('admin.deleteUser'));
    expect(
      source.indexOf('report_metric_values'),
      lessThan(source.indexOf('admin.deleteUser')),
    );
  });
}
```

- [ ] **Step 2: Run source-level test and verify failure**

Run:

```powershell
flutter test test/supabase_delete_account_function_test.dart
```

Expected: FAIL because the Edge Function does not exist.

- [ ] **Step 3: Implement Edge Function**

Create `supabase/functions/delete-account/index.ts`:

```ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type DeleteResponse = {
  ok: boolean;
  code?: string;
  appleRevoked?: boolean;
};

const json = (status: number, body: DeleteResponse) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
    },
  });

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return json(405, { ok: false, code: 'method_not_allowed' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json(500, { ok: false, code: 'function_unavailable' });
  }

  const authorization = req.headers.get('Authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) {
    return json(401, { ok: false, code: 'no_session' });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  const user = userData.user;
  if (userError || !user) {
    return json(401, { ok: false, code: 'no_session' });
  }

  const userId = user.id;

  const { data: profile, error: profileError } = await adminClient
    .from('ibadat_profiles')
    .select('id, role')
    .eq('id', userId)
    .maybeSingle();

  if (profileError) {
    console.error('profile load failed', profileError);
    return json(500, { ok: false, code: 'delete_failed' });
  }

  if (profile?.role === 'super_admin') {
    return json(403, { ok: false, code: 'super_admin_forbidden' });
  }

  const { data: ownedGroups, error: groupsError } = await adminClient
    .from('ibadat_groups')
    .select('id')
    .eq('admin_id', userId)
    .limit(1);

  if (groupsError) {
    console.error('owned group check failed', groupsError);
    return json(500, { ok: false, code: 'delete_failed' });
  }

  if ((ownedGroups ?? []).length > 0) {
    return json(409, { ok: false, code: 'group_ownership_blocked' });
  }

  const deleteStep = async (
    name: string,
    operation: PromiseLike<{ error: unknown }>,
  ) => {
    const { error } = await operation;
    if (error) {
      console.error(`${name} failed`, error);
      throw new Error(name);
    }
  };

  try {
    const { data: reports, error: reportsError } = await adminClient
      .from('ibadat_reports')
      .select('id')
      .eq('user_id', userId);

    if (reportsError) {
      console.error('report lookup failed', reportsError);
      return json(500, { ok: false, code: 'delete_failed' });
    }

    const reportIds = (reports ?? []).map((report) => report.id);
    if (reportIds.length > 0) {
      await deleteStep(
        'report_metric_values',
        adminClient
          .from('report_metric_values')
          .delete()
          .in('report_id', reportIds),
      );
    }

    await deleteStep(
      'ibadat_reports',
      adminClient.from('ibadat_reports').delete().eq('user_id', userId),
    );
    await deleteStep(
      'ibadat_member_settings',
      adminClient.from('ibadat_member_settings').delete().eq('profile_id', userId),
    );
    await deleteStep(
      'ibadat_payments',
      adminClient.from('ibadat_payments').delete().eq('profile_id', userId),
    );
    await deleteStep(
      'ibadat_periods',
      adminClient.from('ibadat_periods').delete().eq('created_by', userId),
    );
    await deleteStep(
      'group_metrics',
      adminClient.from('group_metrics').delete().eq('admin_id', userId),
    );
    await deleteStep(
      'ibadat_invite_codes',
      adminClient.from('ibadat_invite_codes').delete().eq('created_by', userId),
    );
    await deleteStep(
      'ibadat_groups.financier_id',
      adminClient
        .from('ibadat_groups')
        .update({ financier_id: null })
        .eq('financier_id', userId),
    );
    await deleteStep(
      'ibadat_profiles',
      adminClient.from('ibadat_profiles').delete().eq('id', userId),
    );

    const { error: deleteUserError } =
      await adminClient.auth.admin.deleteUser(userId);

    if (deleteUserError) {
      console.error('auth user delete failed', deleteUserError);
      return json(500, { ok: false, code: 'delete_failed' });
    }

    return json(200, { ok: true, appleRevoked: false });
  } catch (error) {
    console.error('account deletion failed', error);
    return json(500, { ok: false, code: 'delete_failed' });
  }
});
```

- [ ] **Step 4: Add deployment README**

Create `supabase/functions/delete-account/README.md`:

```markdown
# delete-account Edge Function

Deletes the currently authenticated regular user or admin account.

## Required Secrets

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Set secrets with:

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
```

Deploy with:

```bash
supabase functions deploy delete-account
```

## Client Contract

Call with `POST` and `Authorization: Bearer <current-user-jwt>`.

Success:

```json
{ "ok": true, "appleRevoked": false }
```

Blocked admin group ownership:

```json
{ "ok": false, "code": "group_ownership_blocked" }
```

`super_admin` accounts are rejected:

```json
{ "ok": false, "code": "super_admin_forbidden" }
```
```

- [ ] **Step 5: Run source-level test**

Run:

```powershell
flutter test test/supabase_delete_account_function_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add -- supabase/functions/delete-account/index.ts supabase/functions/delete-account/README.md test/supabase_delete_account_function_test.dart
git commit -m "feat: add delete account edge function"
```

---

### Task 7: Full Verification

**Files:**
- All files changed by Tasks 1-6.

- [ ] **Step 1: Run focused unit and widget tests**

Run:

```powershell
flutter test test/services/account_deletion_service_test.dart test/services/auth_logout_service_test.dart test/l10n/app_strings_account_deletion_test.dart test/widgets/account_section_test.dart test/supabase_delete_account_function_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run Flutter analyze**

Run:

```powershell
flutter analyze --no-pub lib/services/account_deletion_service.dart lib/services/auth_logout_service.dart lib/widgets/account_section.dart lib/screens/profile/profile_screen.dart lib/screens/admin/admin_screen.dart lib/l10n/app_strings.dart
```

Expected: exits with code 0 and no new issues.

- [ ] **Step 3: Run broader regression tests**

Run:

```powershell
flutter test
```

Expected: PASS. If an existing unrelated test fails, capture the failing test name, rerun the focused account-deletion tests, and report the unrelated failure separately.

- [ ] **Step 4: Manual Supabase verification with disposable users**

In a deployed Supabase project:

1. Deploy `delete-account`.
2. Create a disposable regular user and profile.
3. Create one report, member setting, and payment for that user.
4. Sign in as that user in the app and tap `Профиль` > `Удалить аккаунт` > `Удалить навсегда`.
5. Verify the app returns to sign-in.
6. Verify `auth.users` no longer contains that user.
7. Verify personal rows for that user are gone.
8. Verify other group members and group rows remain.
9. Repeat with an admin who owns no groups and verify deletion succeeds.
10. Repeat with an admin who owns a group and verify the UI shows the group transfer message.

- [ ] **Step 5: Final commit if verification changes any docs**

If Task 7 changes docs or tests, commit those changes:

```powershell
git add -- docs supabase test lib
git commit -m "test: verify account deletion flow"
```

If Task 7 does not change files, do not create an empty commit.

---

## Self-Review

- Spec coverage: UI account section, destructive confirmation, `super_admin` exclusion, Edge Function, service-role isolation, data deletion, shared group preservation, Apple no-token behavior, localization, and verification are covered by Tasks 1-7.
- Red-flag scan: This plan has no deferred implementation language and no task that asks for tests without concrete test code.
- Type consistency: `AccountDeletionService`, `AccountDeletionResult`, `AccountDeletionStatus`, `AccountSection`, and localization field names are introduced before later tasks use them.
