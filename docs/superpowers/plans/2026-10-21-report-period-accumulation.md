# Накопление значений отчёта в рамках периода — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** При повторном сохранении отчёта за период новые значения прибавляются к сохранённым, а не перезаписывают их.

**Architecture:** Редактор хранит сохранённые итоги (`_report`) отдельно от вводимых добавок (`_deltas`). При сохранении отчёт за период перечитывается из базы, к нему чистой функцией `applyReportDeltas` прибавляются добавки, результат сохраняется существующим `upsertReport`. Серверных изменений нет.

**Tech Stack:** Flutter/Dart, Supabase (`supabase_flutter`), `flutter_test`.

Спецификация: [2026-10-21-report-period-accumulation-design-ru.md](../specs/2026-10-21-report-period-accumulation-design-ru.md)

---

## Файлы

- Create: `lib/reporting/report_deltas.dart` — чистая функция `applyReportDeltas`.
- Create: `test/reporting/report_deltas_test.dart`
- Modify: `lib/l10n/app_strings.dart` — строки «Добавить», «Нет новых данных», «станет: N».
- Create: `test/l10n/app_strings_report_accumulation_test.dart`
- Modify: `lib/screens/report/report_editor_screen.dart` — состояние `_deltas`, карточка, сохранение.

---

### Task 1: Функция `applyReportDeltas`

**Files:**
- Create: `lib/reporting/report_deltas.dart`
- Test: `test/reporting/report_deltas_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/reporting/report_deltas.dart';

void main() {
  test('adds deltas to existing totals', () {
    expect(
      applyReportDeltas({'quran': 13, 'book': 4}, {'quran': 5}),
      {'quran': 18, 'book': 4},
    );
  });

  test('adds deltas for metrics without a saved total', () {
    expect(applyReportDeltas({}, {'quran': 3}), {'quran': 3});
  });

  test('negative delta decreases total', () {
    expect(applyReportDeltas({'quran': 13}, {'quran': -3}), {'quran': 10});
  });

  test('total never goes below zero', () {
    expect(applyReportDeltas({'quran': 2}, {'quran': -5}), {'quran': 0});
  });

  test('empty or zero deltas keep totals unchanged', () {
    expect(applyReportDeltas({'quran': 13}, {}), {'quran': 13});
    expect(applyReportDeltas({'quran': 13}, {'quran': 0}), {'quran': 13});
  });

  test('does not mutate the input maps', () {
    final totals = {'quran': 13};
    final deltas = {'quran': 2};
    applyReportDeltas(totals, deltas);
    expect(totals, {'quran': 13});
    expect(deltas, {'quran': 2});
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/reporting/report_deltas_test.dart`
Expected: FAIL — `report_deltas.dart` не найден.

- [ ] **Step 3: Write minimal implementation**

```dart
/// Adds per-metric [deltas] to saved [totals] for one report period.
/// Totals are clamped at zero; metrics without a delta are kept as is.
Map<String, int> applyReportDeltas(
  Map<String, int> totals,
  Map<String, int> deltas,
) {
  final result = Map<String, int>.of(totals);
  deltas.forEach((metricId, delta) {
    final next = (result[metricId] ?? 0) + delta;
    result[metricId] = next < 0 ? 0 : next;
  });
  return result;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/reporting/report_deltas_test.dart`
Expected: All tests passed.

- [ ] **Step 5: Commit**

```bash
git add lib/reporting/report_deltas.dart test/reporting/report_deltas_test.dart
git commit -m "feat: add applyReportDeltas for period accumulation"
```

---

### Task 2: Строки локализации

**Files:**
- Modify: `lib/l10n/app_strings.dart` (рядом с `manualValueHint`, ~строка 1048)
- Test: `test/l10n/app_strings_report_accumulation_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/l10n/app_strings.dart';

void main() {
  test('Russian report accumulation strings', () {
    final s = AppStrings.ru;
    expect(s.reportAddLabel, 'Добавить');
    expect(s.reportNoChanges, 'Нет новых данных');
    expect(s.reportResultPreview(18, 'стр.'), 'станет: 18 стр.');
  });

  test('Kazakh report accumulation strings', () {
    final s = AppStrings.kk;
    expect(s.reportAddLabel, 'Қосу');
    expect(s.reportNoChanges, 'Жаңа деректер жоқ');
    expect(s.reportResultPreview(18, 'бет'), 'болады: 18 бет');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/l10n/app_strings_report_accumulation_test.dart`
Expected: FAIL — геттеры не определены.

- [ ] **Step 3: Write minimal implementation**

В `lib/l10n/app_strings.dart` прямо перед `String manualValueHint(int max, String unit) {` добавить:

```dart
  String get reportAddLabel => languageCode == 'ru' ? 'Добавить' : 'Қосу';
  String get reportNoChanges =>
      languageCode == 'ru' ? 'Нет новых данных' : 'Жаңа деректер жоқ';
  String reportResultPreview(int total, String unit) => languageCode == 'ru'
      ? 'станет: $total $unit'
      : 'болады: $total $unit';

```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/l10n/app_strings_report_accumulation_test.dart`
Expected: All tests passed.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_strings.dart test/l10n/app_strings_report_accumulation_test.dart
git commit -m "feat: add report accumulation strings"
```

---

### Task 3: Состояние добавок и карточка показателя

**Files:**
- Modify: `lib/screens/report/report_editor_screen.dart`

- [ ] **Step 1: Добавить импорт и состояние**

После `import '../../reporting/report_progress.dart';`:

```dart
import '../../reporting/report_deltas.dart';
```

