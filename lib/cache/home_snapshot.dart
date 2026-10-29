import '../models/group_metric.dart';
import '../models/ibadat_group.dart';
import '../models/ibadat_period.dart';
import '../models/ibadat_profile.dart';
import '../models/ibadat_report.dart';

/// Cache name used with [StartupCache] for the home screen snapshot.
const homeSnapshotCacheName = 'home';

/// What the home screen showed for one group: members, metrics, periods
/// (oldest first), the selected period and its reports, and the trend.
class HomeSectionSnapshot {
  final IbadatGroup? group;
  final List<IbadatProfile> members;
  final List<GroupMetric> metrics;
  final List<IbadatPeriod> periods;
  final int periodIdx;
  final Map<String, IbadatReport> monthlyReports;
  final Map<int, Map<String, IbadatReport>> trendReports;

  const HomeSectionSnapshot({
    this.group,
    required this.members,
    required this.metrics,
    required this.periods,
    required this.periodIdx,
    required this.monthlyReports,
    required this.trendReports,
  });

  Map<String, dynamic> toJson() => {
        'group': group?.toCacheJson(),
        'members': [for (final m in members) m.toCacheJson()],
        'metrics': [for (final m in metrics) m.toCacheJson()],
        'periods': [for (final p in periods) p.toCacheJson()],
        'period_idx': periodIdx,
        'monthly_reports': [for (final r in monthlyReports.values) r.toCacheJson()],
        'trend_reports': {
          for (final entry in trendReports.entries)
            '${entry.key}': [for (final r in entry.value.values) r.toCacheJson()],
        },
      };

  factory HomeSectionSnapshot.fromJson(Map<String, dynamic> json) {
    final groupJson = json['group'];
    final trendJson = _map(json['trend_reports']);
    return HomeSectionSnapshot(
      group: groupJson == null ? null : IbadatGroup.fromJson(_map(groupJson)),
      members: _list(json['members']).map(IbadatProfile.fromJson).toList(),
      metrics: _list(json['metrics']).map(GroupMetric.fromJson).toList(),
      periods: _list(json['periods']).map(IbadatPeriod.fromJson).toList(),
      periodIdx: json['period_idx'] as int,
      monthlyReports: _reportsByUser(json['monthly_reports']),
      trendReports: {
        for (final entry in trendJson.entries)
          int.parse(entry.key): _reportsByUser(entry.value),
      },
    );
  }
}

/// Home screen snapshot for a regular member of one group.
class HomeUserSnapshot {
  final String groupId;
  final int viewMonth;
  final int viewYear;
  final HomeSectionSnapshot data;

  const HomeUserSnapshot({
    required this.groupId,
    required this.viewMonth,
    required this.viewYear,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'kind': 'user',
        'group_id': groupId,
        'view_month': viewMonth,
        'view_year': viewYear,
        'data': data.toJson(),
      };

  static HomeUserSnapshot? tryFromJson(Object? json) {
    try {
      final map = _map(json);
      if (map['kind'] != 'user') return null;
      return HomeUserSnapshot(
        groupId: map['group_id'] as String,
        viewMonth: map['view_month'] as int,
        viewYear: map['view_year'] as int,
        data: HomeSectionSnapshot.fromJson(_map(map['data'])),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Home screen snapshot for a group admin: all owned groups plus the admin's
/// personal report card.
class HomeAdminSnapshot {
  final List<HomeSectionSnapshot> sections;
  final List<GroupMetric> personalMetrics;
  final List<IbadatPeriod> personalPeriods;
  final int personalPeriodIdx;
  final IbadatReport? personalReport;

  const HomeAdminSnapshot({
    required this.sections,
    required this.personalMetrics,
    required this.personalPeriods,
    required this.personalPeriodIdx,
    required this.personalReport,
  });

  Map<String, dynamic> toJson() => {
        'kind': 'admin',
        'sections': [for (final s in sections) s.toJson()],
        'personal_metrics': [for (final m in personalMetrics) m.toCacheJson()],
        'personal_periods': [for (final p in personalPeriods) p.toCacheJson()],
        'personal_period_idx': personalPeriodIdx,
        'personal_report': personalReport?.toCacheJson(),
      };

  static HomeAdminSnapshot? tryFromJson(Object? json) {
    try {
      final map = _map(json);
      if (map['kind'] != 'admin') return null;
      final reportJson = map['personal_report'];
      return HomeAdminSnapshot(
        sections: _list(map['sections']).map(HomeSectionSnapshot.fromJson).toList(),
        personalMetrics:
            _list(map['personal_metrics']).map(GroupMetric.fromJson).toList(),
        personalPeriods:
            _list(map['personal_periods']).map(IbadatPeriod.fromJson).toList(),
        personalPeriodIdx: map['personal_period_idx'] as int,
        personalReport:
            reportJson == null ? null : IbadatReport.fromJson(_map(reportJson)),
      );
    } catch (_) {
      return null;
    }
  }
}

Map<String, dynamic> _map(Object? value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _list(Object? value) =>
    [for (final item in value as List) _map(item)];

Map<String, IbadatReport> _reportsByUser(Object? value) {
  final reports = _list(value).map(IbadatReport.fromJson);
  return {for (final r in reports) r.userId: r};
}
