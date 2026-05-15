import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../groups/group_member_filter.dart';
import '../../models/group_metric.dart';
import '../../models/ibadat_group.dart';
import '../../models/ibadat_profile.dart';
import '../../models/ibadat_report.dart';
import '../../models/ibadat_period.dart';
import '../../reporting/report_progress.dart';
import '../../repositories/ibadat_group_repository.dart';
import '../../repositories/group_metric_repository.dart';
import '../../repositories/ibadat_period_repository.dart';
import '../../repositories/ibadat_report_repository.dart';
import '../../theme/accent_provider.dart';
import '../../utils/perf_log.dart';
import '../../utils/week_utils.dart';
import '../../widgets/ring_indicator.dart';
import '../detail/detail_screen.dart';

// ── Data container for one group ──────────────────────────────────────────────
class _GroupSection {
  final IbadatGroup group;
  List<IbadatProfile> members = [];
  List<GroupMetric> metrics = [];
  List<IbadatPeriod> periods = []; // group periods (for members)
  int periodIdx = 0;
  // month → userId → report
  Map<int, Map<String, IbadatReport>> trendReports = {};
  Map<String, IbadatReport> monthlyReports = {};
  bool expanded = false;

  _GroupSection({required this.group});

  int get viewMonth => periods.isNotEmpty
      ? periods[periodIdx.clamp(0, periods.length - 1)].startDate.month
      : DateTime.now().month;

  int get viewYear => periods.isNotEmpty
      ? periods[periodIdx.clamp(0, periods.length - 1)].startDate.year
      : DateTime.now().year;

  bool get isPeriodMode => periods.isNotEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final IbadatProfile profile;
  final IbadatGroup?
  group; // null allowed only for admin without a selected group
  final VoidCallback onSwitchGroup;

