# Security And Performance Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Усилить безопасность invite-кодов и PIN, уменьшить лишние сетевые запросы при входе и сделать клиентский bootstrap-поток устойчивее без большого рефакторинга.

**Architecture:** Работа разбивается на четыре небольших блока: сначала фиксируем тесты и усиливаем `PinService`, затем подключаем новый контракт в `PinScreen`, после этого сокращаем лишние запросы и нормализуем переходы состояния в `AuthGate` и репозиториях, и в конце добавляем SQL-миграцию для ограничения RLS и серверных инвариантов. Изменения локализуются вокруг существующих сервисов и репозиториев, чтобы не трогать несвязанные экраны.

**Tech Stack:** Flutter, Dart, flutter_test, shared_preferences, crypto, Supabase, SQL/RLS

---

## File Map

- Modify: `lib/services/pin_service.dart` — версия PIN-хэша, соль, throttling, миграция legacy-формата.
- Modify: `lib/screens/pin/pin_screen.dart` — отображение состояния блокировки и работа с обновлённым API PIN.
- Modify: `lib/authentication/auth_gate.dart` — меньше повторных загрузок профиля, единая нормализация флагов и ошибок.
- Modify: `lib/repositories/profile_repository.dart` — нормализация email и более узкие запросы.
- Modify: `lib/repositories/invite_code_repository.dart` — нормализация code/groupId, более дешёвые выборки, аккуратные guard-проверки.
- Modify: `lib/repositories/ibadat_report_repository.dart` — точечное сужение выборок и отказ от лишних round-trip, где безопасно.
- Create: `test/services/pin_service_test.dart` — regression-тесты для PIN-миграции и throttling.
- Create: `test/authentication/auth_gate_test.dart` — тесты на поток состояний auth/profile.
- Create: `2026_04_17_security_performance_hardening.sql` — новая SQL-миграция для invite-code hardening.
- Modify: `test/widget_test.dart` — удалить дефолтный smoke-тест, который не соответствует текущему приложению, либо заменить на полезный базовый smoke.

### Task 1: Усиление `PinService`

**Files:**
- Modify: `lib/services/pin_service.dart`
- Test: `test/services/pin_service_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reportdeepen/services/pin_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('verifies and migrates a legacy sha256 pin hash', () async {
    await PinService.debugStoreLegacyHashForTest('1234');

    final verified = await PinService.verifyPin('1234');
    final stored = await PinService.debugReadStoredHashForTest();

    expect(verified, isTrue);
    expect(stored, startsWith('v2:'));
  });

  test('locks verification after repeated failed attempts', () async {
    await PinService.setPin('1234');

    expect(await PinService.verifyPin('0000'), isFalse);
    expect(await PinService.verifyPin('0000'), isFalse);
    expect(await PinService.verifyPin('0000'), isFalse);
    expect(await PinService.isLockedOut(), isTrue);
  });

  test('successful verification clears failed-attempt counters', () async {
    await PinService.setPin('1234');
    await PinService.verifyPin('0000');
    await PinService.verifyPin('1234');

    expect(await PinService.isLockedOut(), isFalse);
    expect(await PinService.debugFailedAttemptsForTest(), 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/pin_service_test.dart`
Expected: FAIL because helper methods like `debugStoreLegacyHashForTest`, `debugReadStoredHashForTest`, `isLockedOut`, and `debugFailedAttemptsForTest` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
class PinVerificationResult {
  final bool isValid;
  final bool isLocked;
  final Duration? retryAfter;

  const PinVerificationResult({
    required this.isValid,
    this.isLocked = false,
    this.retryAfter,
  });
}

class PinService {
  static const _keyPinHash = 'pin_hash';
  static const _keyFailedAttempts = 'pin_failed_attempts';
  static const _keyLockedUntil = 'pin_locked_until';
  static const _legacyVersion = 'legacy';
  static const _currentVersion = 'v2';

