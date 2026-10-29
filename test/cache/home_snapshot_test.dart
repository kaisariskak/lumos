import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/cache/home_snapshot.dart';
import 'package:reportdeepen/models/group_metric.dart';
import 'package:reportdeepen/models/ibadat_group.dart';
import 'package:reportdeepen/models/ibadat_period.dart';
import 'package:reportdeepen/models/ibadat_profile.dart';
import 'package:reportdeepen/models/ibadat_report.dart';

IbadatProfile _profile(String id) => IbadatProfile(
      id: id,
      nickname: 'n-$id',
      role: 'user',
      currentGroupId: 'g1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );

IbadatPeriod _period(String id, int day) => IbadatPeriod(
      id: id,
      groupId: 'g1',
      label: 'L$id',
      startDate: DateTime(2026, 9, day),
      endDate: DateTime(2026, 9, day + 6),
      createdBy: 'a1',
      createdAt: DateTime.utc(2026, 9, 1),
    );

IbadatReport _report(String id, String userId) => IbadatReport(
      id: id,
      userId: userId,
      groupId: 'g1',
      periodId: 'p2',
      month: 9,
      year: 2026,
      metricValues: {'m1': 5},
    );

HomeSectionSnapshot _section({IbadatGroup? group}) => HomeSectionSnapshot(
      group: group,
      members: [_profile('u1'), _profile('u2')],
      metrics: [GroupMetric.test(id: 'm1', groupId: 'g1')],
      periods: [_period('p1', 1), _period('p2', 8)],
      periodIdx: 1,
      monthlyReports: {'u1': _report('r1', 'u1')},
      trendReports: {
        9: {'u1': _report('r1', 'u1')},
        8: {},
      },
    );

/// Simulates writing to and reading from the JSON cache.
Object? _roundTrip(Object? json) => jsonDecode(jsonEncode(json));

void _expectSectionEqual(HomeSectionSnapshot a, HomeSectionSnapshot b) {
  expect(a.group?.id, b.group?.id);
  expect(a.members.map((m) => m.id), b.members.map((m) => m.id));
  expect(a.metrics.map((m) => m.id), b.metrics.map((m) => m.id));
  expect(a.periods.map((p) => p.id), b.periods.map((p) => p.id));
  expect(a.periodIdx, b.periodIdx);
  expect(a.monthlyReports.keys, b.monthlyReports.keys);
  expect(a.monthlyReports['u1']!.metricValues, b.monthlyReports['u1']!.metricValues);
  expect(a.trendReports.keys.toSet(), b.trendReports.keys.toSet());
  expect(a.trendReports[9]!['u1']!.id, b.trendReports[9]!['u1']!.id);
  expect(a.trendReports[8], isEmpty);
}

void main() {
  test('user snapshot round-trips through JSON', () {
    final original = HomeUserSnapshot(
      groupId: 'g1',
      viewMonth: 9,
      viewYear: 2026,
      data: _section(),
    );

    final copy = HomeUserSnapshot.tryFromJson(_roundTrip(original.toJson()));

    expect(copy, isNotNull);
    expect(copy!.groupId, 'g1');
    expect(copy.viewMonth, 9);
    expect(copy.viewYear, 2026);
    _expectSectionEqual(copy.data, original.data);
  });

  test('admin snapshot round-trips through JSON', () {
    final group = IbadatGroup(
      id: 'g1',
      name: 'TESLA',
      code: 'C',
      adminId: 'a1',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final original = HomeAdminSnapshot(
      sections: [_section(group: group)],
      personalMetrics: [GroupMetric.test(id: 'pm1', adminId: 'a1')],
      personalPeriods: [_period('pp1', 1)],
      personalPeriodIdx: 0,
      personalReport: _report('pr1', 'a1'),
    );

    final copy = HomeAdminSnapshot.tryFromJson(_roundTrip(original.toJson()));

    expect(copy, isNotNull);
    expect(copy!.sections, hasLength(1));
    _expectSectionEqual(copy.sections.single, original.sections.single);
    expect(copy.personalMetrics.single.id, 'pm1');
    expect(copy.personalPeriods.single.id, 'pp1');
    expect(copy.personalPeriodIdx, 0);
    expect(copy.personalReport!.id, 'pr1');
  });

  test('wrong kind or garbage returns null', () {
    final user = HomeUserSnapshot(
      groupId: 'g1',
      viewMonth: 9,
      viewYear: 2026,
      data: _section(),
    );

    expect(HomeAdminSnapshot.tryFromJson(_roundTrip(user.toJson())), isNull);
    expect(HomeUserSnapshot.tryFromJson({'kind': 'user'}), isNull);
    expect(HomeUserSnapshot.tryFromJson('nope'), isNull);
    expect(HomeUserSnapshot.tryFromJson(null), isNull);
  });
}
