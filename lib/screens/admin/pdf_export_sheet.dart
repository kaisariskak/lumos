import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../l10n/app_strings.dart';
import '../../models/ibadat_group.dart';
import '../../reporting/monthly_group_report_loader.dart';
import '../../reporting/monthly_report_pdf.dart';
import '../../theme/accent_provider.dart';
import '../../utils/week_utils.dart';

const _sheetBg = Color(0xFF1E293B);
const _field = Color(0xFF111A1D);
const _text = Color(0xFFF8FAFC);
const _muted = Color(0xFF94A3B8);
const _gold = Color(0xFFF6C453);

/// Lets an admin pick a group and month, then opens the generated PDF.
Future<void> showPdfExportSheet(
  BuildContext context, {
  required List<IbadatGroup> groups,
  IbadatGroup? initialGroup,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PdfExportSheet(
      groups: groups,
      initialGroup: initialGroup ?? groups.first,
    ),
  );
}

class _PdfExportSheet extends StatefulWidget {
  final List<IbadatGroup> groups;
  final IbadatGroup initialGroup;

  const _PdfExportSheet({required this.groups, required this.initialGroup});

  @override
  State<_PdfExportSheet> createState() => _PdfExportSheetState();
}

class _PdfExportSheetState extends State<_PdfExportSheet> {
  late IbadatGroup _group;
  late int _month;
  late int _year;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _group = widget.groups.firstWhere(
      (g) => g.id == widget.initialGroup.id,
      orElse: () => widget.groups.first,
    );
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month == now.month && _year == now.year;
  }

  void _shiftMonth(int delta) {
    final d = DateTime(_year, _month + delta);
    setState(() {
      _month = d.month;
      _year = d.year;
      _message = null;
    });
  }

  Future<void> _generate() async {
    final s = S.of(context);
    final lang = pdfLanguageFor(s.languageCode);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final report = await loadMonthlyGroupReport(
        group: _group,
        month: _month,
        year: _year,
      );
      if (!mounted) return;
      if (!report.hasData) {
        setState(() => _message = s.pdfExportNoData);
        return;
      }
      final bytes = await buildMonthlyReportPdf(report, lang: lang);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PdfPreviewScreen(
            bytes: bytes,
            title:
                '${_group.name} · ${WeekUtils.monthLabel(_month, _year, languageCode: s.languageCode)}',
            fileName: _fileName(_group.name, _month, _year),
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _message = '${s.error}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final accent = AccentProvider.instance.current;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: _gold),
                const SizedBox(width: 8),
                Text(
                  s.pdfExportTitle,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              s.pdfExportSubtitle,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            _label(s.pdfExportGroup),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _field,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _group.id,
                  isExpanded: true,
                  dropdownColor: _sheetBg,
                  iconEnabledColor: _muted,
                  style: const TextStyle(color: _text, fontSize: 15),
                  items: [
                    for (final g in widget.groups)
                      DropdownMenuItem(value: g.id, child: Text(g.name)),
                  ],
                  onChanged: _busy
                      ? null
                      : (id) => setState(() {
                          _group = widget.groups.firstWhere((g) => g.id == id);
                          _message = null;
                        }),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _label(s.pdfExportMonth),
            Container(
              decoration: BoxDecoration(
                color: _field,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _busy ? null : () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: _text,
                  ),
                  Expanded(
                    child: Text(
                      WeekUtils.monthLabel(
                        _month,
                        _year,
                        languageCode: s.languageCode,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: (_busy || _isCurrentMonth)
                        ? null
                        : () => _shiftMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: _text,
                    disabledColor: Colors.white.withValues(alpha: 0.2),
                  ),
                ],
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFFCD34D),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          color: Color(0xFFFCD34D),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _busy ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent.accentDark,
                foregroundColor: Colors.white,
                disabledBackgroundColor: accent.accentDark.withValues(
                  alpha: 0.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.description_rounded, size: 20),
              label: Text(
                s.pdfExportGenerate,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(color: _muted, fontSize: 12)),
  );
}

String _fileName(String groupName, int month, int year) {
  final safe = groupName
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  final mm = month.toString().padLeft(2, '0');
  return '${safe.isEmpty ? 'report' : safe}_$year-$mm.pdf';
}

/// Preview with the share and print actions of the printing package
/// (print also offers "Save as PDF").
class _PdfPreviewScreen extends StatelessWidget {
  final Uint8List bytes;
  final String title;
  final String fileName;

  const _PdfPreviewScreen({
    required this.bytes,
    required this.title,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: _text,
        title: Text(title, style: const TextStyle(fontSize: 16)),
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: fileName,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }
}
