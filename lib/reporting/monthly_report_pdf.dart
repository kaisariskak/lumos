import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/week_utils.dart';
import 'monthly_group_report.dart';

/// The PDF is generated in the app's UI language.
String pdfLanguageFor(String uiLanguageCode) =>
    uiLanguageCode == 'ru' ? 'ru' : 'kk';

class _PdfStrings {
  final String title;
  final String member;
  final String done;
  final String monthGoal;
  final String completion;
  final String total;
  final String generated;
  final String Function(int page, int count) pageLabel;

  const _PdfStrings({
    required this.title,
    required this.member,
    required this.done,
    required this.monthGoal,
    required this.completion,
    required this.total,
    required this.generated,
    required this.pageLabel,
  });

  static _PdfStrings of(String lang) => lang == 'ru' ? _ru : _kk;

  static final _kk = _PdfStrings(
    title: 'Айлық есеп',
    member: 'Қатысушы',
    done: 'Орындалды',
    monthGoal: 'Айлық мақсат',
    completion: 'Орындалуы',
    total: 'Барлығы',
    generated: 'Жасалған күні',
    pageLabel: (page, count) => 'Бет $page / $count',
  );

  static final _ru = _PdfStrings(
    title: 'Ежемесячный отчёт',
    member: 'Участник',
    done: 'Выполнено',
    monthGoal: 'Месячная цель',
    completion: 'Выполнение',
    total: 'Итого',
    generated: 'Сформирован',
    pageLabel: (page, count) => 'Стр. $page из $count',
  );
}

const _ink = PdfColor.fromInt(0xFF0F172A);
const _muted = PdfColor.fromInt(0xFF64748B);
const _faint = PdfColor.fromInt(0xFFCBD5E1);
const _line = PdfColor.fromInt(0xFFE2E8F0);
const _zebra = PdfColor.fromInt(0xFFF8FAFC);
const _brand = PdfColor.fromInt(0xFF0F3D3E);
const _brandDark = PdfColor.fromInt(0xFF0B2B2C);
const _accent = PdfColor.fromInt(0xFF15A68B);
const _gold = PdfColor.fromInt(0xFFF6C453);
const _softBg = PdfColor.fromInt(0xFFF0FDF9);
const _track = PdfColor.fromInt(0xFFE8EDF3);
const _amber = PdfColor.fromInt(0xFFF59E0B);
const _coral = PdfColor.fromInt(0xFFEF4444);

