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
import '../../theme/accent_provider.dart';
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

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CounterBtn({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Icon(icon, color: enabled ? color : const Color(0xFF475569), size: 20),
      ),
    );
  }
}

class _PeriodNavigator extends StatelessWidget {
  final List<IbadatPeriod> periods;
  final IbadatPeriod? selected;
  final ValueChanged<IbadatPeriod> onChanged;
  final String langCode;
  final Color accentColor;

  const _PeriodNavigator({
    required this.periods,
    required this.selected,
    required this.onChanged,
    required this.langCode,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final idx = selected == null ? -1 : periods.indexWhere((p) => p.id == selected!.id);
    final canPrev = idx < periods.length - 1;
    final canNext = idx > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ArrowBtn(
            icon: Icons.chevron_left,
            enabled: canPrev,
            accentColor: accentColor,
            onTap: () => onChanged(periods[idx + 1]),
          ),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF64748B), size: 13),
                const SizedBox(height: 2),
                Text(
                  selected?.dateRangeLabelLocalized(langCode) ?? '',
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          _ArrowBtn(
            icon: Icons.chevron_right,
            enabled: canNext,
            accentColor: accentColor,
            onTap: () => onChanged(periods[idx - 1]),
          ),
        ],
      ),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color accentColor;
  final VoidCallback onTap;

  const _ArrowBtn({required this.icon, required this.enabled, required this.accentColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? accentColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: enabled ? accentColor : const Color(0xFF334155),
          size: 22,
        ),
      ),
    );
  }
}

class _ReportEditorScreenState extends State<ReportEditorScreen> {
  late final IbadatReportRepository _repo;
  late final IbadatPeriodRepository _periodRepo;
  late IbadatReport _report;
  List<IbadatPeriod> _periods = [];
  IbadatPeriod? _selectedPeriod;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _repo = IbadatReportRepository(client);
    _periodRepo = IbadatPeriodRepository(client);
    final now = DateTime.now();
    _report = IbadatReport(
      userId: widget.profile.id,
      groupId: widget.group.id,
      month: now.month,
      year: now.year,
    );
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      // Repository already returns newest first (order by start_date DESC)
      final periods = await _periodRepo.getPeriodsForGroup(widget.group.id);
      final selected = periods.isNotEmpty ? periods.first : null;

      IbadatReport? existing;
      if (selected != null) {
        existing = await _repo.getReportByPeriod(
          userId: widget.profile.id,
          groupId: widget.group.id,
          periodId: selected.id,
        );
      } else {
        final now = DateTime.now();
        existing = await _repo.getReport(
          userId: widget.profile.id,
          groupId: widget.group.id,
          month: now.month,
          year: now.year,
        );
      }

      setState(() {
        _periods = periods;
        _selectedPeriod = selected;
        if (existing != null) {
          _report = existing;
        } else if (selected != null) {
          _report = IbadatReport(
            userId: widget.profile.id,
            groupId: widget.group.id,
            periodId: selected.id,
            month: selected.startDate.month,
            year: selected.startDate.year,
          );
        }
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onPeriodSelected(IbadatPeriod period) async {
    setState(() => _isLoading = true);
    try {
      final existing = await _repo.getReportByPeriod(
        userId: widget.profile.id,
        groupId: widget.group.id,
        periodId: period.id,
      );
      setState(() {
        _selectedPeriod = period;
        _report = existing ?? IbadatReport(
          userId: widget.profile.id,
          groupId: widget.group.id,
          periodId: period.id,
          month: period.startDate.month,
          year: period.startDate.year,
        );
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF0F172A), AccentProvider.instance.current.gradientMid, const Color(0xFF0F172A)],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: AccentProvider.instance.current.accent))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        child: Column(
                          children: [
                            // Header
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AccentProvider.instance.current.accentDark,
                                    AccentProvider.instance.current.accent,
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
                              _selectedPeriod?.dateRangeLabelLocalized(S.of(context).languageCode) ?? WeekUtils.currentMonthLabel(),
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                            const SizedBox(height: 10),

                            // Period selector with arrow navigation
                            if (_periods.isNotEmpty) ...[
                              _PeriodNavigator(
                                periods: _periods,
                                selected: _selectedPeriod,
                                onChanged: _onPeriodSelected,
                                langCode: S.of(context).languageCode,
                                accentColor: AccentProvider.instance.current.accent,
                              ),
                              const SizedBox(height: 10),
                            ],
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

                                    // +/- counter row
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _CounterBtn(
                                            icon: Icons.remove,
                                            color: cat.color,
                                            onTap: val > 0
                                                ? () => setState(() => _report.setValue(cat.key, val - 1))
                                                : null,
                                          ),
                                          Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 18),
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: cat.color.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$val',
                                              style: TextStyle(
                                                color: cat.color,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                          _CounterBtn(
                                            icon: Icons.add,
                                            color: cat.color,
                                            onTap: val < cat.weekMax
                                                ? () => setState(() => _report.setValue(cat.key, val + 1))
                                                : null,
                                          ),
                                        ],
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
                                  backgroundColor: AccentProvider.instance.current.accentDark,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                  shadowColor:
                                      AccentProvider.instance.current.accentDark,
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
