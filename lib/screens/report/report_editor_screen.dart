import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../models/group_metric.dart';
import '../../models/ibadat_group.dart';
import '../../models/ibadat_period.dart';
import '../../models/ibadat_profile.dart';
import '../../models/ibadat_report.dart';
import '../../reporting/report_deltas.dart';
import '../../reporting/report_progress.dart';
import '../../repositories/group_metric_repository.dart';
import '../../repositories/ibadat_period_repository.dart';
import '../../repositories/ibadat_report_repository.dart';
import '../../theme/accent_provider.dart';
import '../../utils/week_utils.dart';
import 'manual_value_dialog.dart';

class ReportEditorScreen extends StatefulWidget {
  final IbadatProfile profile;
  final IbadatGroup? group;
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
  State<ReportEditorScreen> createState() => ReportEditorScreenState();
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
          color: enabled
              ? color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? color : const Color(0xFF475569),
          size: 20,
        ),
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
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
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

class ReportEditorScreenState extends State<ReportEditorScreen> with WidgetsBindingObserver {
  void reloadPeriods() => _reloadPeriods();

  late final IbadatReportRepository _repo;
  late final IbadatPeriodRepository _periodRepo;
  late final GroupMetricRepository _metricRepo;

  late IbadatReport _report;
  List<IbadatPeriod> _periods = [];
  IbadatPeriod? _selectedPeriod;

  /// Unsaved per-metric amounts to add to the saved period totals in [_report].
  final Map<String, int> _deltas = {};

