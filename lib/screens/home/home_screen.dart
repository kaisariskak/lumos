import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../models/ibadat_category.dart';
import '../../models/ibadat_group.dart';
import '../../models/ibadat_profile.dart';
import '../../models/ibadat_report.dart';
import '../../models/ibadat_period.dart';
import '../../repositories/ibadat_group_repository.dart';
import '../../repositories/ibadat_period_repository.dart';
import '../../repositories/ibadat_report_repository.dart';
import '../../utils/week_utils.dart';
import '../../widgets/mini_bar_chart.dart';
import '../../widgets/ring_indicator.dart';
import '../detail/detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final IbadatProfile profile;
  final IbadatGroup group;
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
  void reload() => _loadData();
  late final IbadatGroupRepository _groupRepo;
  late final IbadatReportRepository _reportRepo;

  List<IbadatProfile> _members = [];
  // userId → IbadatReport for current viewed month
  Map<String, IbadatReport> _monthlyReports = {};
  // month → userId → IbadatReport, for last 4 months/periods trend chart
  Map<int, Map<String, IbadatReport>> _trendReports = {};

  bool _isLoading = true;

  // Month mode (super-admin)
  late int _viewMonth;
  late int _viewYear;

  // Period mode (regular admin/user)
  late final IbadatPeriodRepository _periodRepo;
  List<IbadatPeriod> _periods = [];
  int _periodIdx = 0;
  bool _isPeriodMode = false;

  bool get _isSuperAdmin => widget.profile.isSuperAdmin;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = now.month;
    _viewYear = now.year;
    final client = Supabase.instance.client;
    _groupRepo = IbadatGroupRepository(client);
    _reportRepo = IbadatReportRepository(client);
    _periodRepo = IbadatPeriodRepository(client);
    _loadData();
  }

  /// Returns the last 4 months as (month, year) pairs, oldest first
  static List<(int, int)> _lastFourMonths(int month, int year) {
    return List.generate(4, (i) {
      int m = month - (3 - i);
      int y = year;
      while (m < 1) { m += 12; y--; }
      return (m, y);
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final members = await _groupRepo.getGroupMembers(widget.group.id);

      // Load periods for non-super-admin
      List<IbadatPeriod> periods = [];
      if (!_isSuperAdmin) {
        final loaded = await _periodRepo.getPeriodsForGroup(widget.group.id);
        periods = loaded.reversed.toList(); // oldest first
      }
      final isPeriodMode = periods.isNotEmpty;

      // Determine which month to load
      int viewMonth = _viewMonth;
      int viewYear = _viewYear;
      if (isPeriodMode) {
        final idx = _periodIdx.clamp(0, periods.length - 1);
        viewMonth = periods[idx].startDate.month;
        viewYear = periods[idx].startDate.year;
      }

      // Load reports for the current view month
      final Map<String, IbadatReport> current = {};
      if (widget.profile.isAdmin) {
        final reports = await _reportRepo.getGroupReports(
          groupId: widget.group.id, month: viewMonth, year: viewYear,
        );
        for (final r in reports) { current[r.userId] = r; }
      } else {
        final r = await _reportRepo.getReport(
          userId: widget.profile.id, groupId: widget.group.id,
          month: viewMonth, year: viewYear,
        );
        if (r != null) current[r.userId] = r;
      }

      // Load trend data (last 4 periods or last 4 months)
      final Map<int, Map<String, IbadatReport>> trend = {};
      final trendMonths = isPeriodMode
          ? periods.take(4).map((p) => (p.startDate.month, p.startDate.year)).toList()
          : _lastFourMonths(viewMonth, viewYear);

      for (final (m, y) in trendMonths) {
        if (widget.profile.isAdmin) {
          final reports = await _reportRepo.getGroupReports(
            groupId: widget.group.id, month: m, year: y,
          );
          trend[m] = {for (final r in reports) r.userId: r};
        } else {
          final r = await _reportRepo.getReport(
            userId: widget.profile.id, groupId: widget.group.id, month: m, year: y,
          );
          trend[m] = r != null ? {r.userId: r} : {};
        }
      }

      if (mounted) {
        setState(() {
          _members = members;
          _periods = periods;
          _isPeriodMode = isPeriodMode;
          _viewMonth = viewMonth;
          _viewYear = viewYear;
          _monthlyReports = current;
          _trendReports = trend;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IbadatReport? _getReport(String userId) => _monthlyReports[userId];

  double _calcScore(String userId) {
    final report = _getReport(userId);
    if (report == null) return 0;
    return _scoreFromReport(report);
  }

  double _scoreFromReport(IbadatReport report) {
    double sum = 0;
    for (final cat in IbadatCategory.all) {
      sum += (report.getValue(cat.key) / cat.monthMax).clamp(0.0, 1.0);
    }
    return sum / IbadatCategory.all.length;
  }

  List<int> _trendValues(String userId) {
    final months = _lastFourMonths(_viewMonth, _viewYear);
    return months.map((pair) {
      final r = _trendReports[pair.$1]?[userId];
      return r?.quranPages ?? 0;
    }).toList();
  }

  void _prevMonth() {
    setState(() {
      _viewMonth--;
      if (_viewMonth < 1) { _viewMonth = 12; _viewYear--; }
    });
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_viewYear > now.year || (_viewYear == now.year && _viewMonth >= now.month)) return;
    setState(() {
      _viewMonth++;
      if (_viewMonth > 12) { _viewMonth = 1; _viewYear++; }
    });
    _loadData();
  }

  List<IbadatProfile> get _sorted {
    final list = List<IbadatProfile>.from(_members);
    list.sort((a, b) => _calcScore(b.id).compareTo(_calcScore(a.id)));
    // Non-admin users only see themselves
    if (!widget.profile.isAdmin) {
      return list.where((m) => m.id == widget.profile.id).toList();
    }
    return list;
  }

  double _groupScore() {
    if (_members.isEmpty) return 0;
    return _members.fold(0.0, (s, m) => s + _calcScore(m.id)) / _members.length;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF6366F1),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.greeting,
                                style: const TextStyle(
                                    color: Color(0xFF64748B), fontSize: 13)),
                            Text(
                              '${widget.profile.displayName.split(' ').first} 👋',
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
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              widget.profile.displayName[0].toUpperCase(),
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
                  ),
                  const SizedBox(height: 4),
                  Text(widget.profile.email,
                      style: const TextStyle(
                          color: Color(0xFF475569), fontSize: 12)),
                  const SizedBox(height: 16),

                  // Group progress bar
                  _GroupProgressBar(
                    groupName: widget.group.name,
                    memberCount: _members.length,
                    score: _groupScore(),
                  ),

                  // Group badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Text('👥',
                                style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              widget.group.name,
                              style: const TextStyle(
                                color: Color(0xFFA5B4FC),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.onSwitchGroup,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.switchGroupShort,
                            style: const TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Navigator: periods for regular admin/user, months for super-admin
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                    ),
                    child: _isPeriodMode
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: _periodIdx > 0
                                    ? () { setState(() => _periodIdx--); _loadData(); }
                                    : null,
                                icon: Icon(Icons.chevron_left,
                                    color: _periodIdx > 0
                                        ? const Color(0xFFA5B4FC)
                                        : const Color(0xFF334155)),
                              ),
                              Column(
                                children: [
                                  Text(
                                    _periods[_periodIdx].dateRangeLabelLocalized(s.languageCode),
                                    style: const TextStyle(
                                        color: Color(0xFFE2E8F0),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14),
                                  ),
                                  Text(
                                    _periods[_periodIdx].label,
                                    style: const TextStyle(
                                        color: Color(0xFF64748B), fontSize: 11),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: _periodIdx < _periods.length - 1
                                    ? () { setState(() => _periodIdx++); _loadData(); }
                                    : null,
                                icon: Icon(Icons.chevron_right,
                                    color: _periodIdx < _periods.length - 1
                                        ? const Color(0xFFA5B4FC)
                                        : const Color(0xFF334155)),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: _prevMonth,
                                icon: const Icon(Icons.chevron_left,
                                    color: Color(0xFFA5B4FC)),
                              ),
                              Text(
                                WeekUtils.monthLabel(_viewMonth, _viewYear),
                                style: const TextStyle(
                                    color: Color(0xFFE2E8F0),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                              IconButton(
                                onPressed: () {
                                  final now = DateTime.now();
                                  if (_viewYear < now.year ||
                                      (_viewYear == now.year &&
                                          _viewMonth < now.month)) {
                                    _nextMonth();
                                  }
                                },
                                icon: Icon(Icons.chevron_right,
                                    color: (_viewYear < DateTime.now().year ||
                                            (_viewYear == DateTime.now().year &&
                                                _viewMonth < DateTime.now().month))
                                        ? const Color(0xFFA5B4FC)
                                        : const Color(0xFF334155)),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Ranking list
                  if (_members.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            const Text('😭', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              s.noMembers,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._sorted.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final member = entry.value;
                      final score = _calcScore(member.id);
                      final trend = _trendValues(member.id);
                      final isMe = member.id == widget.profile.id;
                      final medal = idx == 0
                          ? '🥇'
                          : idx == 1
                              ? '🥈'
                              : idx == 2
                                  ? '🥉'
                                  : null;
                      final catColor = IbadatCategory
                          .all[idx % IbadatCategory.all.length].color;

                      final canViewDetail =
                          widget.profile.isAdmin || member.id == widget.profile.id;
                      return GestureDetector(
                        onTap: canViewDetail
                            ? () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => DetailScreen(
                                    profile: member,
                                    report: _getReport(member.id),
                                    weekLabel: WeekUtils.monthLabel(_viewMonth, _viewYear),
                                    isWeekMode: false,
                                    monthReports: _trendReports.values
                                        .map((m) => m[member.id])
                                        .whereType<IbadatReport>()
                                        .toList(),
                                  ),
                                ));
                              }
                            : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: idx == 0
                                ? LinearGradient(
                                    colors: [
                                      const Color(0xFFFBBF24).withValues(alpha: 0.08),
                                      const Color(0xFFF59E0B).withValues(alpha: 0.04),
                                    ],
                                  )
                                : null,
                            color: idx == 0
                                ? null
                                : Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isMe
                                  ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                                  : idx == 0
                                      ? const Color(0xFFFBBF24).withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Rank
                              SizedBox(
                                width: 28,
                                child: medal != null
                                    ? Text(medal,
                                        style: const TextStyle(fontSize: 18))
                                    : Text(
                                        '${idx + 1}',
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
                                        member.displayName[0].toUpperCase(),
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
                                              horizontal: 3, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text('👑',
                                              style: TextStyle(fontSize: 8)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Name + categories
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          member.displayName.split(' ').first,
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
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF6366F1)
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              s.youLabel,
                                              style: const TextStyle(
                                                color: Color(0xFFA5B4FC),
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    _CategoryChips(
                                      report: _getReport(member.id),
                                    ),
                                  ],
                                ),
                              ),

                              // Ring + trend
                              Column(
                                children: [
                                  RingIndicator(value: score, size: 46),
                                  const SizedBox(height: 3),
                                  MiniBarChart(
                                    values: trend,
                                    color: const Color(0xFF6366F1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

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
        ? const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF34D399)])
        : pct >= 40
            ? const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)])
            : const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF818CF8)]);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withValues(alpha: 0.08),
            const Color(0xFF8B5CF6).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15)),
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
                          color: Color(0xFF94A3B8), fontSize: 11),
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
            style: const TextStyle(
              color: Color(0xFFA5B4FC),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final IbadatReport? report;

  const _CategoryChips({this.report});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: IbadatCategory.all.map((cat) {
        final val = report?.getValue(cat.key) ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: cat.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            '${cat.icon}$val',
            style: TextStyle(
              color: cat.color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}

