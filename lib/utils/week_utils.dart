class WeekInfo {
  final int weekNumber;
  final int year;
  final DateTime start;
  final DateTime end;
  final String label;

  const WeekInfo({
    required this.weekNumber,
    required this.year,
    required this.start,
    required this.end,
    required this.label,
  });
}

class WeekUtils {
  static const _monthsShort = [
    'Қаң', 'Ақп', 'Нау', 'Сәу', 'Мам', 'Мау',
    'Шіл', 'Там', 'Қыр', 'Қаз', 'Қар', 'Жел',
  ];

  static const _monthsFull = [
    'Қаңтар', 'Ақпан', 'Наурыз', 'Сәуір', 'Мамыр', 'Маусым',
    'Шілде', 'Тамыз', 'Қыркүйек', 'Қазан', 'Қараша', 'Желтоқсан',
  ];

  static DateTime _monday(DateTime date) {
    final d = date.toLocal();
    final diff = d.weekday - 1; // Monday = 1
    return DateTime(d.year, d.month, d.day - diff);
  }

  static int _isoWeekNumber(DateTime date) {
    final d = date.toLocal();
    final startOfYear = DateTime(d.year, 1, 1);
    final diff = d.difference(startOfYear).inDays;
    final startWeekday = startOfYear.weekday;
    return ((diff + startWeekday - 1) / 7).ceil();
  }

  static String _fmtDate(DateTime d) =>
      '${d.day} ${_monthsShort[d.month - 1]}';

  /// Returns info for the last 4 weeks (index 0 = oldest, 3 = current)
  static List<WeekInfo> lastFourWeeks() {
    final now = DateTime.now().toLocal();
    return List.generate(4, (i) {
      final offset = DateTime(now.year, now.month, now.day - (3 - i) * 7);
      final mon = _monday(offset);
      final sun = mon.add(const Duration(days: 6));
      return WeekInfo(
        weekNumber: _isoWeekNumber(mon),
        year: mon.year,
        start: mon,
        end: sun,
        label: '${_fmtDate(mon)} – ${_fmtDate(sun)}',
      );
    });
  }

  static String currentMonthLabel() {
    final now = DateTime.now().toLocal();
    return '${_monthsFull[now.month - 1]} ${now.year}';
  }

  static String monthLabel(int month, int year) {
    return '${_monthsFull[month - 1]} $year';
  }

  /// Which week numbers fall in the given month/year
  static List<int> weekNumbersForMonth(int month, int year) {
    final weeks = lastFourWeeks();
    return weeks
        .where((w) => w.start.month == month && w.start.year == year)
        .map((w) => w.weekNumber)
        .toList();
  }
}