  List<GroupMetric> _groupMetrics = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final client = Supabase.instance.client;
    _repo = IbadatReportRepository(client);
    _periodRepo = IbadatPeriodRepository(client);
    _metricRepo = GroupMetricRepository(client);
    final now = DateTime.now();
    _report = IbadatReport(
      userId: widget.profile.id,
      groupId: widget.group?.id,
      month: now.month,
      year: now.year,
    );
    _loadExisting();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadPeriods();
    }
  }

  Future<List<IbadatPeriod>> _fetchPeriods() {
    if (widget.profile.isAdmin) {
      return _periodRepo.getPersonalPeriodsForAdmin(widget.profile.id);
    }
    return _periodRepo.getPeriodsForGroup(widget.group!.id, includePersonal: false);
  }

  Future<List<GroupMetric>> _fetchMetrics(List<IbadatPeriod> periods) {
    if (widget.profile.isAdmin) {
      return _metricRepo.getForAdmin(widget.profile.id);
    }
    final groupId = widget.group?.id ?? (periods.isNotEmpty ? periods.first.groupId : null);
    if (groupId == null) {
      return Future.value(const <GroupMetric>[]);
    }
    return _metricRepo.getForGroup(groupId);
  }

  Future<void> _reloadPeriods() async {
    try {
      final periods = await _fetchPeriods();
      final metrics = await _fetchMetrics(periods);
      if (!mounted) return;
      final newSelected = _selectedPeriod != null
          ? periods.firstWhere(
              (p) => p.id == _selectedPeriod!.id,
              orElse: () => periods.isNotEmpty ? periods.first : _selectedPeriod!,
            )
          : periods.isNotEmpty ? periods.first : null;

      // Also reload the report for the (possibly new) selected period so
      // that _report.periodId matches _selectedPeriod.id before any save.
      IbadatReport? refreshedReport;
      if (newSelected != null) {
        refreshedReport = await _repo.getReportByPeriod(
          userId: widget.profile.id,
          groupId: newSelected.groupId,
          periodId: newSelected.id,
        );
      }
      if (!mounted) return;

      setState(() {
        if (newSelected?.id != _selectedPeriod?.id) _deltas.clear();
        _periods = periods;
        _selectedPeriod = newSelected;
        _groupMetrics = metrics;
        if (newSelected != null) {
          _report = refreshedReport ?? IbadatReport(
            userId: widget.profile.id,
            groupId: newSelected.groupId,
            periodId: newSelected.id,
            month: newSelected.startDate.month,
            year: newSelected.startDate.year,
          );
        }
      });
    } catch (_) {
      // Keep the current editor state if background refresh fails.
    }
  }

  Future<void> _loadExisting() async {
    try {
      final periods = await _fetchPeriods();
      final metrics = await _fetchMetrics(periods);
      final selected = periods.isNotEmpty ? periods.first : null;

      IbadatReport? existing;
      if (selected != null) {
        existing = await _repo.getReportByPeriod(
          userId: widget.profile.id,
          groupId: selected.groupId,
          periodId: selected.id,
        );
      } else if (widget.group != null) {
        final now = DateTime.now();
        existing = await _repo.getReport(
          userId: widget.profile.id,
          groupId: widget.group!.id,
          month: now.month,
          year: now.year,
        );
      }

      if (!mounted) return;
      setState(() {
        _periods = periods;
        _groupMetrics = metrics;
        _selectedPeriod = selected;
        if (existing != null) {
          _report = existing;
        } else if (selected != null) {
          _report = IbadatReport(
            userId: widget.profile.id,
            groupId: selected.groupId,
            periodId: selected.id,
            month: selected.startDate.month,
            year: selected.startDate.year,
          );
        }
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onPeriodSelected(IbadatPeriod period) async {
    setState(() => _isLoading = true);
    try {
      final existing = await _repo.getReportByPeriod(
        userId: widget.profile.id,
        groupId: period.groupId,
        periodId: period.id,
      );
      if (!mounted) return;
      setState(() {
        _selectedPeriod = period;
        _deltas.clear();
        _report = existing ?? IbadatReport(
          userId: widget.profile.id,
          groupId: period.groupId,
          periodId: period.id,
          month: period.startDate.month,
          year: period.startDate.year,
        );
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setDelta(String metricId, int delta) {
    setState(() {
      if (delta == 0) {
        _deltas.remove(metricId);
      } else {
        _deltas[metricId] = delta;
      }
    });
  }

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

  List<GroupMetric> get _visibleMetrics => _groupMetrics.where((metric) => metric.id != null).toList();

  Widget _buildEmptyMetricsState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: Color(0xFF94A3B8), size: 34),
          const SizedBox(height: 10),
          Text(
            S.of(context).customCatEmptyTitle,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            S.of(context).customCatEmptyHint,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, GroupMetric metric) {
    final s = S.of(context);
    final metricId = metric.id!;
    final total = _report.valueForMetric(metricId);
    final delta = _deltas[metricId] ?? 0;
    final result = total + delta;
    final unit = s.unitLabel(metric.unit);
    final sliderMax = metric.maxValue > 0 ? metric.maxValue.toDouble() : 1.0;
    final sliderValue = delta.clamp(0, metric.maxValue > 0 ? metric.maxValue : 1).toDouble();
    final quickValues = quickValuesFor(metric);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(metric.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.localizedName(s.languageCode),
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Макс: ${metric.maxValue} ${s.unitLabel(metric.unit)}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
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
                      '$total $unit',
                      style: TextStyle(
                        color: metric.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (result > metric.maxValue) ...[
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
                        '+${result - metric.maxValue}',
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
            ],
          ),
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
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: metric.color,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: Colors.white,
              overlayColor: metric.color.withValues(alpha: 0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              min: 0,
              max: sliderMax,
              value: sliderValue,
              onChanged: (newValue) => _setDelta(metricId, newValue.round()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CounterBtn(
                  icon: Icons.remove,
                  color: metric.color,
                  onTap: delta > -total
                      ? () => _setDelta(metricId, delta - 1)
                      : null,
                ),
                GestureDetector(
                  onTap: () async {
                    final entered = await showDialog<int>(
                      context: context,
                      builder: (_) => ManualValueDialog(
                        current: delta < 0 ? 0 : delta,
                        unitLabel: s.unitLabel(metric.unit),
                        color: metric.color,
                        title: s.manualValueTitle,
                        hint: s.manualValueHint(metric.maxValue, s.unitLabel(metric.unit)),
                        saveLabel: s.save,
                        cancelLabel: s.cancel,
                      ),
                    );
                    if (entered != null && mounted) {
                      _setDelta(metricId, entered);
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
                      delta < 0 ? '−${-delta}' : '$delta',
                      style: TextStyle(
                        color: metric.color,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                _CounterBtn(
                  icon: Icons.add,
                  color: metric.color,
                  onTap: () => _setDelta(metricId, delta + 1),
                ),
              ],
            ),
          ),
          Row(
            children: quickValues.map((quickValue) {
              final isSelected = delta == quickValue;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => _setDelta(metricId, quickValue),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? metric.color : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$quickValue',
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
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
            colors: [
              const Color(0xFF0F172A),
              AccentProvider.instance.current.gradientMid,
              const Color(0xFF0F172A),
            ],
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
                          color: AccentProvider.instance.current.accent,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        child: Column(
                          children: [
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
                                  widget.profile.nickname[0].toUpperCase(),
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
                              widget.profile.nickname,
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedPeriod?.dateRangeLabelLocalized(S.of(context).languageCode) ??
                                  WeekUtils.currentMonthLabel(
                                    languageCode: S.of(context).languageCode,
                                  ),
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                            const SizedBox(height: 10),
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
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lightbulb_outline, color: Color(0xFFFCD34D), size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    S.of(context).autoCalculated,
                                    style: const TextStyle(
                                      color: Color(0xFFFCD34D),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_visibleMetrics.isEmpty)
                              _buildEmptyMetricsState(context)
                            else
                              ..._visibleMetrics.map((metric) => _buildMetricCard(context, metric)),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (_isSaving || _visibleMetrics.isEmpty)
                                    ? null
                                    : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AccentProvider.instance.current.accentDark,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                  shadowColor: AccentProvider.instance.current.accentDark,
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
                                        S.of(context).save,
                                        style: const TextStyle(
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
