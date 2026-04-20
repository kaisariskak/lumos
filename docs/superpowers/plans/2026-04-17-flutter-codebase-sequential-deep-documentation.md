# Flutter Codebase Sequential Deep Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Подготовить один большой последовательный документ на русском языке, который подробно объясняет весь Flutter-код проекта `reportdeepen` в порядке выполнения приложения, с детальным разбором файлов, классов, методов, виджетов и логических блоков.

**Architecture:** Работа пойдёт от runtime-последовательности приложения к его внутренним слоям. Сначала будет собран и описан путь запуска `main.dart` → `IbadatApp` → `AuthGate`, затем будут разобраны экраны в порядке пользовательского сценария, после этого модели, репозитории, сервисы и вспомогательные слои. Итоговый документ будет единым и линейным, чтобы его можно было читать подряд как подробный путеводитель по коду.

**Tech Stack:** Flutter, Dart, Markdown, PowerShell, локальная файловая система

---

## File Map

- Create: `docs/technical/flutter-codebase-sequential-deep-documentation-ru.md` — основной большой документ.
- Optionally Create: `docs/technical/flutter-codebase-sequential-deep-documentation-ru.pdf` — PDF-версия после завершения markdown.
- Read: `lib/main.dart`, `lib/ibadat_app.dart`, `lib/authentication/auth_gate.dart`
- Read: `lib/screens/**/*.dart`
- Read: `lib/models/*.dart`
- Read: `lib/repositories/*.dart`
- Read: `lib/services/*.dart`
- Read: `lib/theme/*.dart`, `lib/l10n/*.dart`, `lib/config/*.dart`
- Read: `lib/widgets/*.dart`, `lib/utils/*.dart`

### Task 1: Сформировать линейный каркас документа по порядку выполнения приложения

**Files:**
- Read: `lib/main.dart`
- Read: `lib/ibadat_app.dart`
- Read: `lib/authentication/auth_gate.dart`
- Create: `docs/technical/flutter-codebase-sequential-deep-documentation-ru.md`

- [ ] **Step 1: Прочитать стартовые файлы**

Run:

```powershell
Get-Content lib/main.dart
Get-Content lib/ibadat_app.dart
Get-Content lib/authentication/auth_gate.dart
```

Expected: понятен стартовый путь приложения и главная развилка авторизации.

- [ ] **Step 2: Создать каркас документа**

```markdown
# Последовательный глубокий разбор Flutter-проекта reportdeepen

## 1. Как читать этот документ

Этот документ идёт в порядке выполнения приложения: от запуска до экранов, затем к данным и вспомогательным слоям.

## 2. Старт приложения

### 2.1 `main.dart`

### 2.2 `ibadat_app.dart`

### 2.3 `auth_gate.dart`
```

- [ ] **Step 3: Добавить правило разбора для каждого файла**

```markdown
Для каждого файла в этом документе будут описаны:

1. Общая роль файла в проекте.
2. Все классы и функции.
3. Последовательность вызовов.
4. Разбор ключевых строк и блоков кода.
5. Что происходит дальше после вызова.
```

- [ ] **Step 4: Проверить, что каркас сохранён**

Run:

```powershell
Get-Content docs/technical/flutter-codebase-sequential-deep-documentation-ru.md
```

Expected: в файле есть заголовок и стартовые разделы.

- [ ] **Step 5: Commit**

```bash
git add docs/technical/flutter-codebase-sequential-deep-documentation-ru.md
git commit -m "docs: add sequential deep documentation skeleton"
```

### Task 2: Подробно разобрать запуск приложения и стартовую маршрутизацию

**Files:**
- Read: `lib/main.dart`
- Read: `lib/ibadat_app.dart`
- Read: `lib/authentication/auth_gate.dart`
- Modify: `docs/technical/flutter-codebase-sequential-deep-documentation-ru.md`

- [ ] **Step 1: Выписать построчный разбор `main.dart`**

В документ нужно добавить:

```markdown
### `lib/main.dart`

Строка импорта `app_links` подключает механизм deep link.

Строка импорта `flutter/material.dart` нужна для доступа к Flutter binding и `runApp`.

Строка импорта `supabase_flutter.dart` подключает SDK Supabase.

Функция `main()` — это точка входа всего приложения.

Строка `WidgetsFlutterBinding.ensureInitialized();` принудительно инициализирует связь между Dart-кодом и движком Flutter до запуска асинхронной инициализации.

Без этой строки асинхронные вызовы, связанные с платформой, могли бы выполниться до готовности binding.
```

- [ ] **Step 2: Выписать подробный разбор `ibadat_app.dart`**

В документ нужно добавить:

```markdown
### `lib/ibadat_app.dart`

`IbadatApp` сделан `StatefulWidget`, потому что приложение должно перестраиваться при смене локали и акцента.

Метод `initState()` запускает `LocaleProvider.instance.init()` и `AccentProvider.instance.init()`.

Это означает, что до первого полноценного построения интерфейса приложение подтягивает пользовательские настройки из локального хранилища.

Метод `_rebuild()` — это маленький helper, который вызывает `setState()` после уведомления от provider-like объектов.
```

- [ ] **Step 3: Выписать подробный разбор `AuthGate`**

В документ нужно добавить:

```markdown
### `lib/authentication/auth_gate.dart`

`AuthGate` — это центральный маршрутизатор старта приложения.

Его задача не показать конкретный экран сразу, а определить текущее состояние пользователя:

- есть ли активная Supabase-сессия;
- установлен ли PIN;
- существует ли профиль;
- назначена ли группа;
- произошла ли ошибка загрузки.
```

- [ ] **Step 4: Проверить связность стартового раздела**

Run:

```powershell
Get-Content docs/technical/flutter-codebase-sequential-deep-documentation-ru.md
```

Expected: разделы по `main.dart`, `ibadat_app.dart` и `AuthGate` читаются как единый сценарий запуска.

- [ ] **Step 5: Commit**

```bash
git add docs/technical/flutter-codebase-sequential-deep-documentation-ru.md
git commit -m "docs: describe startup flow in sequence"
```

### Task 3: Подробно разобрать экранный слой в пользовательском порядке

**Files:**
- Read: `lib/screens/authorization/ibadat_authorization.dart`
- Read: `lib/screens/pin/pin_screen.dart`
- Read: `lib/screens/invite_code/invite_code_screen.dart`
- Read: `lib/screens/main_scaffold.dart`
- Read: `lib/screens/**/*.dart`
- Modify: `docs/technical/flutter-codebase-sequential-deep-documentation-ru.md`

- [ ] **Step 1: Описать первые экраны после старта**

В документ нужно добавить блоки:

```markdown
## 3. Первые экраны, которые может увидеть пользователь

### 3.1 `IbadatAuthorization`
### 3.2 `PinScreen`
### 3.3 `InviteCodeScreen`
```

Для каждого экрана указать:

- конструктор;
- параметры;
- поля состояния;
- действия пользователя;
- куда ведёт следующий вызов.

- [ ] **Step 2: Описать `MainScaffold` и навигационный shell**

В документ нужно добавить:

```markdown
## 4. Вход в основное приложение

### 4.1 `MainScaffold`

Этот файл является корневым shell для уже вошедшего пользователя.

Нужно отдельно объяснить:

- почему он `StatefulWidget`;
- зачем хранится `_tabIndex`;
- как подгружается текущая группа;
- как формируется `IndexedStack`;
- почему для `super_admin` путь другой.
```

- [ ] **Step 3: Описать остальные экраны в порядке реального перехода**

Последовательность разделов:

```markdown
### 4.2 `HomeScreen`
### 4.3 `DetailScreen`
### 4.4 `ReportEditorScreen`
### 4.5 `PaymentsScreen`
### 4.6 `MemberPaymentsScreen`
### 4.7 `AddPaymentDialog`
### 4.8 `ProfileScreen`
### 4.9 `GroupPickerScreen`
### 4.10 `AdminScreen`
### 4.11 `SuperAdminCodesScreen`
```

- [ ] **Step 4: Добавить явную карту переходов между экранами**

```markdown
## 5. Кто какой экран вызывает

`AuthGate` вызывает `IbadatAuthorization`, `PinScreen`, `InviteCodeScreen` или `MainScaffold`.

`MainScaffold` через вкладки приводит к `HomeScreen`, `ReportEditorScreen`, `PaymentsScreen`, `AdminScreen` или `ProfileScreen`.

`HomeScreen` открывает `DetailScreen`.

`PaymentsScreen` открывает `MemberPaymentsScreen`.

`MemberPaymentsScreen` открывает `AddPaymentDialog`.
```

- [ ] **Step 5: Commit**

```bash
git add docs/technical/flutter-codebase-sequential-deep-documentation-ru.md
git commit -m "docs: describe screens in user flow order"
```

### Task 4: Подробно разобрать модели, репозитории и сервисы

**Files:**
- Read: `lib/models/*.dart`
- Read: `lib/repositories/*.dart`
- Read: `lib/services/*.dart`
- Modify: `docs/technical/flutter-codebase-sequential-deep-documentation-ru.md`

- [ ] **Step 1: Добавить раздел по моделям**

```markdown
## 6. Модели данных

После экранов следует слой моделей, потому что именно эти объекты передаются между репозиториями и UI.
```

Для каждой модели описать:

- каждое поле;
- смысл каждого поля;
- `fromJson` и `toJson`;
- вычисляемые свойства;
- где модель используется.

- [ ] **Step 2: Добавить раздел по репозиториям**

```markdown
## 7. Репозитории

Репозиторий — это слой, который скрывает детали работы с Supabase и возвращает готовые модели в экранный слой.
```

Для каждого репозитория описать:

- каждый публичный метод;
- параметры метода;
- возвращаемое значение;
- какой экран его вызывает;
- что происходит после вызова.

- [ ] **Step 3: Добавить отдельный сверхподробный раздел по `PinService`**

```markdown
## 8. Сервисы

### 8.1 `PinService`

Нужно объяснить:

- зачем нужен сервис;
- почему PIN вынесен отдельно от UI;
- как работает `_hash`;
- как работают `hasPin`, `setPin`, `verifyPin`, `clearPin`;
- как `PinScreen` и `AuthGate` используют этот сервис.
```

- [ ] **Step 4: Проверить связность разделов данных**

Run:

```powershell
Get-Content docs/technical/flutter-codebase-sequential-deep-documentation-ru.md
```

Expected: разделы по моделям, репозиториям и сервисам логически продолжают объяснение экранов.

- [ ] **Step 5: Commit**

```bash
git add docs/technical/flutter-codebase-sequential-deep-documentation-ru.md
git commit -m "docs: describe models repositories and services in depth"
```

### Task 5: Подробно разобрать тему, локализацию, виджеты и утилиты

**Files:**
- Read: `lib/theme/*.dart`
- Read: `lib/l10n/*.dart`
- Read: `lib/config/*.dart`
- Read: `lib/widgets/*.dart`
- Read: `lib/utils/*.dart`
- Modify: `docs/technical/flutter-codebase-sequential-deep-documentation-ru.md`

- [ ] **Step 1: Добавить раздел по конфигу, теме и локализации**

```markdown
## 9. Глобальные слои приложения

### 9.1 `AppConfig`
### 9.2 `theme.dart`
### 9.3 `AccentProvider`
### 9.4 `AppStrings`
### 9.5 `LocaleProvider`
```

- [ ] **Step 2: Добавить раздел по повторно используемым виджетам**

```markdown
## 10. Переиспользуемые виджеты

### 10.1 `RingIndicator`
### 10.2 `CategoryRing`
### 10.3 `MiniBarChart`
```

Для каждого виджета описать:

- параметры конструктора;
- что он рисует;
- где используется;
- почему он вынесен в отдельный файл.

- [ ] **Step 3: Добавить раздел по утилитам**

```markdown
## 11. Утилиты

### 11.1 `WeekInfo`
### 11.2 `WeekUtils`
```

- [ ] **Step 4: Добавить финальный раздел “как читать проект дальше”**

```markdown
## 12. Как читать этот проект дальше

Если вы новичок, продолжайте изучение кода в таком порядке:

1. `main.dart`
2. `ibadat_app.dart`
3. `auth_gate.dart`
4. стартовые экраны
5. `main_scaffold.dart`
6. основные пользовательские экраны
7. модели
8. репозитории
9. сервисы
```

- [ ] **Step 5: Commit**

```bash
git add docs/technical/flutter-codebase-sequential-deep-documentation-ru.md
git commit -m "docs: finish sequential deep documentation"
```

### Task 6: Финальная проверка и при необходимости PDF

**Files:**
- Verify: `docs/technical/flutter-codebase-sequential-deep-documentation-ru.md`
- Optionally Create: `docs/technical/flutter-codebase-sequential-deep-documentation-ru.pdf`

- [ ] **Step 1: Проверить документ целиком**

Run:

```powershell
Get-Content docs/technical/flutter-codebase-sequential-deep-documentation-ru.md
```

Expected: документ читается как одно длинное последовательное объяснение проекта.

- [ ] **Step 2: Проверить, что покрыты все важные файлы**

Run:

```powershell
rg "^##|^###" docs/technical/flutter-codebase-sequential-deep-documentation-ru.md
```

Expected: есть разделы по запуску, экранам, моделям, репозиториям, сервисам, теме, локализации, виджетам и утилитам.

- [ ] **Step 3: При необходимости экспортировать в PDF**

Run:

```powershell
# Export path depends on available local toolchain
```

Expected: PDF создаётся только если пользователь отдельно подтвердит, что он нужен.

- [ ] **Step 4: Проверить артефакты**

Run:

```powershell
Get-ChildItem docs/technical
```

Expected: основной markdown-документ существует; PDF — только если экспорт выполнялся.

- [ ] **Step 5: Commit**

```bash
git add docs/technical/flutter-codebase-sequential-deep-documentation-ru.md
git commit -m "docs: verify sequential deep documentation artifacts"
```