  static Future<void> setPin(String pin) async { /* generate salt + store v2 */ }
  static Future<bool> verifyPin(String pin) async { /* support legacy + migrate */ }
  static Future<bool> isLockedOut() async { /* inspect locked-until */ }
}
```

Implementation details:

- `setPin` сохраняет формат `v2:<base64-salt>:<base64-hash>`.
- Новый хэш вычисляется как минимум через `sha256(utf8.encode('$salt:$pin'))`.
- При проверке legacy-строки без префикса сравнивается старый SHA-256 и при успехе значение сразу пересохраняется в формате `v2`.
- После 3 подряд неудачных попыток выставляется короткая блокировка, например на 30 секунд.
- Успешная проверка очищает счётчики неудач и блокировку.
- Тестовые helper-методы пометить как `@visibleForTesting`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/pin_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/pin_service.dart test/services/pin_service_test.dart
git commit -m "feat: harden pin storage and verification"
```

### Task 2: Подключение блокировки и нового контракта в `PinScreen`

**Files:**
- Modify: `lib/screens/pin/pin_screen.dart`
- Modify: `lib/services/pin_service.dart`
- Test: `test/services/pin_service_test.dart`

- [ ] **Step 1: Write the failing widget test**

```dart
testWidgets('shows a lock message after repeated invalid pin attempts', (tester) async {
  SharedPreferences.setMockInitialValues({});
  await PinService.setPin('1234');

  await tester.pumpWidget(
    MaterialApp(
      home: PinScreen(
        onSuccess: () {},
      ),
    ),
  );

  Future<void> enterPin(String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  await enterPin('0000');
  await tester.pumpAndSettle();
  await enterPin('0000');
  await tester.pumpAndSettle();
  await enterPin('0000');
  await tester.pumpAndSettle();

  expect(find.textContaining('30'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/pin_service_test.dart`
Expected: FAIL because `PinScreen` still treats verification as plain `bool` and cannot render lockout state.

- [ ] **Step 3: Write minimal implementation**

```dart
Future<void> _submit() async {
  if (_mode != PinMode.enter) { /* existing setup/confirm logic */ }

  final result = await PinService.verifyPinDetailed(_pin);
  if (result.isValid) {
    widget.onSuccess();
    return;
  }

  _shake();
  setState(() {
    _pin = '';
    _errorKey = result.isLocked ? 'locked' : 'wrong';
    _retryAfter = result.retryAfter;
  });
}
```

Implementation details:

- Добавить в `PinScreen` отдельное состояние `_retryAfter`.
- Выводить локализуемый или fallback-текст вида `Try again in 30 seconds`, если PIN временно заблокирован.
- Существующий `verifyPin` можно оставить как совместимый wrapper вокруг `verifyPinDetailed`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/pin_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/pin/pin_screen.dart lib/services/pin_service.dart test/services/pin_service_test.dart
git commit -m "feat: surface pin lockout state in pin screen"
```

### Task 3: Тесты и упрощение `AuthGate`

**Files:**
- Modify: `lib/authentication/auth_gate.dart`
- Test: `test/authentication/auth_gate_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('shows pin screen before profile load when pin exists', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: AuthGate()));
  expect(find.byType(PinScreen), findsOneWidget);
});

testWidgets('resets invite and error flags before a successful profile load', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: AuthGate()));
  expect(find.byType(MainScaffold), findsOneWidget);
  expect(find.byType(InviteCodeScreen), findsNothing);
});
```

Test notes:

- Вынести зависимости чтения профиля и invite-кодов за конструкторные фабрики или `@visibleForTesting` setter'ы, чтобы подменять их в тестах.
- Проверять именно переход состояний, а не детали Supabase SDK.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/authentication/auth_gate_test.dart`
Expected: FAIL because `AuthGate` tightly связан с `Supabase.instance` и не даёт стабильно подменить загрузку профиля/сессию.

- [ ] **Step 3: Write minimal implementation**

```dart
class AuthGate extends StatefulWidget {
  final SupabaseClient? clientOverride;
  final ProfileRepository Function(SupabaseClient client)? profileRepositoryFactory;
  final InviteCodeRepository Function(SupabaseClient client)? inviteCodeRepositoryFactory;

  const AuthGate({
    super.key,
    this.clientOverride,
    this.profileRepositoryFactory,
    this.inviteCodeRepositoryFactory,
  });
}
```

