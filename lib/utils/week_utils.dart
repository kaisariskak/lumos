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
  static const _monthsShortKk = [
    '\u049A\u0430\u04A3',
    '\u0410\u049B\u043F',
    '\u041D\u0430\u0443',
    '\u0421\u04D9\u0443',
    '\u041C\u0430\u043C',
    '\u041C\u0430\u0443',
    '\u0428\u0456\u043B',
    '\u0422\u0430\u043C',
    '\u049A\u044B\u0440',
    '\u049A\u0430\u0437',
    '\u049A\u0430\u0440',
    '\u0416\u0435\u043B',
  ];

  static const _monthsFullKk = [
    '\u049A\u0430\u04A3\u0442\u0430\u0440',
    '\u0410\u049B\u043F\u0430\u043D',
    '\u041D\u0430\u0443\u0440\u044B\u0437',
    '\u0421\u04D9\u0443\u0456\u0440',
    '\u041C\u0430\u043C\u044B\u0440',
    '\u041C\u0430\u0443\u0441\u044B\u043C',
    '\u0428\u0456\u043B\u0434\u0435',
    '\u0422\u0430\u043C\u044B\u0437',
    '\u049A\u044B\u0440\u043A\u04AF\u0439\u0435\u043A',
    '\u049A\u0430\u0437\u0430\u043D',
    '\u049A\u0430\u0440\u0430\u0448\u0430',
    '\u0416\u0435\u043B\u0442\u043E\u049B\u0441\u0430\u043D',
  ];

  static const _monthsShortRu = [
    '\u042F\u043D\u0432',
    '\u0424\u0435\u0432',
    '\u041C\u0430\u0440',
    '\u0410\u043F\u0440',
    '\u041C\u0430\u0439',
    '\u0418\u044E\u043D',
    '\u0418\u044E\u043B',
    '\u0410\u0432\u0433',
    '\u0421\u0435\u043D',
    '\u041E\u043A\u0442',
    '\u041D\u043E\u044F',
    '\u0414\u0435\u043A',
  ];

  static const _monthsFullRu = [
    '\u042F\u043D\u0432\u0430\u0440\u044C',
    '\u0424\u0435\u0432\u0440\u0430\u043B\u044C',
    '\u041C\u0430\u0440\u0442',
    '\u0410\u043F\u0440\u0435\u043B\u044C',
    '\u041C\u0430\u0439',
    '\u0418\u044E\u043D\u044C',
    '\u0418\u044E\u043B\u044C',
    '\u0410\u0432\u0433\u0443\u0441\u0442',
    '\u0421\u0435\u043D\u0442\u044F\u0431\u0440\u044C',
    '\u041E\u043A\u0442\u044F\u0431\u0440\u044C',
    '\u041D\u043E\u044F\u0431\u0440\u044C',
    '\u0414\u0435\u043A\u0430\u0431\u0440\u044C',
  ];

  static List<String> _shortMonths(String languageCode) =>
      languageCode == 'ru' ? _monthsShortRu : _monthsShortKk;

  static List<String> _fullMonths(String languageCode) =>
      languageCode == 'ru' ? _monthsFullRu : _monthsFullKk;

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

  static String _fmtDate(DateTime d, {String languageCode = 'kk'}) =>
      '${d.day} ${_shortMonths(languageCode)[d.month - 1]}';

  /// Returns info for the last 4 weeks (index 0 = oldest, 3 = current)
  static List<WeekInfo> lastFourWeeks({String languageCode = 'kk'}) {
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
        label:
            '${_fmtDate(mon, languageCode: languageCode)} \u2013 ${_fmtDate(sun, languageCode: languageCode)}',
      );
    });
  }

  static String currentMonthLabel({String languageCode = 'kk'}) {
    final now = DateTime.now().toLocal();
    return '${_fullMonths(languageCode)[now.month - 1]} ${now.year}';
  }

  static String monthLabel(int month, int year, {String languageCode = 'kk'}) {
    return '${_fullMonths(languageCode)[month - 1]} $year';
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
