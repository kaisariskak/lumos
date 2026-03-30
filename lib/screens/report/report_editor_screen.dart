import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../models/ibadat_category.dart';
import '../../models/ibadat_group.dart';
import '../../models/ibadat_profile.dart';
import '../../models/ibadat_report.dart';
import '../../models/ibadat_period.dart';
import '../../repositories/ibadat_period_repository.dart';
import '../../repositories/ibadat_report_repository.dart';
import '../../utils/week_utils.dart';

class ReportEditorScreen extends StatefulWidget {
  final IbadatProfile profile;
  final IbadatGroup group;
  final VoidCallback? onSaved;
  final VoidCallback? onBack;

  const ReportEditorScreen({
    super.key,
    required this.profile,
    required this.group,
    this.onSaved,
    this.onBack,
  });

  @override
  State<ReportEditorScreen> createState() => _ReportEditorScreenState();
}

class _ReportEditorScreenState extends State<ReportEditorScreen> {
  late final IbadatReportRepository _repo;
  late final IbadatPeriodRepository _periodRepo;
  late final int _currentMonth;
  late final int _currentYear;
  late IbadatReport _report;
  IbadatPeriod? _period;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _repo = IbadatReportRepository(client);
    _periodRepo = IbadatPeriodRepository(client);
    final now = DateTime.now();
    _currentMonth = now.month;
    _currentYear = now.year;
    _report = IbadatReport(
      userId: widget.profile.id,
      groupId: widget.group.id,
      month: _currentMonth,
      year: _currentYear,
    );
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final results = await Future.wait([
        _repo.getReport(
          userId: widget.profile.id,
          groupId: widget.group.id,
          month: _currentMonth,
          year: _currentYear,
        ),
        _periodRepo.getPeriodsForGroup(widget.group.id),
      ]);
      final existing = results[0] as IbadatReport?;
      final periods = results[1] as List;
      setState(() {
        if (existing != null) _report = existing;
        if (periods.isNotEmpty) _period = periods.first as IbadatPeriod;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _repo.upsertReport(_report);
      widget.onSaved?.call();
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0F172A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (widget.onBack != null) {
                          widget.onBack!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chevron_left,
                                color: Color(0xFF94A3B8), size: 20),
                            Text(S.of(context).back,
                                style: const TextStyle(
                                    color: Color(0xFF94A3B8), fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF6366F1)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        child: Column(
                          children: [
                            // Header
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4F46E5),
                                    Color(0xFF7C3AED)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Center(
                                child: Text(
                                  widget.profile.displayName[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.profile.displayName,
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _period?.dateRangeLabelLocalized(S.of(context).languageCode) ?? WeekUtils.currentMonthLabel(),
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('💡',
                                      style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 6),
                                  Text(
                                    S.of(context).autoCalculated,
                                    style: TextStyle(
                                      color: Color(0xFFFCD34D),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Category sliders
                            ...IbadatCategory.all.map((cat) {
                              final val = _report.getValue(cat.key);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // Top row
                                    Row(
                                      children: [
                                        Text(cat.icon,
                                            style: const TextStyle(
                                                fontSize: 22)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                S.of(context).categoryLabel(cat.key),
                                                style: const TextStyle(
                                                  color: Color(0xFFE2E8F0),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                'макс: ${cat.weekMax} ${S.of(context).unitLabel(cat.unit)}${S.of(context).perWeek}',
                                                style: const TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: cat.color
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '$val ${S.of(context).unitLabel(cat.unit)}',
                                            style: TextStyle(
                                              color: cat.color,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Slider
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: cat.color,
                                        inactiveTrackColor: Colors.white
                                            .withValues(alpha: 0.08),
                                        thumbColor: Colors.white,
                                        overlayColor: cat.color
                                            .withValues(alpha: 0.2),
                                        trackHeight: 6,
                                        thumbShape:
                                            const RoundSliderThumbShape(
                                                enabledThumbRadius: 10),
                                      ),
                                      child: Slider(
                                        min: 0,
                                        max: cat.weekMax.toDouble(),
                                        value: val.toDouble().clamp(
                                            0, cat.weekMax.toDouble()),
                                        onChanged: (v) {
                                          setState(() {
                                            _report.setValue(
                                                cat.key, v.round());
                                          });
                                        },
                                      ),
                                    ),

                                    // Quick buttons 25/50/75/100%
                                    Row(
                                      children: [0.25, 0.5, 0.75, 1.0]
                                          .map((f) {
                                        final quickVal =
                                            (cat.weekMax * f).round();
                                        final isSelected = val == quickVal;
                                        return Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                right: 6),
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _report.setValue(
                                                      cat.key, quickVal);
                                                });
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 200),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? cat.color
                                                      : Colors.white
                                                          .withValues(
                                                              alpha: 0.05),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '$quickVal',
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF94A3B8),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            const SizedBox(height: 8),

                            // Save button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                  shadowColor:
                                      const Color(0xFF4F46E5),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        '✅ ${S.of(context).save}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
