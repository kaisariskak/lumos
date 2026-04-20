# Flutter Codebase PDF Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Подготовить подробную техническую PDF-документацию по Flutter-проекту `reportdeepen` с пофайловым разбором, картой вызовов и объяснением архитектуры для начинающего разработчика.

**Architecture:** Работа делится на четыре части: сначала собрать структуру проекта и поток запуска приложения, затем последовательно прочитать код по слоям и зафиксировать технические заметки, после этого собрать единый markdown-документ с формальной структурой, и в конце экспортировать его в PDF и проверить итоговый файл. Основной артефакт будет создаваться в `docs/`, чтобы документ остался рядом с кодовой базой и мог обновляться в будущем.

**Tech Stack:** Flutter, Dart, Markdown, PowerShell, локальная файловая система

---

## File Map

- Create: `docs/technical/flutter-codebase-documentation-ru.md` — основной текст технической документации.
- Create: `docs/technical/flutter-codebase-documentation-ru.pdf` — итоговый PDF.
- Modify: `docs/superpowers/specs/2026-04-17-flutter-codebase-pdf-documentation-design-ru.md` — только если во время исполнения потребуется зафиксировать уточнение структуры.
- Read: `lib/main.dart`, `lib/ibadat_app.dart` — точка входа и bootstrap.
- Read: `lib/authentication/auth_gate.dart` — основная развилка потока входа.
- Read: все файлы в `lib/models/` — модели данных.
- Read: все файлы в `lib/repositories/` — слой работы с данными.
- Read: все файлы в `lib/services/` — сервисный слой.
- Read: все файлы в `lib/screens/` — экранный слой.
- Read: все файлы в `lib/widgets/`, `lib/theme/`, `lib/l10n/`, `lib/utils/`, `lib/config/` — вспомогательные модули.
- Read: `pubspec.yaml` — стек и зависимости.

### Task 1: Собрать карту проекта и поток запуска

**Files:**
- Read: `pubspec.yaml`
- Read: `lib/main.dart`
- Read: `lib/ibadat_app.dart`
- Read: `lib/authentication/auth_gate.dart`
- Create: `docs/technical/flutter-codebase-documentation-ru.md`

- [ ] **Step 1: Зафиксировать структуру папок и зависимостей**

Run:

```powershell
rg --files lib test
Get-Content pubspec.yaml
```

Expected: список файлов проекта и перечень ключевых зависимостей (`supabase_flutter`, `google_sign_in`, `shared_preferences`, `app_links`, `crypto`).

- [ ] **Step 2: Прочитать точку входа приложения**

Run:

```powershell
Get-Content lib/main.dart
Get-Content lib/ibadat_app.dart
Get-Content lib/authentication/auth_gate.dart
```

Expected: понятен путь `main()` → `Supabase.initialize()` → deep links → `runApp(IbadatApp)` → `MaterialApp` → `AuthGate`.

- [ ] **Step 3: Написать стартовые разделы markdown-документа**

```markdown
# Техническая документация по Flutter-проекту reportdeepen

## 1. Введение

Этот документ описывает архитектуру Flutter-проекта `reportdeepen`, его слои, классы, функции, последовательность вызовов и связи между компонентами.

## 2. Стек технологий

- Flutter
- Dart
- Supabase
- Google Sign-In
- SharedPreferences
- App Links

## 3. Поток запуска приложения

1. В `main()` вызывается `WidgetsFlutterBinding.ensureInitialized()`.
2. Затем инициализируется Supabase.
3. После этого настраивается обработка OAuth redirect и deep link.
4. Далее вызывается `runApp(const IbadatApp())`.
5. `IbadatApp` создаёт `MaterialApp` и передаёт управление в `AuthGate`.
```

- [ ] **Step 4: Проверить, что стартовые разделы сохранены**

Run:

```powershell
Get-Content docs/technical/flutter-codebase-documentation-ru.md
```

Expected: в файле есть введение, стек и последовательность запуска.

- [ ] **Step 5: Commit**

```bash
git add docs/technical/flutter-codebase-documentation-ru.md
git commit -m "docs: add documentation skeleton for flutter codebase"
```

### Task 2: Разобрать инфраструктурные и базовые слои