В `ReportEditorScreenState` после `IbadatPeriod? _selectedPeriod;`:

```dart
  /// Unsaved per-metric amounts to add to the saved period totals in [_report].
  final Map<String, int> _deltas = {};

  void _setDelta(String metricId, int delta) {
    setState(() {
      if (delta == 0) {
        _deltas.remove(metricId);
      } else {
        _deltas[metricId] = delta;
      }
    });
  }
```

- [ ] **Step 2: Сбрасывать добавки при смене периода**

В `_onPeriodSelected` внутри `setState(() {` после `_selectedPeriod = period;`:

```dart
        _deltas.clear();
```

В `_reloadPeriods` внутри `setState(() {` перед `_periods = periods;`:

```dart
        if (newSelected?.id != _selectedPeriod?.id) _deltas.clear();
```

- [ ] **Step 3: Переписать `_buildMetricCard`**

Начало метода (вместо вычисления `value`, `clampedValue`):

```dart
    final metricId = metric.id!;
    final total = _report.valueForMetric(metricId);
    final delta = _deltas[metricId] ?? 0;
    final result = total + delta;
    final unit = s.unitLabel(metric.unit);
    final sliderMax = metric.maxValue > 0 ? metric.maxValue.toDouble() : 1.0;
    final sliderValue = delta.clamp(0, metric.maxValue > 0 ? metric.maxValue : 1).toDouble();
    final quickValues = quickValuesFor(metric);
```

Изменения в разметке:
- Бейдж итога: `'$value ${s.unitLabel(metric.unit)}'` → `'$total $unit'`.
- Бейдж превышения: условие `value > metric.maxValue` → `result > metric.maxValue`, текст `'+${value - metric.maxValue}'` → `'+${result - metric.maxValue}'`.
- Сразу после заголовочного `Row(...)` (перед `const SizedBox(height: 12),`) вставить предпросмотр и подпись:

```dart
          if (delta != 0)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  s.reportResultPreview(result < 0 ? 0 : result, unit),
                  style: TextStyle(
                    color: metric.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              s.reportAddLabel,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ),
```

(существующий `const SizedBox(height: 12),` перед `SliderTheme` удалить — он теперь внутри вставки.)

- Slider: `value: sliderValue`, `onChanged: (newValue) => _setDelta(metricId, newValue.round()),`.
- Кнопка «−»:

```dart
                  onTap: delta > -total
                      ? () => _setDelta(metricId, delta - 1)
                      : null,
```

- Ручной ввод: `current: delta < 0 ? 0 : delta,`; при результате `_setDelta(metricId, result);` вместо `setState(() => _report.setValue(metricId, result));` (переменную результата диалога переименовать в `entered`, чтобы не конфликтовать с `result`):

```dart
                    final entered = await showDialog<int>(
                      ...
                    );
                    if (entered != null && mounted) {
                      _setDelta(metricId, entered);
                    }
```

- Центральное поле: текст `'$value'` → `delta < 0 ? '−${-delta}' : '$delta'`.
- Кнопка «+»: `onTap: () => _setDelta(metricId, delta + 1),`.
- Быстрые кнопки: `isSelected = delta == quickValue`, `onTap: () => _setDelta(metricId, quickValue),`.

- [ ] **Step 4: Проверить анализатором**

Run: `flutter analyze --no-pub lib/screens/report/report_editor_screen.dart`
Expected: No issues found! (не должно остаться ссылок на `value` в `_buildMetricCard`).

Сохранение пока перезаписывает итоги без добавок — это исправляет Task 4; коммит делается после него.

---

### Task 4: Сохранение с суммированием

**Files:**
- Modify: `lib/screens/report/report_editor_screen.dart` (метод `_save`)

- [ ] **Step 1: Заменить тело `_save`**

```dart
  Future<void> _save() async {
    final period = _selectedPeriod;
    if (period == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).noPeriodSelected)),
      );
      return;
    }
    if (_deltas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).reportNoChanges)),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      // Re-read the period's saved totals so the addition is applied to the
      // latest data, not to what was loaded when the screen opened.
      final fresh = await _repo.getReportByPeriod(
        userId: widget.profile.id,
        groupId: period.groupId,
        periodId: period.id,
      );
      final base = fresh ??
          IbadatReport(
            userId: widget.profile.id,
            groupId: period.groupId,
            periodId: period.id,
            month: period.startDate.month,
            year: period.startDate.year,
          );
      final saved = await _repo.upsertReport(
        base.copyWith(metricValues: applyReportDeltas(base.metricValues, _deltas)),
      );
      if (!mounted) return;
      setState(() {
        _report = saved;
        _deltas.clear();
      });
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).reportSaved),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${S.of(context).error}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
```

- [ ] **Step 2: Анализ и полный прогон тестов**

Run: `flutter analyze --no-pub` и `flutter test --no-pub`
Expected: No issues found; All tests passed.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/report/report_editor_screen.dart
git commit -m "feat: accumulate report values within the selected period"
```

---

### Task 5: Ручная проверка на устройстве

- [ ] Период A: добавить «Коран» +5, сохранить → бейдж 5, поле добавки 0.
- [ ] Закрыть приложение, открыть, выбрать период A → бейдж 5. Добавить +3, сохранить → 8.
- [ ] Нажать «Сохранить» без изменений → «Нет новых данных», итог 8.
- [ ] «−» дважды → поле `−2`, предпросмотр «станет: 6»; сохранить → 6. «−» не опускается ниже −6.
- [ ] Период B: итоги B не изменились после сохранений в A.
- [ ] Ввести добавку, переключить период → добавка сброшена.
