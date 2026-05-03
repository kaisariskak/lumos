import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';

import '../../models/group_metric.dart';
import '../../models/ibadat_period.dart';
import '../../theme/accent_provider.dart';
import '../../models/ibadat_profile.dart';
import '../../models/ibadat_report.dart';
import '../../repositories/group_metric_repository.dart';
import '../../repositories/ibadat_report_repository.dart';
import '../../reporting/report_progress.dart';
import '../../widgets/ring_indicator.dart';

class DetailScreen extends StatefulWidget {
  final IbadatProfile profile;
  final String groupId;
  final IbadatReport? report;
  final String weekLabel;
  final bool isWeekMode;
  final List<IbadatReport> monthReports;
  final List<IbadatPeriod> periods;
  final int initialPeriodIdx;
  // Non-null → viewing admin's own personal reports: metrics come from
  // getForAdmin(adminId), and period reports use the period's own groupId
  // (nullable for personal periods).
  final String? adminId;

  const DetailScreen({
    super.key,
    required this.profile,
    required this.groupId,
    required this.report,
    required this.weekLabel,
    required this.isWeekMode,
    this.monthReports = const [],
    this.periods = const [],
    this.initialPeriodIdx = 0,
    this.adminId,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late final IbadatReportRepository _repo;
  late final GroupMetricRepository _metricRepo;
  late int _periodIdx;
  IbadatReport? _report;
  List<GroupMetric> _metrics = [];
  bool _isLoading = false;

  bool get _isPeriodMode => widget.periods.isNotEmpty;
  List<GroupMetric> get _visibleMetrics =>
      _metrics.where((metric) => metric.id != null).toList();

  IbadatPeriod? get _currentPeriod =>
      _isPeriodMode ? widget.periods[_periodIdx.clamp(0, widget.periods.length - 1)] : null;

  @override
  void initState() {
    super.initState();
    _repo = IbadatReportRepository(Supabase.instance.client);
    _metricRepo = GroupMetricRepository(Supabase.instance.client);
    _periodIdx = widget.initialPeriodIdx.clamp(0, widget.periods.isEmpty ? 0 : widget.periods.length - 1);
    _report = widget.report;
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      final metrics = widget.adminId != null
          ? await _metricRepo.getForAdmin(widget.adminId!)
          : await _metricRepo.getForGroup(widget.groupId);
      if (mounted) {
        setState(() {
          _metrics = metrics;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _metrics = [];
        });
      }
    }
  }

  Future<void> _loadPeriodReport() async {
    final period = _currentPeriod;
    if (period == null) return;
    setState(() => _isLoading = true);
    try {
      final r = await _repo.getReportByPeriod(
        userId: widget.profile.id,
        groupId: widget.adminId != null ? period.groupId : widget.groupId,
        periodId: period.id,
      );
      setState(() {
        _report = r;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _goPrev() {
    if (_periodIdx < widget.periods.length - 1) {
      _periodIdx++;
      _loadPeriodReport();
    }
  }

  void _goNext() {
    if (_periodIdx > 0) {
      _periodIdx--;
      _loadPeriodReport();
    }
  }

  int _getValue(String key) {
    return _effectiveReport()?.getValue(key) ?? 0;
  }

  IbadatReport? _effectiveReport() {
    if (_isPeriodMode) return _report;
    if (widget.isWeekMode) return widget.report;
    if (widget.monthReports.isNotEmpty) {
      final aggregate = <String, int>{};
      for (final report in widget.monthReports) {
        for (final entry in report.metricValues.entries) {
          aggregate[entry.key] = (aggregate[entry.key] ?? 0) + entry.value;
        }
      }
      final source = widget.monthReports.first;
      return IbadatReport(
        userId: source.userId,
        groupId: source.groupId,
        month: source.month,
        year: source.year,
        metricValues: aggregate,
      );
    }
    return widget.report;
  }

  double _calcScore() {
    final report = _effectiveReport();
    if (report == null) return 0;
    return reportProgress(report, _visibleMetrics);
  }

  @override
  Widget build(BuildContext context) {
    final score = _calcScore();
    final accent = AccentProvider.instance.current;
    final period = _currentPeriod;

    String label;
    if (_isPeriodMode && period != null) {
      label = period.dateRangeLabelLocalized(S.of(context).languageCode);
    } else {
      label = widget.weekLabel;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF0F172A), accent.gradientMid, const Color(0xFF0F172A)],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chevron_left, color: Color(0xFF94A3B8), size: 20),
                          Text(S.of(context).back, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: accent.accent))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                        child: Column(
                          children: [
                            // Avatar
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [accent.accentDark, accent.accent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(36),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.accentDark.withValues(alpha: 0.4),
                                    blurRadius: 32,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  widget.profile.nickname[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.profile.nickname,
                              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),

                            // Period badge / navigator
                            if (_isPeriodMode)
                              _PeriodNav(
                                label: label,
                                canPrev: _periodIdx < widget.periods.length - 1,
                                canNext: _periodIdx > 0,
                                onPrev: _goPrev,
                                onNext: _goNext,
                                accentColor: accent.accent,
                                accentLight: accent.accentLight,
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: accent.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: accent.accent.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(widget.isWeekMode ? '📅' : '📆', style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 6),
                                    Text(
                                      label,
                                      style: TextStyle(color: accent.accentLight, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),

                            // Overall ring
                            RingIndicator(value: score, size: 88),
                            const SizedBox(height: 20),

                            // Metric grid
                            if (_visibleMetrics.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'Показатели ещё не настроены',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.35),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                            else
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.55,
                                children: _visibleMetrics.map((metric) {
                                  final val = _getValue(metric.id!);
                                  final pct = metricProgress(val, metric.maxValue);

                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(metric.icon, style: const TextStyle(fontSize: 18)),
                                            CategoryRing(value: pct, color: metric.color),
                                          ],
                                        ),
                                        const Spacer(),
                                        Text(
                                          '$val',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: metric.color, height: 1.0),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${metric.localizedName(S.of(context).languageCode)} · ${S.of(context).unitLabel(metric.unit)}',
                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(2),
                                          child: Stack(
                                            children: [
                                              Container(
                                                height: 3,
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.06),
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                              FractionallySizedBox(
                                                widthFactor: pct,
                                                child: Container(
                                                  height: 3,
                                                  decoration: BoxDecoration(
                                                    color: metric.color,
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
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

class _PeriodNav extends StatelessWidget {
  final String label;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Color accentColor;
  final Color accentLight;

  const _PeriodNav({
    required this.label,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.accentColor,
    required this.accentLight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavBtn(icon: Icons.chevron_left, enabled: canPrev, color: accentColor, onTap: onPrev),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📆', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(color: accentLight, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          _NavBtn(icon: Icons.chevron_right, enabled: canNext, color: accentColor, onTap: onNext),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _NavBtn({required this.icon, required this.enabled, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: enabled ? color : const Color(0xFF334155), size: 20),
      ),
    );
  }
}