**Files:**
- Read: `lib/config/app_config.dart`
- Read: `lib/theme/theme.dart`
- Read: `lib/theme/accent_provider.dart`
- Read: `lib/l10n/app_strings.dart`
- Read: `lib/l10n/locale_provider.dart`
- Read: `lib/services/pin_service.dart`
- Modify: `docs/technical/flutter-codebase-documentation-ru.md`

- [ ] **Step 1: Прочитать инфраструктурные файлы**

Run:

```powershell
Get-Content lib/config/app_config.dart
Get-Content lib/theme/theme.dart
Get-Content lib/theme/accent_provider.dart
Get-Content lib/l10n/app_strings.dart
Get-Content lib/l10n/locale_provider.dart
Get-Content lib/services/pin_service.dart
```

Expected: понятны глобальные настройки, тема, локализация и сервис PIN.

- [ ] **Step 2: Добавить в markdown разделы по базовой инфраструктуре**

```markdown
## 4. Базовая инфраструктура

### 4.1 `lib/config/app_config.dart`

- Назначение: хранит глобальные константы конфигурации.
- Основной объект: `AppConfig`.
- Что содержит: `googleWebClientId`.
- Кто использует: экран авторизации Google.

### 4.2 `lib/theme/accent_provider.dart`

- Назначение: управляет текущей акцентной темой приложения.
- Тип: singleton/provider-подобный объект.
- Кто вызывает: `IbadatApp`, экраны и виджеты, которым нужен текущий акцент.

### 4.3 `lib/l10n/locale_provider.dart`

- Назначение: хранит и меняет текущую локаль.
- Кто вызывает: `IbadatApp`.
- Что происходит: при изменении локали приложение перестраивается.

### 4.4 `lib/services/pin_service.dart`

- Назначение: локальная работа с PIN-кодом.
- Ответственность: сохранение, проверка, очистка, защита от перебора.
- Кто вызывает: `AuthGate` и `PinScreen`.
```

- [ ] **Step 3: Добавить технические пояснения по классам и методам**

Для каждого класса из этих файлов описать:

- все публичные поля;
- все публичные методы;
- что принимает метод;
- что возвращает метод;
- кто вызывает метод;
- что происходит дальше после вызова.

- [ ] **Step 4: Проверить сохранённый раздел**

Run:

```powershell
Get-Content docs/technical/flutter-codebase-documentation-ru.md
```

Expected: документ содержит структурированные разделы по `config`, `theme`, `l10n`, `services`.

- [ ] **Step 5: Commit**

```bash
git add docs/technical/flutter-codebase-documentation-ru.md
git commit -m "docs: describe infrastructure layers"
```

### Task 3: Разобрать модели и репозитории

**Files:**
- Read: `lib/models/*.dart`
- Read: `lib/repositories/*.dart`
- Modify: `docs/technical/flutter-codebase-documentation-ru.md`

- [ ] **Step 1: Прочитать модели**

Run:

```powershell
Get-ChildItem lib/models/*.dart | ForEach-Object { Get-Content $_.FullName }
```

Expected: понятны основные сущности проекта: профиль, группа, отчёт, платеж, период, invite-код и вспомогательные модели.

- [ ] **Step 2: Прочитать репозитории**

Run:

```powershell
Get-ChildItem lib/repositories/*.dart | ForEach-Object { Get-Content $_.FullName }
```

Expected: видно, как экранный слой получает данные из Supabase через репозитории.

- [ ] **Step 3: Добавить в документацию разделы по моделям**

```markdown
## 5. Модели данных

Для каждой модели описать:

- в каком файле объявлена;
- какие поля хранит;
- что означает каждое поле;
- какие фабричные методы и `toJson/fromJson` используются;
- какие экраны и репозитории используют эту модель.
```

- [ ] **Step 4: Добавить в документацию разделы по репозиториям**

```markdown
## 6. Репозитории

Для каждого репозитория описать:

- его назначение;
- с какой таблицей или сущностью он работает;
- какие публичные методы предоставляет;
- какие параметры принимают методы;
- какой результат возвращают методы;
- какие экраны или сервисы вызывают этот репозиторий.
```

- [ ] **Step 5: Commit**

```bash
git add docs/technical/flutter-codebase-documentation-ru.md
git commit -m "docs: describe models and repositories"
```

### Task 4: Разобрать экранный слой, виджеты и поток вызовов