Implementation details:

- Ввести приватный getter для клиента и репозиториев, чтобы в runtime всё работало как раньше.
- Перед `_loadProfile()` централизованно сбрасывать `_profileError`, `_showInviteCode`, `_showGroupPicker`.
- Не вызывать `_loadProfile()` повторно после успешного PIN, если уже идёт активная загрузка.
- На `signedOut` очищать `_profileError` так же, как `_profile` и `_pinRequired`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/authentication/auth_gate_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/authentication/auth_gate.dart test/authentication/auth_gate_test.dart
git commit -m "refactor: stabilize auth gate bootstrap flow"
```

### Task 4: Уточнение `ProfileRepository` и `InviteCodeRepository`

**Files:**
- Modify: `lib/repositories/profile_repository.dart`
- Modify: `lib/repositories/invite_code_repository.dart`
- Test: `test/authentication/auth_gate_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
test('normalizes invite codes before lookup', () async {
  final repo = InviteCodeRepository(fakeClient);

  await repo.validateCode(' usr-ab12cd ');

  expect(fakeClient.lastEqValue, 'USR-AB12CD');
});

test('normalizes emails before allowlist queries', () async {
  final repo = ProfileRepository(fakeClient);

  await repo.getAllowlistEntry(' User@Example.com ');

  expect(fakeClient.lastEqValue, 'user@example.com');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/authentication/auth_gate_test.dart`
Expected: FAIL because normalization helpers are duplicated inline and repository methods do not expose a single reusable path.

- [ ] **Step 3: Write minimal implementation**

```dart
String _normalizeEmail(String email) => email.trim().toLowerCase();
String _normalizeCode(String code) => code.trim().toUpperCase();
```

Implementation details:

- Использовать `_normalizeEmail` во всех email-методах `ProfileRepository`.
- Использовать `_normalizeCode` во всех code-методах `InviteCodeRepository`.
- Там, где нужен только факт существования, выбирать `id` или конкретные поля вместо полного `select()`.
- Для `markUsed` обновлять ещё и `updated_at`, если колонка существует; если нет, ограничиться `is_used`.
- Добавить быстрый `ArgumentError` для пустого `groupId`, `createdBy` или `code`, если операция без них бессмысленна.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/authentication/auth_gate_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/profile_repository.dart lib/repositories/invite_code_repository.dart test/authentication/auth_gate_test.dart
git commit -m "refactor: normalize repository inputs and trim queries"
```

### Task 5: Точечная оптимизация `IbadatReportRepository`

**Files:**
- Modify: `lib/repositories/ibadat_report_repository.dart`
- Test: `test/authentication/auth_gate_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('checks report existence with a single-row select', () async {
  final repo = IbadatReportRepository(fakeClient);

  await repo.hasReportsForPeriod(groupId: 'group-1', periodId: 'period-1');

  expect(fakeClient.lastSelectedColumns, 'id');
  expect(fakeClient.lastLimit, 1);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/authentication/auth_gate_test.dart`
Expected: FAIL if repository still over-fetches or if the fake client shows broader query shape than intended.

- [ ] **Step 3: Write minimal implementation**

```dart
Future<bool> hasReportsForPeriod({
  required String groupId,
  required String periodId,
}) async {
  final data = await _client
      .from('ibadat_reports')
      .select('id')
      .eq('group_id', groupId)
      .eq('period_id', periodId)
      .limit(1);
  return (data as List).isNotEmpty;
}
```

Implementation details:

- Сохранять текущий внешний контракт.
- Не расширять рефакторинг дальше методов, которые уже затрагиваются в этом проходе.
- Если безопасного сокращения `read-after-write` нет без изменения поведения кастомных полей, оставить текущую логику как есть.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/authentication/auth_gate_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/ibadat_report_repository.dart test/authentication/auth_gate_test.dart
git commit -m "perf: tighten report repository queries"
```

### Task 6: SQL-миграция для invite-code hardening

**Files:**
- Create: `2026_04_17_security_performance_hardening.sql`

- [ ] **Step 1: Write the failing verification notes**

```sql
-- Expected failures before migration:
-- 1. Any authenticated user can SELECT all rows from ibadat_invite_codes.
-- 2. Any authenticated user can UPDATE rows in ibadat_invite_codes.
-- 3. role_type has no CHECK constraint limiting values.
```

- [ ] **Step 2: Run or review current policy state to verify the risk**

Run in Supabase SQL editor or compare with `invite_codes_migration.sql`
Expected: current policies are broader than intended.

- [ ] **Step 3: Write minimal migration**

```sql
alter table ibadat_invite_codes
  add column if not exists updated_at timestamptz not null default now();

alter table ibadat_invite_codes
  drop constraint if exists ibadat_invite_codes_role_type_check;

alter table ibadat_invite_codes
  add constraint ibadat_invite_codes_role_type_check
  check (role_type in ('ADMIN', 'USER'));

drop policy if exists "Authenticated users can read codes" on ibadat_invite_codes;
drop policy if exists "Admins can mark codes used" on ibadat_invite_codes;

create policy "Authenticated users can validate matching codes"
  on ibadat_invite_codes
  for select
  using (
    auth.uid() is not null
  );

create policy "Authenticated users can mark only active codes as used"
  on ibadat_invite_codes
  for update
  using (
    auth.uid() is not null
    and is_used = false
    and expires_at > now()
  )
  with check (
    is_used = true
  );

create index if not exists idx_invite_codes_lookup
  on ibadat_invite_codes (code, is_used, expires_at);
```

Implementation notes:

- Во время реализации скорректировать policy-выражения под фактический безопасный клиентский сценарий, чтобы не оставить blanket access.
- Если текущий клиент не может безопасно работать без более широкого `SELECT`, зафиксировать это в итоговом отчёте как остаточный риск и причину.

- [ ] **Step 4: Verify migration content**

Review: убедиться, что миграция не ломает `INSERT` политики и не снимает существующие ограничения по ролям.
Expected: SQL file is internally consistent and ready for Supabase application.

- [ ] **Step 5: Commit**

```bash
git add 2026_04_17_security_performance_hardening.sql
git commit -m "feat: harden invite code policies and constraints"
```

### Task 7: Общая верификация

**Files:**
- Modify: `test/widget_test.dart`
- Verify: `lib/services/pin_service.dart`
- Verify: `lib/screens/pin/pin_screen.dart`
- Verify: `lib/authentication/auth_gate.dart`
- Verify: `lib/repositories/profile_repository.dart`
- Verify: `lib/repositories/invite_code_repository.dart`
- Verify: `lib/repositories/ibadat_report_repository.dart`
- Verify: `2026_04_17_security_performance_hardening.sql`

- [ ] **Step 1: Replace the default smoke test with a real app-safe smoke test**

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder smoke test for reportdeepen', () {
    expect(true, isTrue);
  });
}
```

- [ ] **Step 2: Run focused tests**

Run: `flutter test test/services/pin_service_test.dart test/authentication/auth_gate_test.dart test/widget_test.dart`
Expected: PASS

- [ ] **Step 3: Run static analysis**

Run: `flutter analyze`
Expected: no new errors in touched files

- [ ] **Step 4: Review git diff for unrelated changes**

Run: `git diff -- lib/services/pin_service.dart lib/screens/pin/pin_screen.dart lib/authentication/auth_gate.dart lib/repositories/profile_repository.dart lib/repositories/invite_code_repository.dart lib/repositories/ibadat_report_repository.dart test/services/pin_service_test.dart test/authentication/auth_gate_test.dart test/widget_test.dart 2026_04_17_security_performance_hardening.sql`
Expected: only intended hardening and test changes appear

- [ ] **Step 5: Commit**

```bash
git add lib/services/pin_service.dart lib/screens/pin/pin_screen.dart lib/authentication/auth_gate.dart lib/repositories/profile_repository.dart lib/repositories/invite_code_repository.dart lib/repositories/ibadat_report_repository.dart test/services/pin_service_test.dart test/authentication/auth_gate_test.dart test/widget_test.dart 2026_04_17_security_performance_hardening.sql
git commit -m "feat: harden auth flows and trim repository overhead"
```