/// Builds the monthly report PDF in [lang] ('kk' or 'ru'): the header and
/// one table of members' monthly totals against their monthly goals.
Future<Uint8List> buildMonthlyReportPdf(
  MonthlyGroupReport report, {
  required String lang,
  DateTime? generatedAt,
}) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
  );
  final s = _PdfStrings.of(lang);
  final monthLabel = WeekUtils.monthLabel(
    report.month,
    report.year,
    languageCode: lang,
  );
  final now = generatedAt ?? DateTime.now();

  final doc = pw.Document(
    title: '${report.group.name} — $monthLabel',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 28),
      footer: (context) => _footer(context, s, now),
      build: (context) => [
        _header(report, s, monthLabel, now),
        pw.SizedBox(height: 18),
        _rankingTable(report, s),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _header(
  MonthlyGroupReport report,
  _PdfStrings s,
  String monthLabel,
  DateTime now,
) {
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(20, 18, 20, 18),
    decoration: const pw.BoxDecoration(
      gradient: pw.LinearGradient(
        colors: [_brandDark, _brand],
        begin: pw.Alignment.topLeft,
        end: pw.Alignment.bottomRight,
      ),
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                s.title.toUpperCase(),
                style: pw.TextStyle(
                  color: _gold,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                report.group.name,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                monthLabel,
                style: const pw.TextStyle(
                  color: PdfColor.fromInt(0xFFD1FAE5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              s.generated,
              style: const pw.TextStyle(
                color: PdfColor.fromInt(0xFF9DB5AB),
                fontSize: 8,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              _formatDate(now),
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _rankingTable(MonthlyGroupReport r, _PdfStrings s) {
  final goal = r.memberGoalTotal;
  final rows = <pw.TableRow>[
    pw.TableRow(
      repeat: true,
      verticalAlignment: pw.TableCellVerticalAlignment.middle,
      decoration: const pw.BoxDecoration(color: _brand),
      children: [
        _headCell('№'),
        _headCell(s.member, align: pw.TextAlign.left),
        _headCell(s.done),
        _headCell(s.monthGoal),
        _headCell(s.completion),
      ],
    ),
  ];
  for (var i = 0; i < r.members.length; i++) {
    final t = r.members[i];
    final submitted = t.reportsCount > 0;
    rows.add(
      pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        decoration: pw.BoxDecoration(color: i.isOdd ? _zebra : PdfColors.white),
        children: [
          _cell('${i + 1}', color: _muted),
          _cell(
            t.member.nickname,
            align: pw.TextAlign.left,
            color: submitted ? _ink : _muted,
            bold: submitted,
          ),
          _cell('${t.total}', bold: true, color: submitted ? _ink : _faint),
          _cell('$goal', color: _muted),
          _completionCell(completionRatio(t.total, goal), muted: !submitted),
        ],
      ),
    );
  }
  rows.add(
    pw.TableRow(
      verticalAlignment: pw.TableCellVerticalAlignment.middle,
      decoration: const pw.BoxDecoration(
        color: _softBg,
        border: pw.Border(top: pw.BorderSide(color: _accent, width: 1)),
      ),
      children: [
        _cell(''),
        _cell(s.total, align: pw.TextAlign.left, bold: true),
        _cell('${r.groupTotal}', bold: true),
        _cell('${r.groupGoalTotal}', bold: true),
        _cell(
          _formatPercent(completionRatio(r.groupTotal, r.groupGoalTotal)),
          bold: true,
        ),
      ],
    ),
  );

  return pw.Table(
    columnWidths: const {
      0: pw.FixedColumnWidth(24),
      1: pw.FlexColumnWidth(2.6),
      2: pw.FlexColumnWidth(1.2),
      3: pw.FlexColumnWidth(1.3),
      4: pw.FlexColumnWidth(2),
    },
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      bottom: pw.BorderSide(color: _line, width: 0.5),
    ),
    children: rows,
  );
}

/// Progress bar (capped at 100%) followed by the real percentage.
pw.Widget _completionCell(double? ratio, {required bool muted}) {
  final filled = ((ratio ?? 0).clamp(0.0, 1.0) * 1000).round();
  const radius = pw.BorderRadius.all(pw.Radius.circular(3));
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Container(
            height: 6,
            decoration: const pw.BoxDecoration(
              color: _track,
              borderRadius: radius,
            ),
            child: pw.Row(
              children: [
                if (filled > 0)
                  pw.Expanded(
                    flex: filled,
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        color: _completionColor(ratio),
                        borderRadius: radius,
                      ),
                    ),
                  ),
                if (filled < 1000)
                  pw.Expanded(flex: 1000 - filled, child: pw.SizedBox()),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.SizedBox(
          width: 32,
          child: pw.Text(
            _formatPercent(ratio),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              color: muted ? _faint : _ink,
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

PdfColor _completionColor(double? ratio) {
  if (ratio == null || ratio <= 0) return _faint;
  if (ratio >= 0.75) return _accent;
  if (ratio >= 0.5) return _amber;
  return _coral;
}

pw.Widget _headCell(String text, {pw.TextAlign align = pw.TextAlign.center}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

pw.Widget _cell(
  String text, {
  pw.TextAlign align = pw.TextAlign.center,
  PdfColor color = _ink,
  bool bold = false,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Text(
      text,
      textAlign: align,
      maxLines: 2,
      style: pw.TextStyle(
        color: color,
        fontSize: 9.5,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

pw.Widget _footer(pw.Context context, _PdfStrings s, DateTime now) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 10),
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _line, width: 0.5)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '${s.generated}: ${_formatDate(now)}',
          style: const pw.TextStyle(color: _muted, fontSize: 7.5),
        ),
        pw.Text(
          s.pageLabel(context.pageNumber, context.pagesCount),
          style: const pw.TextStyle(color: _muted, fontSize: 7.5),
        ),
      ],
    ),
  );
}

/// Whole percent; over-achievement is shown as is (e.g. 120%).
String _formatPercent(double? ratio) =>
    ratio == null ? '—' : '${(ratio * 100).round()}%';

String _formatDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}