**Files:**
- Read: `lib/screens/**/*.dart`
- Read: `lib/widgets/*.dart`
- Read: `lib/utils/*.dart`
- Modify: `docs/technical/flutter-codebase-documentation-ru.md`

- [ ] **Step 1: Прочитать экраны**

Run:

```powershell
Get-ChildItem lib/screens -Recurse *.dart | ForEach-Object { Get-Content $_.FullName }
```

Expected: понятны роли экранов `authorization`, `pin`, `invite_code`, `main_scaffold`, `home`, `report`, `payments`, `profile`, `admin`, `super_admin`, `detail`, `group_picker`.

- [ ] **Step 2: Прочитать переиспользуемые виджеты и утилиты**

Run:

```powershell
Get-Content lib/widgets/ring_indicator.dart
Get-Content lib/widgets/mini_bar_chart.dart
Get-Content lib/utils/week_utils.dart
```

Expected: понятны визуальные компоненты и вспомогательные функции.

- [ ] **Step 3: Добавить разделы по экранам**

```markdown
## 7. Экранный слой

Для каждого экрана описать:

- тип виджета (`StatelessWidget` или `StatefulWidget`);
- входные параметры конструктора;
- внутреннее состояние;
- какие репозитории, модели и сервисы использует экран;
- какие действия пользователя он обрабатывает;
- какой следующий экран или объект вызывается после ключевых событий.
```

- [ ] **Step 4: Добавить разделы по повторно используемым виджетам и последовательности вызовов**

```markdown
## 8. Переиспользуемые виджеты и утилиты

## 9. Последовательность вызовов

### 9.1 Запуск приложения
### 9.2 Вход через Google
### 9.3 Проверка PIN
### 9.4 Проверка invite-кода
### 9.5 Переход в `MainScaffold`
### 9.6 Навигация по основным вкладкам
```

- [ ] **Step 5: Commit**

```bash
git add docs/technical/flutter-codebase-documentation-ru.md
git commit -m "docs: describe screens widgets and call flow"
```

### Task 5: Справочные таблицы, финальная проверка и PDF

**Files:**
- Modify: `docs/technical/flutter-codebase-documentation-ru.md`
- Create: `docs/technical/flutter-codebase-documentation-ru.pdf`

- [ ] **Step 1: Добавить таблицы связей и словарь терминов**

```markdown
## 10. Таблицы связей

| Сущность | Файл | Назначение |
|---|---|---|

## 11. Словарь терминов

- `Widget` — базовый строительный блок интерфейса во Flutter.
- `StatefulWidget` — виджет, у которого есть изменяемое состояние.
- `Repository` — класс, который инкапсулирует доступ к данным.
- `Model` — объект данных.
- `Service` — класс с прикладной логикой вне UI.
```

- [ ] **Step 2: Проверить полноту документа**

Run:

```powershell
Get-Content docs/technical/flutter-codebase-documentation-ru.md
```

Expected: документ последовательно покрывает запуск приложения, слои, файлы, классы, методы, последовательность вызовов и словарь терминов.

- [ ] **Step 3: Экспортировать markdown в PDF**

Run one of the available commands:

```powershell
pandoc docs/technical/flutter-codebase-documentation-ru.md -o docs/technical/flutter-codebase-documentation-ru.pdf
```

или, если `pandoc` недоступен:

```powershell
@'
Add-Type -AssemblyName System.Web
$html = Get-Content "docs/technical/flutter-codebase-documentation-ru.md" -Raw
$html = "<html><body><pre style='font-family:Consolas,monospace;white-space:pre-wrap'>" + [System.Web.HttpUtility]::HtmlEncode($html) + "</pre></body></html>"
$html | Out-File "docs/technical/flutter-codebase-documentation-ru.html" -Encoding utf8
'@
```

Expected: создан PDF или промежуточный HTML для дальнейшей конвертации.

- [ ] **Step 4: Проверить итоговый артефакт**

Run:

```powershell
Get-ChildItem docs/technical
```

Expected: в папке есть итоговый `flutter-codebase-documentation-ru.pdf`.

- [ ] **Step 5: Commit**

```bash
git add docs/technical/flutter-codebase-documentation-ru.md docs/technical/flutter-codebase-documentation-ru.pdf
git commit -m "docs: add technical pdf documentation for flutter codebase"
```