  const HomeScreen({
    super.key,
    required this.profile,
    required this.group,
    required this.onSwitchGroup,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  // Silent reload — no spinner, used when switching tabs so UX stays smooth.
  void reload() => _silentReload();

  Future<void> _silentReload() async {
    final version = ++_loadVersion;
    try {
      if (_isAdmin && !_isSuperAdmin) {
        await _loadAdminData(version);
      } else {
        await _loadUserData(version);
      }
    } catch (_) {}
  }

  late final IbadatGroupRepository _groupRepo;
  late final IbadatReportRepository _reportRepo;
  late final GroupMetricRepository _metricRepo;
  late final IbadatPeriodRepository _periodRepo;

  bool _isLoading = true;

  // Admin: list of group sections
  List<_GroupSection> _sections = [];
  int _adminPeriodIdx = 0; // period index for admin's own report card
  List<GroupMetric> _adminPersonalMetrics = [];
  List<IbadatPeriod> _adminPeriods = [];
  IbadatReport? _adminReport;
  int _loadVersion = 0; // guard against stale concurrent reloads

  // Non-admin (user): single group data
  List<IbadatProfile> _userMembers = [];
  List<GroupMetric> _userMetrics = [];
  Map<String, IbadatReport> _userMonthlyReports = {};
  Map<int, Map<String, IbadatReport>> _userTrendReports = {};
  List<IbadatPeriod> _userPeriods = [];
  int _userPeriodIdx = 0;
  int _viewMonth = DateTime.now().month;
  int _viewYear = DateTime.now().year;

  bool get _isAdmin => widget.profile.isAdmin;
  bool get _isSuperAdmin => widget.profile.isSuperAdmin;

  static List<(int, int)> _lastFourMonths(int month, int year) {
    return List.generate(4, (i) {
      int m = month - (3 - i);
      int y = year;
      while (m < 1) {
        m += 12;
        y--;
      }
      return (m, y);
    });
  }

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _groupRepo = IbadatGroupRepository(client);
    _reportRepo = IbadatReportRepository(client);
    _metricRepo = GroupMetricRepository(client);
    _periodRepo = IbadatPeriodRepository(client);
    _loadData();
  }

  Future<void> _loadData() async {
    await traceAsync('HomeScreen._loadData', () async {
      final version = ++_loadVersion;
      setState(() => _isLoading = true);
      try {
        if (_isAdmin && !_isSuperAdmin) {
          await _loadAdminData(version);
        } else {
          await _loadUserData(version);
        }
      } catch (_) {
        // ignore
      } finally {
        // Always clear the spinner so it never gets stuck when a silentReload
        // incremented _loadVersion while this initial load was still running.
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  // ── Admin: load all groups this admin owns ──────────────────────────────────
  Future<void> _loadAdminData(int version) async {
    await traceAsync('HomeScreen._loadAdminData', () async {
      final allGroups = await _groupRepo.getAllGroups();
      final myGroups = allGroups
          .where((g) => g.adminId == widget.profile.id)
          .toList();

      // Load sections, personal metrics, and admin's personal periods in parallel.
      // Admin periods are loaded at state level so the self-report card works
      // even before any group is created.
      final sectionsFuture = Future.wait(myGroups.map(_loadSection));
      final personalMetricsFuture = _metricRepo.getForAdmin(widget.profile.id);
      final adminPeriodsFuture = _periodRepo.getPersonalPeriodsForAdmin(
        widget.profile.id,
      );

      final sections = await sectionsFuture;
      final personalMetrics = await personalMetricsFuture;
      final adminPeriods = (await adminPeriodsFuture).reversed
          .toList(); // oldest first

      if (mounted && _loadVersion == version) {
        setState(() {
          _sections = sections;
          _adminPersonalMetrics = personalMetrics;
          _adminPeriods = adminPeriods;
        });
        unawaited(_loadAdminReports(version, sections, adminPeriods));
      }
    });
  }

  Future<_GroupSection> _loadSection(IbadatGroup group) async {
    return traceAsync(
      'HomeScreen._loadSection group=${group.id}',
      () async {
        final section = _GroupSection(group: group);

        final results = await Future.wait([
          _groupRepo.getGroupMembers(group.id),
          _metricRepo.getForGroup(group.id),
          _periodRepo.getPeriodsForGroup(group.id, includePersonal: false),
        ]);

        section.members = visibleGroupMembers(
          results[0] as List<IbadatProfile>,
          adminId: group.adminId,
        );
        section.metrics = results[1] as List<GroupMetric>;
        final periodsRaw = results[2] as List<IbadatPeriod>;
        section.periods = periodsRaw.reversed.toList(); // oldest first

        return section;
      },
      describeResult: (section) =>
          'members=${section.members.length} metrics=${section.metrics.length} periods=${section.periods.length}',
    );
  }

  Future<void> _loadAdminReports(
    int version,
    List<_GroupSection> sections,
    List<IbadatPeriod> adminPeriods,
  ) async {
    await traceAsync('HomeScreen._loadAdminReports', () async {
      await Future.wait(sections.map(_loadSectionReports));
      final adminReport = await _fetchAdminReport(adminPeriods);
      if (!mounted || _loadVersion != version) return;
      setState(() => _adminReport = adminReport);
    });
  }

  Future<void> _loadSectionReports(_GroupSection section) async {
    final trace = Stopwatch()..start();
    if (perfLogsEnabled) {
      debugPrint(
        '[PERF] START HomeScreen._loadSectionReports group=${section.group.id}',
      );
    }

    if (section.isPeriodMode) {
      final periodIdx = section.periodIdx.clamp(0, section.periods.length - 1);
      final currentPeriod = section.periods[periodIdx];
      final trendPeriods = section.periods.take(4).toList();

      // Current period may already be in the trend window — fetch each unique
      // period once, then reuse the result for both current + trend slots.
      final uniquePeriodsById = <String, IbadatPeriod>{};
      for (final p in trendPeriods) {
        uniquePeriodsById[p.id] = p;
      }
      uniquePeriodsById[currentPeriod.id] = currentPeriod;
      final uniquePeriods = uniquePeriodsById.values.toList();

      final results = await Future.wait(
        uniquePeriods.map(
          (p) => _reportRepo.getGroupReportsByPeriod(
            groupId: section.group.id,
            periodId: p.id,
          ),
        ),
      );
      final reportsByPeriodId = <String, List<IbadatReport>>{
        for (var i = 0; i < uniquePeriods.length; i++)
          uniquePeriods[i].id: results[i],
      };

      section.monthlyReports = {
        for (final r in reportsByPeriodId[currentPeriod.id] ?? const [])
          r.userId: r,
      };
      section.trendReports = {
        for (final p in trendPeriods)
          p.startDate.month: {
            for (final r in reportsByPeriodId[p.id] ?? const []) r.userId: r,
          },
      };
    } else {
      final month = section.viewMonth;
      final year = section.viewYear;
      final monthsAndYears = _lastFourMonths(month, year);

      final results = await Future.wait(
        monthsAndYears.map(
          (pair) => _reportRepo.getGroupReports(
            groupId: section.group.id,
            month: pair.$1,
            year: pair.$2,
          ),
        ),
      );

      // _lastFourMonths returns oldest→newest, so current = last entry.
      section.monthlyReports = {
        for (final r in results.last) r.userId: r,
      };
      section.trendReports = {
        for (var i = 0; i < monthsAndYears.length; i++)
          monthsAndYears[i].$1: {
            for (final r in results[i]) r.userId: r,
          },
      };
    }

    if (perfLogsEnabled) {
      debugPrint(
        '[PERF] END HomeScreen._loadSectionReports group=${section.group.id} '
        '${trace.elapsedMilliseconds}ms currentReports=${section.monthlyReports.length} '
        'trendBuckets=${section.trendReports.length}',
      );
    }

    // Admin's own report — loaded separately by _loadAdminReport
  }

  Future<IbadatReport?> _fetchAdminReport(
    List<IbadatPeriod> adminPeriods,
  ) async {
    if (adminPeriods.isNotEmpty) {
      final period =
          adminPeriods[_adminPeriodIdx.clamp(0, adminPeriods.length - 1)];
      return _reportRepo.getReportByPeriod(
        userId: widget.profile.id,
        groupId: period.groupId,
        periodId: period.id,
      );
    }
    final now = DateTime.now();
    return _reportRepo.getReport(
      userId: widget.profile.id,
      groupId: null,
      month: now.month,
      year: now.year,
    );
  }

  Future<void> _reloadAdminReport() async {
    final report = await _fetchAdminReport(_adminPeriods);
    if (mounted) setState(() => _adminReport = report);
  }

  /// Loads only the user's own report for the currently selected period/month.
  /// Called when navigating periods so we don't reload everything.
  Future<void> _loadUserReport() async {
    final isPeriodMode = _userPeriods.isNotEmpty;
    final Map<String, IbadatReport> monthly = {};
    if (isPeriodMode) {
      final period =
          _userPeriods[_userPeriodIdx.clamp(0, _userPeriods.length - 1)];
      final r = await _reportRepo.getReportByPeriod(
        userId: widget.profile.id,
        groupId: widget.group!.id,
        periodId: period.id,
      );
      if (r != null) monthly[r.userId] = r;
    } else {
      final r = await _reportRepo.getReport(
        userId: widget.profile.id,
        groupId: widget.group!.id,
        month: _viewMonth,
        year: _viewYear,
      );
      if (r != null) monthly[r.userId] = r;
    }
    if (mounted) setState(() => _userMonthlyReports = monthly);
  }

  // ── User: single group ──────────────────────────────────────────────────────
  Future<void> _loadUserData([int? version]) async {
    await traceAsync('HomeScreen._loadUserData', () async {
      final loadVersion = version ?? ++_loadVersion;
      final results = await Future.wait([
        _groupRepo.getGroupMembers(widget.group!.id),
        _metricRepo.getForGroup(widget.group!.id),
        _periodRepo.getPeriodsForGroup(widget.group!.id, includePersonal: false),
      ]);
      final members = visibleGroupMembers(
        results[0] as List<IbadatProfile>,
        adminId: widget.group!.adminId,
      );
      final metrics = results[1] as List<GroupMetric>;
      final loadedPeriods = results[2] as List<IbadatPeriod>;
      final periods = loadedPeriods.reversed.toList();

      final isPeriodMode = periods.isNotEmpty;
      int viewMonth = _viewMonth;
      int viewYear = _viewYear;
      if (isPeriodMode) {
        final idx = _userPeriodIdx.clamp(0, periods.length - 1);
        viewMonth = periods[idx].startDate.month;
        viewYear = periods[idx].startDate.year;
      }

      if (mounted && _loadVersion == loadVersion) {
        setState(() {
          _userMembers = members;
          _userMetrics = metrics;
          _userPeriods = periods;
          _viewMonth = viewMonth;
          _viewYear = viewYear;
        });
        unawaited(
          _loadUserReports(
            loadVersion,
            periods,
            _userPeriodIdx,
            viewMonth,
            viewYear,
          ),
        );
      }
    });
  }

  Future<void> _loadUserReports(
    int version,
    List<IbadatPeriod> periods,
    int periodIdx,
    int viewMonth,
    int viewYear,
  ) async {
    await traceAsync('HomeScreen._loadUserReports', () async {
      final isPeriodMode = periods.isNotEmpty;
      final monthly = <String, IbadatReport>{};
      final trend = <int, Map<String, IbadatReport>>{};

      if (isPeriodMode) {
        final clampedIdx = periodIdx.clamp(0, periods.length - 1);
        final currentPeriod = periods[clampedIdx];
        final trendPeriods = periods.take(4).toList();

        final uniquePeriodsById = <String, IbadatPeriod>{};
        for (final p in trendPeriods) {
          uniquePeriodsById[p.id] = p;
        }
        uniquePeriodsById[currentPeriod.id] = currentPeriod;
        final uniquePeriods = uniquePeriodsById.values.toList();

        final results = await Future.wait(
          uniquePeriods.map(
            (p) => _reportRepo.getReportByPeriod(
              userId: widget.profile.id,
              groupId: widget.group!.id,
              periodId: p.id,
            ),
          ),
        );
        final reportByPeriodId = <String, IbadatReport?>{
          for (var i = 0; i < uniquePeriods.length; i++)
            uniquePeriods[i].id: results[i],
        };

        final current = reportByPeriodId[currentPeriod.id];
        if (current != null) monthly[current.userId] = current;

        for (final p in trendPeriods) {
          final r = reportByPeriodId[p.id];
          trend[p.startDate.month] = r != null ? {r.userId: r} : {};
        }
      } else {
        final monthsAndYears = _lastFourMonths(viewMonth, viewYear);
        final results = await Future.wait(
          monthsAndYears.map(
            (pair) => _reportRepo.getReport(
              userId: widget.profile.id,
              groupId: widget.group!.id,
              month: pair.$1,
              year: pair.$2,
            ),
          ),
        );

        // _lastFourMonths returns oldest→newest; current = last entry.
        final current = results.last;
        if (current != null) monthly[current.userId] = current;

        for (var i = 0; i < monthsAndYears.length; i++) {
          final r = results[i];
          trend[monthsAndYears[i].$1] = r != null ? {r.userId: r} : {};
        }
      }

      if (!mounted || _loadVersion != version) return;
      setState(() {
        _userMonthlyReports = monthly;
        _userTrendReports = trend;
      });
    });
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  double _calcScore(
    String userId,
    Map<String, IbadatReport> monthly,
    List<GroupMetric> metrics,
  ) {
    final report = monthly[userId];
    if (report == null) return 0;
    return reportProgress(report, metrics);
  }

  List<int> _trendValues(
    String userId,
    Map<int, Map<String, IbadatReport>> trendReports,
    int month,
    int year,
    List<GroupMetric> metrics,
  ) {
    final months = _lastFourMonths(month, year);
    final primaryMetricId = metrics.isNotEmpty ? metrics.first.id : null;
    return months.map((pair) {
      final r = trendReports[pair.$1]?[userId];
      if (r == null || primaryMetricId == null) return 0;
      return r.valueForMetric(primaryMetricId);
    }).toList();
  }

  // ── Period navigation ────────────────────────────────────────────────────────

  void _prevMonth() {
    setState(() {
      _viewMonth--;
      if (_viewMonth < 1) {
        _viewMonth = 12;
        _viewYear--;
      }
    });
    _loadUserData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_viewYear > now.year ||
        (_viewYear == now.year && _viewMonth >= now.month)) {
      return;
    }
    setState(() {
      _viewMonth++;
      if (_viewMonth > 12) {
        _viewMonth = 1;
        _viewYear++;
      }
    });
    _loadUserData();
  }

  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final accent = AccentProvider.instance.current.accent;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 80),
                children: [
                  _buildHeader(s),
                  const SizedBox(height: 16),
                  if (_isAdmin && !_isSuperAdmin)
                    ..._buildAdminContent(s)
                  else
                    ..._buildUserContent(s),
                ],
              ),
            ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppStrings s) {
    final accent = AccentProvider.instance.current;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.greeting,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              Text(
                '${widget.profile.nickname.split(' ').first} 👋',
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: widget.onSwitchGroup,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.accentLight, accent.accentDark],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                widget.profile.nickname[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Admin view: multiple groups ──────────────────────────────────────────────

  List<Widget> _buildAdminContent(AppStrings s) {
    final totalMembers = _sections.fold(
      0,
      (sum, sec) => sum + sec.members.length,
    );

    return [
      // Combined admin card: profile info + period nav + own report.
      // Shown even when the admin has no groups yet — they still submit
      // personal reports that need to be visible here.
      Builder(
        builder: (context) {
          final accent = AccentProvider.instance.current;
          final sec = _sections.isEmpty
              ? null
              : _sections.firstWhere(
                  (sec) => sec.group.id == widget.profile.currentGroupId,
                  orElse: () => _sections.first,
                );
          final periods = _adminPeriods;
          final hasPeriods = periods.isNotEmpty;
          final pidx = _adminPeriodIdx.clamp(
            0,
            hasPeriods ? periods.length - 1 : 0,
          );
          final adminReport = _adminReport;
          final adminMetrics = _adminPersonalMetrics;
          final score = adminReport != null
              ? _calcScore(widget.profile.id, {
                  widget.profile.id: adminReport,
                }, adminMetrics)
              : 0.0;
          final trend = sec != null
              ? _trendValues(
                  widget.profile.id,
                  sec.trendReports,
                  sec.viewMonth,
                  sec.viewYear,
                  adminMetrics,
                )
              : const <int>[];

          return GestureDetector(
            onTap: () {
              final now = DateTime.now();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DetailScreen(
                    profile: widget.profile,
                    groupId: sec?.group.id ?? '',
                    adminId: widget.profile.id,
                    report: adminReport,
                    weekLabel: WeekUtils.monthLabel(
                      sec?.viewMonth ?? now.month,
                      sec?.viewYear ?? now.year,
                    ),
                    isWeekMode: false,
                    monthReports: sec != null
                        ? sec.trendReports.values
                              .map((m) => m[widget.profile.id])
                              .whereType<IbadatReport>()
                              .toList()
                        : const <IbadatReport>[],
                    periods: periods,
                    initialPeriodIdx: pidx,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.accent.withValues(alpha: 0.15),
                    accent.gradientMid.withValues(alpha: 0.26),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  // Top row: avatar + name + stats
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent.accentLight, accent.accentDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            widget.profile.nickname[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.profile.nickname,
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '👑 ${s.groupAdminLabel}',
                              style: TextStyle(
                                color: accent.accentLight,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_sections.length}',
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            s.groupLabel,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalMembers',
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            s.memberCount,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.08),
                    height: 1,
                  ),
                  const SizedBox(height: 10),
                  // Period navigator
                  if (hasPeriods)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: pidx < periods.length - 1
                              ? () async {
                                  setState(() => _adminPeriodIdx = pidx + 1);
                                  await _reloadAdminReport();
                                }
                              : null,
                          icon: Icon(
                            Icons.chevron_left,
                            color: pidx < periods.length - 1
                                ? accent.accentLight
                                : const Color(0xFF334155),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        Text(
                          periods[pidx].dateRangeLabelLocalized(s.languageCode),
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        IconButton(
                          onPressed: pidx > 0
                              ? () async {
                                  setState(() => _adminPeriodIdx = pidx - 1);
                                  await _reloadAdminReport();
                                }
                              : null,
                          icon: Icon(
                            Icons.chevron_right,
                            color: pidx > 0
                                ? accent.accentLight
                                : const Color(0xFF334155),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  if (hasPeriods) const SizedBox(height: 8),
                  // Report stats row
                  _AdminReportRow(
                    report: adminReport,
                    score: score,
                    trend: trend,
                    metrics: adminMetrics,
                  ),
                ],
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 16),

      if (_sections.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                const Text('👥', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  s.noMembers,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        )
      else
        ..._sections.map((section) => _buildGroupSection(section, s)),
    ];
  }

  Widget _buildGroupSection(_GroupSection section, AppStrings s) {
    final accent = AccentProvider.instance.current;
    final totalMembers = section.members.length;
    final allScores = section.members
        .map((m) => _calcScore(m.id, section.monthlyReports, section.metrics))
        .toList();
    final groupScore = allScores.isEmpty
        ? 0.0
        : allScores.fold(0.0, (s, v) => s + v) / allScores.length;

    final sorted = List<IbadatProfile>.from(section.members);
    sorted.sort(
      (a, b) => _calcScore(
        b.id,
        section.monthlyReports,
        section.metrics,
      ).compareTo(_calcScore(a.id, section.monthlyReports, section.metrics)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header — tap to expand/collapse
        GestureDetector(
          onTap: () => setState(() => section.expanded = !section.expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.accent.withValues(alpha: 0.1),
                  accent.gradientMid.withValues(alpha: 0.22),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Text('👥', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.group.name,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '$totalMembers ${s.memberCount}  ·  ${(groupScore * 100).round()}%',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Period label
                if (section.isPeriodMode)
                  Text(
                    section
                        .periods[section.periodIdx.clamp(
                          0,
                          section.periods.length - 1,
                        )]
                        .dateRangeLabelLocalized(s.languageCode),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: section.expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Progress bar
        if (section.expanded) ...[
          const SizedBox(height: 8),
          _GroupProgressBar(
            groupName: section.group.name,
            memberCount: totalMembers,
            score: groupScore,
          ),
        ],

        // Period navigator
        if (section.expanded &&
            section.isPeriodMode &&
            section.periods.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildPeriodNav(section, s),
          ),

        // Members list
        if (section.expanded) ...[
          const SizedBox(height: 8),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  s.noMembers,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...sorted.asMap().entries.map((entry) {
              final idx = entry.key;
              final member = entry.value;
              final score = _calcScore(
                member.id,
                section.monthlyReports,
                section.metrics,
              );
              final trend = _trendValues(
                member.id,
                section.trendReports,
                section.viewMonth,
                section.viewYear,
                section.metrics,
              );
              final isMe = member.id == widget.profile.id;
              final medal = idx == 0
                  ? '🥇'
                  : idx == 1
                  ? '🥈'
                  : idx == 2
                  ? '🥉'
                  : null;

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DetailScreen(
                        profile: member,
                        groupId: section.group.id,
                        report: section.monthlyReports[member.id],
                        weekLabel: WeekUtils.monthLabel(
                          section.viewMonth,
                          section.viewYear,
                        ),
                        isWeekMode: false,
                        monthReports: section.trendReports.values
                            .map((m) => m[member.id])
                            .whereType<IbadatReport>()
                            .toList(),
                        periods: section.periods,
                        initialPeriodIdx: section.periodIdx,
                      ),
                    ),
                  );
                },
                child: _MemberTile(
                  member: member,
                  isMe: isMe,
                  rank: idx,
                  medal: medal,
                  score: score,
                  trend: trend,
                  report: section.monthlyReports[member.id],
                  metrics: section.metrics,
                ),
              );
            }),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPeriodNav(_GroupSection section, AppStrings s) {
    final accentLight = AccentProvider.instance.current.accentLight;
    final idx = section.periodIdx.clamp(0, section.periods.length - 1);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: idx > 0
                ? () async {
                    setState(() => section.periodIdx--);
                    await _loadSectionReports(section);
                    if (mounted) setState(() {});
                  }
                : null,
            icon: Icon(
              Icons.chevron_left,
              color: idx > 0 ? accentLight : const Color(0xFF334155),
            ),
          ),
          Column(
            children: [
              Text(
                section.periods[idx].dateRangeLabelLocalized(s.languageCode),
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                section.periods[idx].label,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
          IconButton(
            onPressed: idx < section.periods.length - 1
                ? () async {
                    setState(() => section.periodIdx++);
                    await _loadSectionReports(section);
                    if (mounted) setState(() {});
                  }
                : null,
            icon: Icon(
              Icons.chevron_right,
              color: idx < section.periods.length - 1
                  ? accentLight
                  : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // ── User view: single group, only own report ─────────────────────────────────

  List<Widget> _buildUserContent(AppStrings s) {
    final accent = AccentProvider.instance.current;
    final me = _userMembers.where((m) => m.id == widget.profile.id).toList();
    final score = me.isEmpty
        ? 0.0
        : _calcScore(me.first.id, _userMonthlyReports, _userMetrics);
    final trend = _trendValues(
      widget.profile.id,
      _userTrendReports,
      _viewMonth,
      _viewYear,
      _userMetrics,
    );

    return [
      // Group badge — tap to see group / switch
      GestureDetector(
        onTap: widget.onSwitchGroup,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: accent.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: accent.accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👥', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                widget.group!.name,
                style: TextStyle(
                  color: accent.accentLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      _GroupProgressBar(
        groupName: widget.group!.name,
        memberCount: _userMembers.length,
        score: score,
      ),

      // Period / month navigator
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: _userPeriods.isNotEmpty
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _userPeriodIdx > 0
                        ? () async {
                            setState(() => _userPeriodIdx--);
                            await _loadUserReport();
                          }
                        : null,
                    icon: Icon(
                      Icons.chevron_left,
                      color: _userPeriodIdx > 0
                          ? accent.accentLight
                          : const Color(0xFF334155),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        _userPeriods[_userPeriodIdx.clamp(
                              0,
                              _userPeriods.length - 1,
                            )]
                            .dateRangeLabelLocalized(s.languageCode),
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _userPeriods[_userPeriodIdx.clamp(
                              0,
                              _userPeriods.length - 1,
                            )]
                            .label,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _userPeriodIdx < _userPeriods.length - 1
                        ? () async {
                            setState(() => _userPeriodIdx++);
                            await _loadUserReport();
                          }
                        : null,
                    icon: Icon(
                      Icons.chevron_right,
                      color: _userPeriodIdx < _userPeriods.length - 1
                          ? accent.accentLight
                          : const Color(0xFF334155),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _prevMonth,
                    icon: Icon(Icons.chevron_left, color: accent.accentLight),
                  ),
                  Text(
                    WeekUtils.monthLabel(_viewMonth, _viewYear),
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final now = DateTime.now();
                      if (_viewYear < now.year ||
                          (_viewYear == now.year && _viewMonth < now.month)) {
                        _nextMonth();
                      }
                    },
                    icon: Icon(
                      Icons.chevron_right,
                      color:
                          (_viewYear < DateTime.now().year ||
                              (_viewYear == DateTime.now().year &&
                                  _viewMonth < DateTime.now().month))
                          ? accent.accentLight
                          : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
      ),
      const SizedBox(height: 12),

      // My card
      if (me.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              s.noMembers,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 15),
            ),
          ),
        )
      else
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DetailScreen(
                  profile: me.first,
                  groupId: widget.group!.id,
                  report: _userMonthlyReports[me.first.id],
                  weekLabel: WeekUtils.monthLabel(_viewMonth, _viewYear),
                  isWeekMode: false,
                  monthReports: _userTrendReports.values
                      .map((m) => m[me.first.id])
                      .whereType<IbadatReport>()
                      .toList(),
                  periods: _userPeriods,
                  initialPeriodIdx: _userPeriodIdx,
                ),
              ),
            );
          },
          child: _MemberTile(
            member: me.first,
            isMe: true,
            rank: 0,
            medal: null,
            score: score,
            trend: trend,
            report: _userMonthlyReports[me.first.id],
            metrics: _userMetrics,
            showRank: false,
          ),
        ),
    ];
  }
}

// ── Reusable member tile ───────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  static const List<Color> _fallbackRankColors = [
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFF8B5CF6),
  ];

  final IbadatProfile member;
  final bool isMe;
  final int rank;
  final String? medal;
  final double score;
  final List<int> trend;
  final IbadatReport? report;
  final List<GroupMetric> metrics;
  final bool showRank;

  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.rank,
    required this.medal,
    required this.score,
    required this.trend,
    required this.report,
    required this.metrics,
    this.showRank = true,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final accent = AccentProvider.instance.current;
    final catColor = metrics.isNotEmpty
        ? metrics[rank % metrics.length].color
        : _fallbackRankColors[rank % _fallbackRankColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: rank == 0
            ? LinearGradient(
                colors: [
                  const Color(0xFFFBBF24).withValues(alpha: 0.08),
                  const Color(0xFFF59E0B).withValues(alpha: 0.04),
                ],
              )
            : null,
        color: rank == 0 ? null : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? accent.accent.withValues(alpha: 0.3)
              : rank == 0
              ? const Color(0xFFFBBF24).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          // Rank
          if (showRank)
            SizedBox(
              width: 28,
              child: medal != null
                  ? Text(medal!, style: const TextStyle(fontSize: 18))
                  : Text(
                      '${rank + 1}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),

          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  catColor.withValues(alpha: 0.4),
                  catColor.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    member.nickname[0].toUpperCase(),
                    style: TextStyle(
                      color: catColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                if (member.isAdmin)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('👑', style: TextStyle(fontSize: 8)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Name + chips
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member.nickname.split(' ').first,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          s.youLabel,
                          style: TextStyle(
                            color: accent.accentLight,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                _CategoryChips(report: report, metrics: metrics),
              ],
            ),
          ),

          // Progress ring
          Column(
            children: [
              RingIndicator(value: score, size: 46),
              if (report != null && _hasPointMetrics(metrics)) ...[
                const SizedBox(height: 4),
                _TotalPointsChip(
                  points: reportPoints(report!, metrics),
                  color: catColor,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Group progress bar ────────────────────────────────────────────────────────

class _GroupProgressBar extends StatelessWidget {
  final String groupName;
  final int memberCount;
  final double score;

  const _GroupProgressBar({
    required this.groupName,
    required this.memberCount,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final accent = AccentProvider.instance.current;
    final pct = (score * 100).round();
    String milestone;
    String milestoneIcon;
    if (pct >= 90) {
      milestone = s.milestoneExcellent;
      milestoneIcon = '🔥';
    } else if (pct >= 70) {
      milestone = s.milestoneGoodProgress;
      milestoneIcon = '💪';
    } else if (pct >= 50) {
      milestone = s.milestoneHalfWay;
      milestoneIcon = '⚡';
    } else if (pct >= 25) {
      milestone = s.milestoneKeepGoing;
      milestoneIcon = '🌱';
    } else {
      milestone = s.milestoneStart;
      milestoneIcon = '🚀';
    }

    final barColor = pct >= 70
        ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)])
        : pct >= 40
        ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)])
        : LinearGradient(colors: [accent.accentDark, accent.accentLight]);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.accent.withValues(alpha: 0.08),
            accent.gradientMid.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(milestoneIcon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.groupProgress,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '$groupName · $memberCount ${s.memberCount}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: pct >= 70
                      ? const Color(0xFF10B981)
                      : pct >= 40
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: score.clamp(0.0, 1.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 1200),
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: barColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            milestone,
            style: TextStyle(
              color: accent.accentLight,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category chips ─────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final IbadatReport? report;
  final List<GroupMetric> metrics;

  const _CategoryChips({this.report, this.metrics = const []});

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const Text(
        'Нет показателей',
        style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
      );
    }
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: metrics.map((metric) {
        final val = metric.id == null
            ? 0
            : report?.valueForMetric(metric.id!) ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: metric.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            '${metric.icon}$val',
            style: TextStyle(
              color: metric.color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}

bool _hasPointMetrics(Iterable<GroupMetric> metrics) {
  return metrics.any((metric) => maxPointsForMetric(metric) != null);
}

class _TotalPointsChip extends StatelessWidget {
  final double points;
  final Color color;

  const _TotalPointsChip({required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '${formatMetricPoints(points)} балл',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    );
  }
}

// ── Admin report summary row ─────────────────────────────────────────────────

class _AdminReportRow extends StatelessWidget {
  final IbadatReport? report;
  final double score;
  final List<int> trend;
  final List<GroupMetric> metrics;

  const _AdminReportRow({
    required this.report,
    required this.score,
    required this.trend,
    this.metrics = const [],
  });

  @override
  Widget build(BuildContext context) {
    final accent = AccentProvider.instance.current;
    if (report == null) {
      return Center(
        child: Text(
          S.of(context).noReport,
          style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
        ),
      );
    }
    if (metrics.isEmpty) {
      return Center(
        child: Text(
          'Нет показателей',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
        ),
      );
    }
    final totalPoints = reportPoints(report!, metrics);
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...metrics.map((metric) {
                final val = metric.id == null
                    ? 0
                    : report!.valueForMetric(metric.id!);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: metric.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(metric.icon, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '$val',
                        style: TextStyle(
                          color: metric.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            RingIndicator(value: score, size: 52, strokeWidth: 5),
            if (_hasPointMetrics(metrics)) ...[
              const SizedBox(height: 5),
              _TotalPointsChip(points: totalPoints, color: accent.accentLight),
            ],
          ],
        ),
      ],
    );
  }
}
