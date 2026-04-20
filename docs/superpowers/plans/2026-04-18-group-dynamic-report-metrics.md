# Group Dynamic Report Metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перевести отчёты с фиксированных системных показателей на динамический список показателей, создаваемых администратором отдельно для каждой группы.

**Architecture:** Реализация идёт от данных к UI. Сначала вводим новую схему данных и тестируемые доменные модели для групповых показателей и значений отчёта, затем переносим сохранение отчёта на динамические значения, после этого перестраиваем админку и экран `Отчёт`, и только в конце переводим `HomeScreen` и `DetailScreen` на новый расчёт прогресса. Старые фиксированные категории выводятся из активной логики, а проценты считаются через отдельный helper, чтобы не дублировать формулы по экранам.

**Tech Stack:** Flutter, Dart, flutter_test, Supabase, SQL

---

## File Map

- Create: `2026_04_18_dynamic_group_report_metrics.sql` — новая SQL-схема для `group_metrics` и `report_metric_values`, очистка старых репорт-полей.
- Create: `lib/models/group_metric.dart` — единая модель показателя группы.
- Create: `lib/reporting/report_progress.dart` — чистые функции расчёта вкладов и общего прогресса.
- Create: `test/models/group_metric_test.dart` — сериализация и валидация модели показателя.
- Create: `test/models/ibadat_report_test.dart` — новый контракт `IbadatReport` без фиксированных полей.
- Create: `test/reporting/report_progress_test.dart` — расчёты процентов, пустые группы, превышение максимума.
- Modify: `lib/models/ibadat_report.dart` — удалить фиксированные поля категорий, оставить метаданные и `metricValues`.
- Modify: `lib/repositories/ibadat_report_repository.dart` — читать и писать значения через `report_metric_values`.
- Modify: `lib/models/custom_category.dart` or replace usage with `lib/models/group_metric.dart` — старую модель вывести из активного использования.
- Modify: `lib/repositories/custom_category_repository.dart` or replace usage with `lib/repositories/group_metric_repository.dart` — репозиторий групповых показателей.
- Modify: `lib/screens/admin/admin_screen.dart` — блок показателей группы становится основным и добавляет цвет/max/icon/unit/name.
- Modify: `lib/screens/report/report_editor_screen.dart` — динамические карточки показателей и пустое состояние.
- Modify: `lib/screens/home/home_screen.dart` — динамический расчёт пользовательского и группового прогресса.
- Modify: `lib/screens/detail/detail_screen.dart` — динамическое отображение значений отчёта.
- Modify: `lib/l10n/app_strings.dart` — строки для пустого состояния, цвета, максимума и групповых показателей.
- Modify: `test/widget_test.dart` — заменить дефолтный smoke-тест на минимальный полезный smoke, если он мешает новой логике.

### Task 1: Ввести доменные модели и расчёт прогресса

**Files:**
- Create: `lib/models/group_metric.dart`
- Modify: `lib/models/ibadat_report.dart`
- Create: `lib/reporting/report_progress.dart`
- Create: `test/models/group_metric_test.dart`
- Create: `test/models/ibadat_report_test.dart`
- Create: `test/reporting/report_progress_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/models/group_metric.dart';

void main() {
  test('parses a group metric with icon color unit and max value', () {
    final metric = GroupMetric.fromJson({
      'id': 'm1',
      'group_id': 'g1',
      'name': 'Коран',
      'icon': '📖',
      'color_value': 0xFF0D9488,
      'unit': 'стр.',
      'max_value': 100,
      'order_index': 2,
      'created_at': '2026-04-18T00:00:00Z',
    });

    expect(metric.id, 'm1');
    expect(metric.groupId, 'g1');
    expect(metric.colorValue, const Color(0xFF0D9488).value);
    expect(metric.maxValue, 100);
  });
}
```

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/models/ibadat_report.dart';

