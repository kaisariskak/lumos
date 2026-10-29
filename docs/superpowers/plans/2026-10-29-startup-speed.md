# Ускорение запуска — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Главный экран при повторном запуске показывается сразу из кэша; при первом — на ~0,6 с быстрее.

**Architecture:** Параллельные запросы в AuthGate, встроенные значения показателей в запросах отчётов, кэш стартовых данных (`StartupCache` на `SharedPreferences`) с показом из кэша и фоновым обновлением в AuthGate, MainScaffold и HomeScreen.

**Tech Stack:** Flutter/Dart, supabase_flutter, shared_preferences, flutter_test.

Спецификация: [2026-10-29-startup-speed-design-ru.md](../specs/2026-10-29-startup-speed-design-ru.md)

---

## Файлы

- Create: `lib/cache/startup_cache.dart`, `lib/cache/home_snapshot.dart`
- Modify: `lib/models/{ibadat_profile,ibadat_group,group_metric,ibadat_period,ibadat_report}.dart` — `toCacheJson()`
- Modify: `lib/repositories/ibadat_report_repository.dart` — встроенные значения
- Modify: `lib/services/auth_logout_service.dart` — очистка кэша
- Modify: `lib/authentication/auth_gate.dart`, `lib/screens/main_scaffold.dart`, `lib/screens/home/home_screen.dart`
- Tests: `test/cache/startup_cache_test.dart`, `test/models/cache_json_test.dart`, `test/cache/home_snapshot_test.dart`, `test/repositories/ibadat_report_repository_test.dart`, `test/services/auth_logout_service_test.dart`

---

### Task 1: Встроенные значения показателей в запросах отчётов

- [ ] Тест (в `ibadat_report_repository_test.dart`): `getReport` с данными, где есть `report_metric_values: [{metric_id, value}]`, возвращает значения и не вызывает `getMetricValues`; то же для `getGroupReports` без `getMetricValuesForReports`.
- [ ] Прогнать — FAIL.
- [ ] Реализация: в `IbadatReportRepository` функция `_embeddedMetricValues(data)` → `Map<String,int>?` (null, если ключа нет); `_hydrateReport` и `_hydrateReports` используют её и обращаются к store только для отчётов без встроенных данных. В `_SupabaseIbadatReportDataStore` у пяти запросов чтения `select()` → `select(_reportWithValues)`, где `_reportWithValues = '*, report_metric_values(metric_id, value)'`.
- [ ] Тесты — PASS. Commit.

### Task 2: `toCacheJson()` у моделей

- [ ] Тест `test/models/cache_json_test.dart`: для каждой из 5 моделей `fromJson(x.toCacheJson())` сохраняет все поля (даты UTC и «дата без времени» для периода, `metric_values` и `id` у отчёта, `color_value` у показателя).
- [ ] FAIL → реализация → PASS. Commit.

### Task 3: `StartupCache`

- [ ] Тест `test/cache/startup_cache_test.dart` (`SharedPreferences.setMockInitialValues({})`): write/read; другой userId → null; повреждённая строка → null; `clear()` удаляет только ключи кэша.
- [ ] FAIL → реализация (`read`, `write`, `clear`, префикс `startup_cache_v1:`) → PASS. Commit.

### Task 4: Снимок главного экрана

- [ ] Тест `test/cache/home_snapshot_test.dart`: `HomeUserSnapshot` и `HomeAdminSnapshot` туда-обратно через `toJson`/`fromJson`; `fromJson` на мусоре → null (`tryFromJson`).
- [ ] FAIL → реализация: `HomeUserSnapshot {groupId, members, metrics, periods, monthlyReports, trendReports}`, `HomeSectionSnapshot {group, members, metrics, periods, monthlyReports, trendReports}`, `HomeAdminSnapshot {sections, personalMetrics, personalPeriods, personalReport}`; `trendReports` — `Map<int, Map<String, IbadatReport>>`, ключи-месяцы в JSON строкой. → PASS. Commit.

### Task 5: Очистка кэша при выходе

- [ ] Тест в `auth_logout_service_test.dart`: `clearLocalAccountState(clearPin:…, clearStartupCache:…)` вызывает оба шага.
- [ ] FAIL → параметр `AsyncLogoutStep? clearStartupCache`, по умолчанию `StartupCache.clear` → PASS. Commit.

### Task 6: AuthGate — параллельные запросы и кэш

- [ ] `_fetchAuth(userId)`: `Future.wait([getProfile, getGroupsByAdminIds([userId])])` → `(IbadatProfile?, bool ownsGroup)`; ошибка проверки групп → `ownsGroup=false` (как сейчас).
- [ ] Чистые функции: `_normalize(profile, ownsGroup)`, `_bypassesPin(profile, ownsGroup) = !profile.isSuperAdmin && ownsGroup`.
- [ ] `_checkAuth`: `hasPin`; кэш `auth` → решение по кэшу, маршрут через `_applyProfile`, фоновый `_loadProfile()`; без кэша → `_fetchAuth`, решение о PIN, затем маршрут по уже полученному результату (без повторных запросов).
- [ ] `_loadProfile`: использует `_fetchAuth`, пишет кэш `auth`, если профиль найден; если `hasPin && !_bypassesPin && !_pinVerified` → `_pinRequired = true`.
- [ ] `_onPinSuccess` ставит `_pinVerified = true`; событие signedOut сбрасывает его.
- [ ] `flutter analyze` по файлу. Commit.

### Task 7: MainScaffold — группа из кэша

- [ ] `_loadGroup`: если `_group == null` и в кэше `group` с `id == currentGroupId` → `setState(_group, _isLoading=false)` до сетевого запроса; после запроса — запись кэша.
- [ ] Analyze. Commit.

### Task 8: HomeScreen — снимок

- [ ] `initState`: прочитать снимок; подходящий → заполнить состояние (период — последний), `_isLoading=false`.
- [ ] `_loadData`: индикатор только если данных нет.
- [ ] Выбор периода при обновлении: был последний → новый последний (участник и личные периоды админа).
- [ ] После `_loadUserReports` / `_loadAdminReports` — запись снимка.
- [ ] Analyze + полный `flutter test`. Commit.

### Task 9: Проверка на устройстве

- [ ] `flutter run --profile --dart-define=PERF_LOGS=true -d R5GL63KBQ6V`, войти, закрыть.
- [ ] `flutter logs`, открыть с иконки: главный экран сразу, индикатора нет; `[PERF]` — нет `getMetricValues` после `getReportByPeriod`; `getProfile` и `getGroupsByAdminIds` стартуют вместе.
- [ ] Выйти из аккаунта, войти: кэш не мешает, данные корректны.
