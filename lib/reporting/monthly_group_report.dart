import '../models/group_metric.dart';
import '../models/ibadat_group.dart';
import '../models/ibadat_period.dart';
import '../models/ibadat_profile.dart';
import '../models/ibadat_report.dart';
import 'report_progress.dart';

/// One member's totals for a month.
class MemberMonthlyTotals {
  final IbadatProfile member;

  /// Metric id → summed value over all of the month's reports.
  final Map<String, int> values;

  /// How many reports (periods) the member submitted in the month.
  final int reportsCount;

  /// Summed points, or null when no metric has a points rule.
  final double? points;

  const MemberMonthlyTotals({
    required this.member,
    required this.values,
    required this.reportsCount,
    required this.points,
  });

  int valueFor(String metricId) => values[metricId] ?? 0;

  /// All of the member's metric values added up, regardless of unit.
  int get total => values.values.fold(0, (sum, v) => sum + v);
}

/// A group's metrics aggregated for one calendar month.
class MonthlyGroupReport {
  final IbadatGroup group;
  final int month;
  final int year;
  final List<GroupMetric> metrics;

  /// The group's periods attributed to the month (empty in month mode).
  final List<IbadatPeriod> periods;
  final List<MemberMonthlyTotals> members;

  const MonthlyGroupReport({
    required this.group,
    required this.month,
    required this.year,
    required this.metrics,
    required this.periods,
    required this.members,
  });

  bool get hasPoints => metrics.any((m) => maxPointsForMetric(m) != null);

  bool get hasData => members.any((m) => m.reportsCount > 0);

  int get submittedCount => members.where((m) => m.reportsCount > 0).length;

  int groupTotalFor(String metricId) =>
      members.fold(0, (sum, m) => sum + m.valueFor(metricId));

  double get groupPoints =>
      members.fold(0.0, (sum, m) => sum + (m.points ?? 0));

  int get groupTotal => members.fold(0, (sum, m) => sum + m.total);

  /// Number of reporting periods in the month; a group without periods
  /// reports once a month, so its per-period goal is already monthly.
  int get periodCount => periods.isEmpty ? 1 : periods.length;

  /// One member's goal for [metric] over the month: the per-period goal
  /// multiplied by the number of periods in the month.
  int monthlyGoalFor(GroupMetric metric) => metric.maxValue * periodCount;

  /// Sum of the member's monthly goals over all metrics.
  int get memberGoalTotal =>
      metrics.fold(0, (sum, m) => sum + monthlyGoalFor(m));

  /// The group's monthly goal for [metric]: every member's goal together.
  int groupGoalFor(GroupMetric metric) =>
      monthlyGoalFor(metric) * members.length;

  int get groupGoalTotal => memberGoalTotal * members.length;

  /// The member's share of the group total, from 0 to 1.
  double shareOf(MemberMonthlyTotals member) =>
      groupTotal == 0 ? 0 : member.total / groupTotal;
}

/// Aggregates [reports] of [group] into totals for [month]/[year].
///
/// Mirrors the home screen: a group that has periods counts only reports of
/// its periods, and each period belongs wholly to the month of its start date
/// (the month the app stores on the report), so a period crossing a month
/// boundary is never counted twice. A group without periods counts its
/// monthly reports. Duplicate reports of one member for the same period are
/// collapsed to the most recently updated one.
MonthlyGroupReport buildMonthlyGroupReport({
  required IbadatGroup group,
  required int month,
  required int year,
  required List<IbadatProfile> members,
  required List<GroupMetric> metrics,
  required List<IbadatPeriod> periods,
  required List<IbadatReport> reports,
}) {
  final groupMetrics = metrics.where((m) => m.id != null).toList()
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  final metricIds = {for (final m in groupMetrics) m.id!};

  final groupPeriods = periods.where((p) => !p.isPersonal).toList();
  final isPeriodMode = groupPeriods.isNotEmpty;
  final monthPeriods = groupPeriods
      .where((p) => p.startDate.year == year && p.startDate.month == month)
      .toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  final monthPeriodIds = {for (final p in monthPeriods) p.id};

  bool belongsToMonth(IbadatReport r) {
    if (r.groupId != group.id) return false;
    if (isPeriodMode) return monthPeriodIds.contains(r.periodId);
    return r.periodId == null && r.month == month && r.year == year;
  }

  final latestByKey = <String, IbadatReport>{};
  for (final report in reports.where(belongsToMonth)) {
    final key = '${report.userId}|${report.periodId ?? ''}';
    final existing = latestByKey[key];
    if (existing == null || _isNewer(report, existing)) {
      latestByKey[key] = report;
    }
  }

  final reportsByUser = <String, List<IbadatReport>>{};
  for (final report in latestByKey.values) {
    reportsByUser.putIfAbsent(report.userId, () => []).add(report);
  }

  final hasPoints = groupMetrics.any((m) => maxPointsForMetric(m) != null);
  final seenMembers = <String>{};
  final totals = <MemberMonthlyTotals>[];
  for (final member in members) {
    if (!seenMembers.add(member.id)) continue;
    final userReports = reportsByUser[member.id] ?? const <IbadatReport>[];
    final values = <String, int>{};
    for (final report in userReports) {
      report.metricValues.forEach((metricId, value) {
        if (metricIds.contains(metricId)) {
          values[metricId] = (values[metricId] ?? 0) + value;
        }
      });
    }
    double? points;
    if (hasPoints) {
      points = groupMetrics.fold<double>(
        0,
        (sum, m) => sum + (pointsForMetricValue(values[m.id] ?? 0, m) ?? 0),
      );
    }
    totals.add(
      MemberMonthlyTotals(
        member: member,
        values: values,
        reportsCount: userReports.length,
        points: points,
      ),
    );
  }

  // Every member has the same goals, so ordering by total also orders by
  // completion of the overall monthly goal.
  totals.sort((a, b) {
    final byTotal = b.total.compareTo(a.total);
    if (byTotal != 0) return byTotal;
    return a.member.nickname.toLowerCase().compareTo(
          b.member.nickname.toLowerCase(),
        );
  });

  return MonthlyGroupReport(
    group: group,
    month: month,
    year: year,
    metrics: groupMetrics,
    periods: monthPeriods,
    members: totals,
  );
}

/// Completion ratio of [actual] against [goal] (1.0 = 100%); may exceed 1.
/// Null when there is no goal to measure against.
double? completionRatio(int actual, int goal) =>
    goal <= 0 ? null : actual / goal;

bool _isNewer(IbadatReport a, IbadatReport b) {
  final aTime = a.updatedAt ?? a.submittedAt;
  final bTime = b.updatedAt ?? b.submittedAt;
  if (aTime == null) return false;
  if (bTime == null) return true;
  return aTime.isAfter(bTime);
}