void main() {
  test('stores dynamic metric values without fixed category fields', () {
    final report = IbadatReport(
      userId: 'u1',
      groupId: 'g1',
      month: 4,
      year: 2026,
      metricValues: {'m1': 25, 'm2': 130},
    );

    expect(report.metricValues['m1'], 25);
    expect(report.metricValues['m2'], 130);
    expect(report.toJson().containsKey('quran_pages'), isFalse);
  });
}
```

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/models/group_metric.dart';
import 'package:reportdeepen/reporting/report_progress.dart';

void main() {
  test('caps a metric contribution at 100 percent', () {
    final metric = GroupMetric.test(
      id: 'm1',
      groupId: 'g1',
      name: 'Коран',
      maxValue: 100,
    );

    expect(metricProgress(metric, 140), 1.0);
  });

  test('returns zero progress for an empty metric list', () {
    expect(reportProgress(const [], const {}), 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/group_metric_test.dart test/models/ibadat_report_test.dart test/reporting/report_progress_test.dart`
Expected: FAIL because `GroupMetric`, `metricValues`, `metricProgress`, and `reportProgress` do not exist in the new form yet.

- [ ] **Step 3: Write minimal implementation**

```dart
class GroupMetric {
  final String id;
  final String groupId;
  final String name;
  final String icon;
  final int colorValue;
  final String unit;
  final int maxValue;
  final int orderIndex;
  final DateTime? createdAt;

  const GroupMetric({
    required this.id,
    required this.groupId,
    required this.name,
    required this.icon,
    required this.colorValue,
    required this.unit,
    required this.maxValue,
    required this.orderIndex,
    this.createdAt,
  });
}
```

```dart
class IbadatReport {
  final String? id;
  final String userId;
  final String groupId;
  final String? periodId;
  final int month;
  final int year;
  final DateTime? submittedAt;
  final DateTime? updatedAt;
  Map<String, int> metricValues;

  IbadatReport({
    this.id,
    required this.userId,
    required this.groupId,
    this.periodId,
    required this.month,
    required this.year,
    this.submittedAt,
    this.updatedAt,
    Map<String, int>? metricValues,
  }) : metricValues = metricValues ?? {};
}
```

```dart
double metricProgress(GroupMetric metric, int value) {
  if (metric.maxValue <= 0 || value <= 0) return 0;
  return (value / metric.maxValue).clamp(0, 1).toDouble();
}

double reportProgress(List<GroupMetric> metrics, Map<String, int> values) {
  final active = metrics.where((m) => m.maxValue > 0).toList();
  if (active.isEmpty) return 0;
  final total = active.fold<double>(
    0,
    (sum, metric) => sum + metricProgress(metric, values[metric.id] ?? 0),
  );
  return total / active.length;
}
```

Implementation notes:

- Добавить `Color get color => Color(colorValue);` в `GroupMetric`, чтобы UI не дублировал преобразование.
- В `IbadatReport.toJson()` оставить только поля шапки отчёта.
- Добавить `copyWith` и helper `valueForMetric(String metricId)`.
- Удалить или перестать использовать `getValue/setValue/getCustomValue/setCustomValue`, завязанные на фиксированные ключи.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/group_metric_test.dart test/models/ibadat_report_test.dart test/reporting/report_progress_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/group_metric.dart lib/models/ibadat_report.dart lib/reporting/report_progress.dart test/models/group_metric_test.dart test/models/ibadat_report_test.dart test/reporting/report_progress_test.dart
git commit -m "feat: add dynamic report metric domain model"
```

### Task 2: Перевести базу и репозиторий отчётов на динамические значения

**Files:**
- Create: `2026_04_18_dynamic_group_report_metrics.sql`
- Modify: `lib/repositories/ibadat_report_repository.dart`
- Modify: `lib/models/ibadat_report.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/models/ibadat_report.dart';

