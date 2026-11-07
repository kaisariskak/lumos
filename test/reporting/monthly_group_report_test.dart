import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/models/group_metric.dart';
import 'package:reportdeepen/models/ibadat_group.dart';
import 'package:reportdeepen/models/ibadat_period.dart';
import 'package:reportdeepen/models/ibadat_profile.dart';
import 'package:reportdeepen/models/ibadat_report.dart';
import 'package:reportdeepen/reporting/monthly_group_report.dart';

final _group = IbadatGroup(
  id: 'group-1',
  name: 'Group',
  code: 'CODE',
  adminId: 'admin',
  createdAt: DateTime(2026),
);

IbadatProfile _member(String id) => IbadatProfile(
  id: id,
  nickname: id,
  role: 'user',
  currentGroupId: 'group-1',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

IbadatPeriod _period(String id, DateTime start, DateTime end) => IbadatPeriod(
  id: id,
  groupId: 'group-1',
  label: id,
  startDate: start,
  endDate: end,
  createdBy: 'admin',
  createdAt: DateTime(2026),
);

IbadatReport _report(
  String userId,
  String? periodId,
  Map<String, int> values, {
  int month = 10,
  DateTime? updatedAt,
}) => IbadatReport(
  id: '$userId-$periodId-${updatedAt?.millisecondsSinceEpoch}',
  userId: userId,
  groupId: 'group-1',
  periodId: periodId,
  month: month,
  year: 2026,
  metricValues: values,
  updatedAt: updatedAt,
);

void main() {
  final metrics = [GroupMetric.test(id: 'quran', maxValue: 20)];

  test('sums all periods that start in the month', () {
    final result = buildMonthlyGroupReport(
      group: _group,
      month: 10,
      year: 2026,
      members: [_member('a')],
      metrics: metrics,
      periods: [
        _period('p1', DateTime(2026, 10, 1), DateTime(2026, 10, 7)),
        _period('p2', DateTime(2026, 10, 8), DateTime(2026, 10, 14)),
      ],
      reports: [
        _report('a', 'p1', {'quran': 5}),
        _report('a', 'p2', {'quran': 7}),
      ],
    );

    expect(result.members.single.valueFor('quran'), 12);
    expect(result.members.single.reportsCount, 2);
    expect(result.groupTotalFor('quran'), 12);
  });

  test('attributes a period crossing months to its start month only', () {
    final periods = [
      _period('oct', DateTime(2026, 10, 28), DateTime(2026, 11, 3)),
      _period('nov', DateTime(2026, 11, 4), DateTime(2026, 11, 10)),
    ];
    final reports = [
      _report('a', 'oct', {'quran': 4}),
      _report('a', 'nov', {'quran': 6}, month: 11),
    ];

    final october = buildMonthlyGroupReport(
      group: _group,
      month: 10,
      year: 2026,
      members: [_member('a')],
      metrics: metrics,
      periods: periods,
      reports: reports,
    );
    final november = buildMonthlyGroupReport(
      group: _group,
      month: 11,
      year: 2026,
      members: [_member('a')],
      metrics: metrics,
      periods: periods,
      reports: reports,
    );

    expect(october.members.single.valueFor('quran'), 4);
    expect(november.members.single.valueFor('quran'), 6);
  });

  test('keeps only the latest duplicate report for a period', () {
    final result = buildMonthlyGroupReport(
      group: _group,
      month: 10,
      year: 2026,
      members: [_member('a')],
      metrics: metrics,
      periods: [_period('p1', DateTime(2026, 10, 1), DateTime(2026, 10, 7))],
      reports: [
        _report('a', 'p1', {'quran': 3}, updatedAt: DateTime(2026, 10, 2)),
        _report('a', 'p1', {'quran': 9}, updatedAt: DateTime(2026, 10, 5)),
      ],
    );

    expect(result.members.single.valueFor('quran'), 9);
    expect(result.members.single.reportsCount, 1);
  });

  test('uses monthly reports when the group has no periods', () {
    final result = buildMonthlyGroupReport(
      group: _group,
      month: 10,
      year: 2026,
      members: [_member('a')],
      metrics: metrics,
      periods: const [],
      reports: [
        _report('a', null, {'quran': 8}),
        _report('a', null, {'quran': 99}, month: 9),
      ],
    );

    expect(result.members.single.valueFor('quran'), 8);
  });

  test('lists members without reports with zero values', () {
    final result = buildMonthlyGroupReport(
      group: _group,
      month: 10,
      year: 2026,
      members: [_member('a'), _member('b')],
      metrics: metrics,
      periods: [_period('p1', DateTime(2026, 10, 1), DateTime(2026, 10, 7))],
      reports: [_report('a', 'p1', {'quran': 5})],
    );

    final b = result.members.firstWhere((m) => m.member.id == 'b');
    expect(b.valueFor('quran'), 0);
    expect(b.reportsCount, 0);
    expect(result.submittedCount, 1);
    expect(result.hasData, isTrue);
  });

  test('reports no data when nobody submitted in the month', () {
    final result = buildMonthlyGroupReport(
      group: _group,
      month: 12,
      year: 2026,
      members: [_member('a')],
      metrics: metrics,
      periods: [_period('p1', DateTime(2026, 10, 1), DateTime(2026, 10, 7))],
      reports: [_report('a', 'p1', {'quran': 5})],
    );

    expect(result.hasData, isFalse);
  });

  test('sums all metrics per member and computes shares of the group', () {
    final result = buildMonthlyGroupReport(
      group: _group,
      month: 10,
      year: 2026,
      members: [_member('a'), _member('b'), _member('c')],
      metrics: [
        GroupMetric.test(id: 'quran', orderIndex: 0),
        GroupMetric.test(id: 'zikr', orderIndex: 1),
      ],
      periods: [_period('p1', DateTime(2026, 10, 1), DateTime(2026, 10, 7))],
      reports: [
        _report('a', 'p1', {'quran': 10, 'zikr': 20}),
        _report('b', 'p1', {'quran': 5, 'zikr': 5}),
      ],
    );

    expect(result.members.map((m) => m.member.id), ['a', 'b', 'c']);
    expect(result.members[0].total, 30);
    expect(result.members[1].total, 10);
    expect(result.groupTotal, 40);
    expect(result.shareOf(result.members[0]), 0.75);
    expect(result.shareOf(result.members[2]), 0);
  });

  test('monthly goal is the period goal times periods in the month', () {
    final kk = GroupMetric.test(id: 'kk', maxValue: 10);
    final result = buildMonthlyGroupReport(
      group: _group,
      month: 10,
      year: 2026,
      members: [_member('a'), _member('b')],
      metrics: [kk],
      periods: [
        for (var w = 0; w < 4; w++)
          _period(
            'w$w',
            DateTime(2026, 10, 1 + w * 7),
            DateTime(2026, 10, 7 + w * 7),
          ),
      ],
      reports: [
        _report('a', 'w0', {'kk': 8}),
        _report('a', 'w1', {'kk': 10}),
        _report('a', 'w2', {'kk': 7}),
        _report('a', 'w3', {'kk': 5}),
      ],
    );

    expect(result.periodCount, 4);
    expect(result.monthlyGoalFor(kk), 40);
    expect(result.members.first.valueFor('kk'), 30);
    expect(completionRatio(30, result.monthlyGoalFor(kk)), 0.75);
    expect(result.groupGoalFor(kk), 80);
  });

  test('a group without periods uses the goal once per month', () {
    final kk = GroupMetric.test(id: 'kk', maxValue: 10);
    final result = buildMonthlyGroupReport(
      group: _group,
      month: 10,
      year: 2026,
      members: [_member('a')],
      metrics: [kk],
      periods: const [],
      reports: [_report('a', null, {'kk': 12})],
    );

    expect(result.monthlyGoalFor(kk), 10);
    expect(completionRatio(12, 10), 1.2);
    expect(completionRatio(5, 0), isNull);
  });

  test('ignores values of metrics no longer in the group', () {
    final result = buildMonthlyGroupReport(
      group: _group,
      month: 10,
      year: 2026,
      members: [_member('a')],
      metrics: metrics,
      periods: [_period('p1', DateTime(2026, 10, 1), DateTime(2026, 10, 7))],
      reports: [
        _report('a', 'p1', {'quran': 5, 'deleted': 100}),
      ],
    );

    expect(result.members.single.values.keys, ['quran']);
  });
}
