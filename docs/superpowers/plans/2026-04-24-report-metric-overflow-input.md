# Report Metric Overflow Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Позволить пользователю и админу вводить в отчёте значения показателей выше `metric.maxValue` через диалог ручного ввода, с визуальным бейджем переполнения.

**Architecture:** Добавить standalone-виджет `ManualValueDialog` в отдельный файл (тестируется изолированно). В `_buildMetricCard` ([report_editor_screen.dart:391-540](../../../lib/screens/report/report_editor_screen.dart#L391-L540)) обернуть центральный чип цифры в `GestureDetector`, открывающий диалог; рядом с правым чипом значения добавить бейдж переполнения при `value > maxValue`. Локализацию расширить через `AppStringsX`.

**Tech Stack:** Flutter, Dart, `flutter_test` (widget tests). Существующие зависимости уже есть в `pubspec.yaml`.

**Спецификация:** [docs/superpowers/specs/2026-04-24-report-metric-overflow-input-design-ru.md](../specs/2026-04-24-report-metric-overflow-input-design-ru.md)

---

## File Structure

- **Создать** [lib/screens/report/manual_value_dialog.dart](../../../lib/screens/report/manual_value_dialog.dart) — публичный `ManualValueDialog` (`StatefulWidget`), возвращает `int?` через `Navigator.pop`.
- **Создать** [test/screens/report/manual_value_dialog_test.dart](../../../test/screens/report/manual_value_dialog_test.dart) — widget-тесты диалога.
- **Изменить** [lib/l10n/app_strings.dart](../../../lib/l10n/app_strings.dart) — добавить `manualValueTitle` (required field, ru/kk), добавить `manualValueHint(int max, String unit)` в `AppStringsX` extension.
- **Изменить** [lib/screens/report/report_editor_screen.dart](../../../lib/screens/report/report_editor_screen.dart) — импорт `ManualValueDialog`, обернуть центральный чип в `GestureDetector`, добавить бейдж переполнения.

Все изменения соответствуют существующему паттерну экрана (private widgets для не-переиспользуемых, отдельные файлы для тестируемых единиц).

---

## Task 1: Локализация — `manualValueTitle` и `manualValueHint`

**Files:**
- Modify: `lib/l10n/app_strings.dart`

- [ ] **Step 1: Добавить поле `manualValueTitle` в класс `AppStrings`**

В [lib/l10n/app_strings.dart](../../../lib/l10n/app_strings.dart), в секции `// ── Home / Report ──` (после `reportSaving`, строка 164), добавить объявление поля:

```dart
  final String manualValueTitle;
```

И в конструктор `const AppStrings({...})` (после `required this.reportSaving,`, строка 371), добавить:

```dart
    required this.manualValueTitle,
```

- [ ] **Step 2: Добавить значение в казахскую константу `_kk`**

В `const _kk = AppStrings(...)`, в секции после `reportSaving: 'Сақталуда...',` (строка 578), добавить:

```dart
  manualValueTitle: 'Мәнді енгізу',
```

- [ ] **Step 3: Добавить значение в русскую константу `_ru`**

В `const _ru = AppStrings(...)`, после `reportSaving: 'Сохраняется...',` (строка 785), добавить:

```dart
  manualValueTitle: 'Ввести значение',
```

- [ ] **Step 4: Добавить helper `manualValueHint` в extension `AppStringsX`**

В [lib/l10n/app_strings.dart](../../../lib/l10n/app_strings.dart), в `extension AppStringsX on AppStrings` (строка 841), перед `String unitLabel(...)`, добавить:

```dart
  String manualValueHint(int max, String unit) {
    if (languageCode == 'ru') {
      return 'Обычный диапазон: 0..$max $unit';
    }
    return 'Әдеттегі аралық: 0..$max $unit';
  }
```

- [ ] **Step 5: Запустить анализатор, чтобы убедиться в отсутствии ошибок компиляции**

Run: `flutter analyze lib/l10n/app_strings.dart`
Expected: `No issues found!` или существующие предупреждения, не связанные с правками.

- [ ] **Step 6: Коммит**

```bash
git add lib/l10n/app_strings.dart
git commit -m "feat(l10n): add manual value dialog strings"
```

---

## Task 2: `ManualValueDialog` — TDD

**Files:**
- Create: `test/screens/report/manual_value_dialog_test.dart`
- Create: `lib/screens/report/manual_value_dialog.dart`

- [ ] **Step 1: Написать провальный тест — диалог показывает заголовок, текущее значение и хинт**

Создать [test/screens/report/manual_value_dialog_test.dart](../../../test/screens/report/manual_value_dialog_test.dart):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/screens/report/manual_value_dialog.dart';

Widget _host(Widget dialog) {
  return MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('kk')],
    localizationsDelegates: const [
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
    home: Scaffold(body: Builder(builder: (context) => dialog)),
  );
}

void main() {
  testWidgets('shows title, prefilled value, and hint with max/unit', (tester) async {
    await tester.pumpWidget(_host(
      Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => showDialog<int>(
            context: context,
            builder: (_) => const ManualValueDialog(
              current: 7,
              max: 10,
              unitLabel: 'стр.',
              color: Color(0xFF6366F1),
              title: 'Ввести значение',
              hint: 'Обычный диапазон: 0..10 стр.',
              saveLabel: 'Сохранить',
              cancelLabel: 'Отмена',
            ),
          ),
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Ввести значение'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Обычный диапазон: 0..10 стр.'), findsOneWidget);
  });

  testWidgets('save button is disabled when field is empty', (tester) async {
    await tester.pumpWidget(_host(
      Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => showDialog<int>(
            context: context,
            builder: (_) => const ManualValueDialog(
              current: 5,
              max: 10,
              unitLabel: 'раз',
              color: Color(0xFF6366F1),
              title: 'T',
              hint: 'H',
              saveLabel: 'Сохранить',
              cancelLabel: 'Отмена',
            ),
          ),
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    final saveBtn = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Сохранить'),
    );
    expect(saveBtn.onPressed, isNull);
  });

  testWidgets('returns entered integer via Navigator.pop', (tester) async {
    int? result;
    await tester.pumpWidget(_host(
      Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () async {
            result = await showDialog<int>(
              context: context,
              builder: (_) => const ManualValueDialog(
                current: 3,
                max: 10,
                unitLabel: 'раз',
                color: Color(0xFF6366F1),
                title: 'T',
                hint: 'H',
                saveLabel: 'Сохранить',
                cancelLabel: 'Отмена',
              ),
            );
          },
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Сохранить'));
    await tester.pumpAndSettle();

    expect(result, 123);
  });

  testWidgets('cancel returns null', (tester) async {
    int? result = -1;
    await tester.pumpWidget(_host(
      Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () async {
            result = await showDialog<int>(
              context: context,
              builder: (_) => const ManualValueDialog(
                current: 3,
                max: 10,
                unitLabel: 'раз',
                color: Color(0xFF6366F1),
                title: 'T',
                hint: 'H',
                saveLabel: 'Сохранить',
                cancelLabel: 'Отмена',
              ),
            );
          },
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
```

- [ ] **Step 2: Запустить тесты и убедиться, что они падают**

Run: `flutter test test/screens/report/manual_value_dialog_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:reportdeepen/screens/report/manual_value_dialog.dart'`.

- [ ] **Step 3: Создать минимальную реализацию `ManualValueDialog`**

Создать [lib/screens/report/manual_value_dialog.dart](../../../lib/screens/report/manual_value_dialog.dart):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ManualValueDialog extends StatefulWidget {
  final int current;
  final int max;
  final String unitLabel;
  final Color color;
  final String title;
  final String hint;
  final String saveLabel;
  final String cancelLabel;

  const ManualValueDialog({
    super.key,
    required this.current,
    required this.max,
    required this.unitLabel,
    required this.color,
    required this.title,
    required this.hint,
    required this.saveLabel,
    required this.cancelLabel,
  });

  @override
  State<ManualValueDialog> createState() => _ManualValueDialogState();
}

class _ManualValueDialogState extends State<ManualValueDialog> {
  late final TextEditingController _ctrl;
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current.toString());
    _ctrl.addListener(_onChanged);
  }

  void _onChanged() {
    final text = _ctrl.text.trim();
    final parsed = int.tryParse(text);
    setState(() => _isValid = text.isNotEmpty && parsed != null && parsed >= 0);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: const TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              suffixText: widget.unitLabel,
              suffixStyle: const TextStyle(color: Color(0xFF94A3B8)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: widget.color, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.hint,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel, style: const TextStyle(color: Color(0xFF94A3B8))),
        ),
        TextButton(
          onPressed: _isValid
              ? () => Navigator.of(context).pop(int.parse(_ctrl.text.trim()))
              : null,
          child: Text(
            widget.saveLabel,
            style: TextStyle(color: _isValid ? widget.color : const Color(0xFF475569), fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Запустить тесты и убедиться, что все проходят**

Run: `flutter test test/screens/report/manual_value_dialog_test.dart`
Expected: All 4 tests PASS.

- [ ] **Step 5: Коммит**

```bash
git add lib/screens/report/manual_value_dialog.dart test/screens/report/manual_value_dialog_test.dart
git commit -m "feat(report): add ManualValueDialog widget for free-form metric input"
```

---

## Task 3: Интеграция диалога в `_buildMetricCard` (тап по центральной цифре)

**Files:**
- Modify: `lib/screens/report/report_editor_screen.dart`

- [ ] **Step 1: Добавить импорт `ManualValueDialog`**

В [lib/screens/report/report_editor_screen.dart](../../../lib/screens/report/report_editor_screen.dart), после строки 15 (`import '../../utils/week_utils.dart';`) добавить:

```dart
import 'manual_value_dialog.dart';
```

- [ ] **Step 2: Обернуть центральный чип цифры в `GestureDetector` с вызовом диалога**

Найти в `_buildMetricCard` блок (строки 483–498):

```dart
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: metric.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$value',
                    style: TextStyle(
                      color: metric.color,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
```

Заменить на:

```dart
                GestureDetector(
                  onTap: () async {
                    final result = await showDialog<int>(
                      context: context,
                      builder: (_) => ManualValueDialog(
                        current: value,
                        max: metric.maxValue,
                        unitLabel: s.unitLabel(metric.unit),
                        color: metric.color,
                        title: s.manualValueTitle,
                        hint: s.manualValueHint(metric.maxValue, s.unitLabel(metric.unit)),
                        saveLabel: s.save,
                        cancelLabel: s.cancel,
                      ),
                    );
                    if (result != null && mounted) {
                      setState(() => _report.setValue(metricId, result));
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      color: metric.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$value',
                      style: TextStyle(
                        color: metric.color,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
```

- [ ] **Step 3: Запустить анализатор**

Run: `flutter analyze lib/screens/report/report_editor_screen.dart`
Expected: `No issues found!` (или только существующие warnings, не связанные с правками).

- [ ] **Step 4: Коммит**

```bash
git add lib/screens/report/report_editor_screen.dart
git commit -m "feat(report): open ManualValueDialog on metric value tap"
```

---

## Task 4: Бейдж переполнения рядом с чипом значения

**Files:**
- Modify: `lib/screens/report/report_editor_screen.dart`

- [ ] **Step 1: Обернуть правый чип-значения в `Row` и добавить бейдж**

В `_buildMetricCard` найти блок (строки 435–449):

```dart
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: metric.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$value ${s.unitLabel(metric.unit)}',
                  style: TextStyle(
                    color: metric.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
```

Заменить на:

```dart
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: metric.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$value ${s.unitLabel(metric.unit)}',
                      style: TextStyle(
                        color: metric.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (value > metric.maxValue) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '+${value - metric.maxValue}',
                        style: const TextStyle(
                          color: Color(0xFFFCD34D),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
```

- [ ] **Step 2: Запустить анализатор**

Run: `flutter analyze lib/screens/report/report_editor_screen.dart`
Expected: `No issues found!`.

- [ ] **Step 3: Запустить все существующие тесты**

Run: `flutter test`
Expected: All tests PASS (включая `report_progress_test.dart` и новый `manual_value_dialog_test.dart`). `test/widget_test.dart` может падать из-за Supabase init — это известная проблема, не связанная с правками; если падает только он — игнорировать.

- [ ] **Step 4: Коммит**

```bash
git add lib/screens/report/report_editor_screen.dart
git commit -m "feat(report): show overflow badge when metric value exceeds max"
```

---

## Task 5: Ручная проверка в приложении

**Files:** N/A — UI smoke-проверка.

- [ ] **Step 1: Запустить приложение**

Run: `flutter run -d windows` (или предпочтительная платформа).

- [ ] **Step 2: Проверить сценарий пользователя в группе**

1. Войти как обычный пользователь, перейти на вкладку «Отчёт».
2. Выбрать показатель с `max`, например, 10.
3. Тапнуть по центральной цифре → диалог открывается с предзаполненным текущим значением.
4. Ввести `100`, нажать «Сохранить» → число в центре становится `100`, рядом с правым чипом появляется бейдж `+90`.
5. Нажать «+» → значение становится `101`, бейдж становится `+91`.
6. Нажать «Сохранить» (основная кнопка экрана) → `Отчёт сохранён ✅`.
7. Перейти на главный экран → в детали показателя отображается `100 стр.`, прогресс-кольцо заполнено на 100%.

Expected: всё работает без крашей, значения сохраняются в Supabase, бейдж появляется/исчезает корректно при пересечении границы max.

- [ ] **Step 3: Проверить сценарий админа на личных показателях**

1. Войти как админ, перейти на «Отчёт» (для админов показатели — личные).
2. Повторить шаги 2–7 из Step 2.

Expected: поведение идентично пользовательскому.

- [ ] **Step 4: Проверить валидацию диалога**

1. Открыть диалог, стереть содержимое поля → кнопка «Сохранить» становится неактивной.
2. Ввести `0` → кнопка активна, сохранение обнуляет значение.
3. Нажать «Отмена» → значение не меняется.

Expected: все 3 случая работают.

- [ ] **Step 5: Зафиксировать результаты проверки**

Если всё работает — перейти к завершению ветки (PR или merge через skill `superpowers:finishing-a-development-branch`).

Если найдены баги — откатиться к предыдущей рабочей точке, завести задачу, отремонтировать, перезапустить Task 5.

---

## Self-Review

**1. Spec coverage:**
- ✅ Слайдер 0..max, клампится — не трогаем, оставляем как есть.
- ✅ Кнопки ± без изменений.
- ✅ Быстрые значения без изменений.
- ✅ Тап по цифре → диалог (Task 3).
- ✅ Диалог: поле, подсказка, валидация, кнопки (Task 2).
- ✅ Бейдж `+N` при `value > maxValue` (Task 4).
- ✅ Локализация ru/kk (Task 1).
- ✅ Детали/главная не трогаем (подтверждено в spec).
- ✅ Ручная проверка обоих сценариев — пользователь и админ (Task 5).

**2. Placeholder scan:** TBD/TODO/placeholder'ов в коде нет, все шаги содержат полные сниппеты.

**3. Type consistency:**
- `ManualValueDialog` — имя совпадает в Task 2 (создание) и Task 3 (использование).
- Параметры `current: int`, `max: int`, `unitLabel: String`, `color: Color`, `title`, `hint`, `saveLabel`, `cancelLabel` — согласованы между Task 2 и Task 3.
- `manualValueTitle` как поле `AppStrings`, `manualValueHint(int, String)` как метод extension — согласовано между Task 1 и Task 3.
- Возврат `int?` через `Navigator.pop` — согласован.