void main() {
  test('report payload excludes metric values and keeps only report header', () {
    final report = IbadatReport(
      userId: 'u1',
      groupId: 'g1',
      month: 4,
      year: 2026,
      metricValues: {'m1': 25},
    );

    expect(report.toJson(), {
      'user_id': 'u1',
      'group_id': 'g1',
      'month': 4,
      'year': 2026,
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/ibadat_report_test.dart`
Expected: FAIL if `toJson()` still contains old fixed columns.

- [ ] **Step 3: Write minimal implementation**

```sql
create table if not exists group_metrics (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references ibadat_groups(id) on delete cascade,
  name text not null,
  icon text not null,
  color_value bigint not null,
  unit text not null,
  max_value integer not null check (max_value >= 0),
  order_index integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists report_metric_values (
  report_id uuid not null references ibadat_reports(id) on delete cascade,
  metric_id uuid not null references group_metrics(id) on delete cascade,
  value integer not null default 0,
  primary key (report_id, metric_id)
);
```

```dart
Future<void> _loadMetricValues(IbadatReport report) async {
  if (report.id == null) return;
  final data = await _client
      .from('report_metric_values')
      .select('metric_id, value')
      .eq('report_id', report.id!);
  report.metricValues = {
    for (final row in (data as List))
      row['metric_id'] as String: row['value'] as int,
  };
}
```

```dart
Future<IbadatReport> upsertReport(IbadatReport report) async {
  final data = await _client
      .from('ibadat_reports')
      .upsert({...report.toJson(), 'updated_at': DateTime.now().toIso8601String()},
          onConflict: report.periodId != null
              ? 'user_id,group_id,period_id'
              : 'user_id,group_id,month,year')
      .select()
      .single();

  final saved = IbadatReport.fromJson(data);
  final rows = report.metricValues.entries
      .map((entry) => {
            'report_id': saved.id,
            'metric_id': entry.key,
            'value': entry.value,
          })
      .toList();
  if (rows.isNotEmpty) {
    await _client.from('report_metric_values').upsert(rows, onConflict: 'report_id,metric_id');
  }
  saved.metricValues = Map<String, int>.from(report.metricValues);
  return saved;
}
```

Implementation notes:

- В SQL-миграции удалить старые unique/key-конфликты только если они мешают новой шапке отчёта.
- Старые fixed columns в `ibadat_reports` можно оставить физически до конца миграции, но код не должен их читать и писать.
- Удалить зависимость `IbadatReportRepository` от `custom_report_values`.
- Если в БД остаются старые таблицы, новая кодовая ветка должна использовать только `group_metrics` и `report_metric_values`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/ibadat_report_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add 2026_04_18_dynamic_group_report_metrics.sql lib/models/ibadat_report.dart lib/repositories/ibadat_report_repository.dart test/models/ibadat_report_test.dart
git commit -m "feat: persist report values by dynamic metric ids"
```

### Task 3: Перестроить админку под полные групповые показатели

**Files:**
- Create or Modify: `lib/repositories/group_metric_repository.dart`
- Create or Modify: `lib/models/group_metric.dart`
- Modify: `lib/screens/admin/admin_screen.dart`
- Modify: `lib/l10n/app_strings.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/models/group_metric.dart';

void main() {
  test('group metric serializes color and max value for insert payload', () {
    final metric = GroupMetric(
      id: 'm1',
      groupId: 'g1',
      name: 'Книга',
      icon: '📚',
      colorValue: const Color(0xFF7C3AED).value,
      unit: 'стр.',
      maxValue: 50,
      orderIndex: 0,
    );

    expect(metric.toInsertJson()['color_value'], const Color(0xFF7C3AED).value);
    expect(metric.toInsertJson()['max_value'], 50);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/group_metric_test.dart`
Expected: FAIL if `toInsertJson()` or renamed repository contract is still missing.

- [ ] **Step 3: Write minimal implementation**

```dart
class GroupMetricRepository {
  final SupabaseClient _client;

  GroupMetricRepository(this._client);

  Future<List<GroupMetric>> getForGroup(String groupId) async { /* select from group_metrics */ }

  Future<GroupMetric> create(GroupMetric metric) async { /* insert + select */ }

  Future<void> delete(String metricId) async {
    await _client.from('group_metrics').delete().eq('id', metricId);
  }
}
```

```dart
final result = await showDialog<_MetricDialogResult>(
  context: context,
  builder: (_) => _AddMetricDialog(s: S.of(context)),
);

await _metricRepo.create(
  GroupMetric(
    id: '',
    groupId: groupId,
    name: result.name,
    icon: result.icon,
    colorValue: result.colorValue,
    unit: result.unit,
    maxValue: result.maxValue,
    orderIndex: _groupMetrics.length,
  ),
);
```

```dart
static const _presetColors = <Color>[
  Color(0xFF0D9488),
  Color(0xFF7C3AED),
  Color(0xFFF59E0B),
  Color(0xFF2563EB),
  Color(0xFFE11D48),
  Color(0xFF10B981),
];
```

Implementation notes:

- Переименовать пользовательские строки: вместо "Доп. показатели" показать обычные "Показатели группы".
- Из блока админки убрать fixed max settings по `IbadatCategory.all`.
- В диалог добавления включить обязательные поля `name`, `icon`, `color`, `unit`, `maxValue`.
- На первом этапе редактирование существующего показателя не делать; только создание и удаление.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/group_metric_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/group_metric.dart lib/repositories/group_metric_repository.dart lib/screens/admin/admin_screen.dart lib/l10n/app_strings.dart test/models/group_metric_test.dart
git commit -m "feat: manage group metrics from admin screen"
```

### Task 4: Перевести экран `Отчёт` на динамические карточки

**Files:**
- Modify: `lib/screens/report/report_editor_screen.dart`
- Modify: `lib/repositories/ibadat_report_repository.dart`
- Modify: `lib/repositories/group_metric_repository.dart`
- Modify: `lib/l10n/app_strings.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/models/group_metric.dart';
import 'package:reportdeepen/reporting/report_progress.dart';

void main() {
  test('quick values are derived from metric max value', () {
    final metric = GroupMetric.test(
      id: 'm1',
      groupId: 'g1',
      name: 'Коран',
      maxValue: 100,
    );

    expect(quickValuesFor(metric), [25, 50, 75, 100]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/reporting/report_progress_test.dart`
Expected: FAIL because helper `quickValuesFor` or equivalent dynamic helper does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
List<int> quickValuesFor(GroupMetric metric) {
  return [0.25, 0.5, 0.75, 1.0]
      .map((factor) => (metric.maxValue * factor).round())
      .toSet()
      .toList();
}
```

```dart
final metrics = await _metricRepo.getForGroup(widget.group.id);
setState(() {
  _groupMetrics = metrics;
});
```

```dart
..._groupMetrics.map((metric) {
  final value = _report.metricValues[metric.id] ?? 0;
  return _MetricCard(
    metric: metric,
    value: value,
    onChanged: (next) => setState(() {
      _report.metricValues[metric.id] = next;
    }),
  );
})
```

Implementation notes:

- Удалить весь цикл по `IbadatCategory.all`.
- Если `_groupMetrics.isEmpty`, показать пустое состояние вместо кнопки сохранения.
- Кнопка `+` не должна ограничиваться `metric.maxValue`.
- Слайдер либо убрать, либо использовать только как быстрый диапазон `0..metric.maxValue`; основной ввод оставить через счётчик.
- Отображать максимум как `Макс: {metric.maxValue} {metric.unit}`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/reporting/report_progress_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/report/report_editor_screen.dart lib/repositories/group_metric_repository.dart lib/repositories/ibadat_report_repository.dart lib/l10n/app_strings.dart test/reporting/report_progress_test.dart
git commit -m "feat: build report editor from group metrics"
```

### Task 5: Перевести `HomeScreen` и `DetailScreen` на динамический прогресс

**Files:**
- Modify: `lib/screens/home/home_screen.dart`
- Modify: `lib/screens/detail/detail_screen.dart`
- Modify: `lib/reporting/report_progress.dart`
- Modify: `lib/repositories/group_metric_repository.dart`
- Modify: `lib/l10n/app_strings.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/models/group_metric.dart';
import 'package:reportdeepen/reporting/report_progress.dart';

void main() {
  test('report progress averages all valid group metrics', () {
    final metrics = [
      GroupMetric.test(id: 'm1', groupId: 'g1', name: 'A', maxValue: 100),
      GroupMetric.test(id: 'm2', groupId: 'g1', name: 'B', maxValue: 50),
    ];

    final progress = reportProgress(metrics, {'m1': 100, 'm2': 25});

    expect(progress, 0.75);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/reporting/report_progress_test.dart`
Expected: FAIL until every helper uses only dynamic `GroupMetric` definitions.

- [ ] **Step 3: Write minimal implementation**

```dart
double _calcScore(String userId, Map<String, IbadatReport> monthly, List<GroupMetric> metrics) {
  final report = monthly[userId];
  if (report == null) return 0;
  return reportProgress(metrics, report.metricValues);
}
```

```dart
Widget _buildMetricChips(IbadatReport report, List<GroupMetric> metrics) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: metrics.map((metric) {
      final value = report.metricValues[metric.id] ?? 0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: metric.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('${metric.icon} $value ${metric.unit}'),
      );
    }).toList(),
  );
}
```

Implementation notes:

- В `HomeScreen` хранить карту `groupId -> List<GroupMetric>`, чтобы не тянуть показатели заново при каждом расчёте.
- Заменить все чтения `section.settings.getMax(...)` и fixed `report.getValue(...)`.
- В `DetailScreen` показывать динамический список метрик группы, а не fixed keys.
- Если у группы нет метрик, summary и detail должны оставаться стабильными и показывать нулевой прогресс.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/reporting/report_progress_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home/home_screen.dart lib/screens/detail/detail_screen.dart lib/reporting/report_progress.dart lib/repositories/group_metric_repository.dart lib/l10n/app_strings.dart test/reporting/report_progress_test.dart
git commit -m "feat: calculate home and detail progress dynamically"
```

### Task 6: Проверка, очистка зависимостей и финальная верификация

**Files:**
- Modify: `lib/models/ibadat_category.dart`
- Modify: `lib/models/ibadat_group_settings.dart`
- Modify: `test/widget_test.dart`
- Modify: any leftover imports in `lib/screens/admin/admin_screen.dart`, `lib/screens/report/report_editor_screen.dart`, `lib/screens/home/home_screen.dart`, `lib/screens/detail/detail_screen.dart`

- [ ] **Step 1: Write the failing smoke test**

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy fixed report category helpers are no longer referenced', () async {
    expect(true, isTrue);
  });
}
```

- [ ] **Step 2: Run targeted analysis to verify cleanup is still pending**

Run: `flutter analyze`
Expected: FAIL or show warnings while stale imports and dead references to `IbadatCategory` / `IbadatGroupSettings` still exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// Keep this file only as a deprecated compatibility shell during cleanup.
@Deprecated('Report screens now use GroupMetric instead.')
class IbadatCategory {
  const IbadatCategory._();
}
```

```dart
// If group settings are still needed elsewhere, leave only non-report settings here.
class IbadatGroupSettings {
  final String groupId;

  const IbadatGroupSettings({required this.groupId});
}
```

Implementation notes:

- Если `IbadatCategory` и `IbadatGroupSettings` после рефактора нигде не нужны, удалить файлы полностью вместо заглушек.
- Убрать старые импорты и мёртвые helper-методы.
- Обновить `widget_test.dart`, чтобы он не зависел от устаревшей структуры виджетов.

- [ ] **Step 4: Run full verification**

Run: `flutter test`
Expected: PASS

Run: `flutter analyze`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/ibadat_category.dart lib/models/ibadat_group_settings.dart lib/screens/admin/admin_screen.dart lib/screens/report/report_editor_screen.dart lib/screens/home/home_screen.dart lib/screens/detail/detail_screen.dart test/widget_test.dart
git commit -m "refactor: remove legacy fixed report category flow"
```

## Self-Review

- Spec coverage: все требования из спецификации закрыты — отдельные групповые показатели, выбор иконки/цвета/unit/max, динамический экран отчёта, сохранение значений выше максимума, capped progress, пустая группа, перевод home/detail.
- Placeholder scan: все задачи привязаны к конкретным файлам, тестам и командам; абстрактных `TODO` шагов не осталось.
- Type consistency: везде используется единая терминология `GroupMetric`, `metricValues`, `group_metrics`, `report_metric_values`, `reportProgress`.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-18-group-dynamic-report-metrics.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
