import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/models/group_metric.dart';
import 'package:reportdeepen/models/ibadat_group.dart';
import 'package:reportdeepen/models/ibadat_period.dart';
import 'package:reportdeepen/models/ibadat_profile.dart';
import 'package:reportdeepen/models/ibadat_report.dart';

void main() {
  test('IbadatProfile round-trips through toCacheJson', () {
    final original = IbadatProfile.fromJson({
      'id': 'u1',
      'nickname': 'vitamin',
      'role': 'user',
      'current_group_id': 'g1',
      'super_admin_id': 'sa1',
      'created_by_admin_id': 'a1',
      'created_at': '2026-01-02T03:04:05.123+00:00',
      'updated_at': '2026-02-03T04:05:06+00:00',
    });

    final copy = IbadatProfile.fromJson(original.toCacheJson());

    expect(copy.id, original.id);
    expect(copy.nickname, original.nickname);
    expect(copy.role, original.role);
    expect(copy.currentGroupId, original.currentGroupId);
    expect(copy.superAdminId, original.superAdminId);
    expect(copy.createdByAdminId, original.createdByAdminId);
    expect(copy.createdAt, original.createdAt);
    expect(copy.updatedAt, original.updatedAt);
  });

  test('IbadatGroup round-trips through toCacheJson', () {
    final original = IbadatGroup.fromJson({
      'id': 'g1',
      'name': 'TESLA',
      'code': 'ABC',
      'admin_id': 'a1',
      'financier_id': 'f1',
      'created_at': '2026-01-02T03:04:05+00:00',
    });

    final copy = IbadatGroup.fromJson(original.toCacheJson());

    expect(copy.id, original.id);
    expect(copy.name, original.name);
    expect(copy.code, original.code);
    expect(copy.adminId, original.adminId);
    expect(copy.financierId, original.financierId);
    expect(copy.createdAt, original.createdAt);
  });

  test('GroupMetric round-trips through toCacheJson', () {
    final original = GroupMetric.fromJson({
      'id': 'm1',
      'group_id': 'g1',
      'admin_id': null,
      'name_ru': 'Коран',
      'name_kk': 'Құран',
      'icon': '📖',
      'color_value': -7617718,
      'unit': 'pages',
      'max_value': 10,
      'points_per_unit': 5,
      'points_value': 1,
      'order_index': 2,
      'created_at': '2026-01-02T03:04:05+00:00',
    });

    final copy = GroupMetric.fromJson(original.toCacheJson());

    expect(copy.id, original.id);
    expect(copy.groupId, original.groupId);
    expect(copy.adminId, original.adminId);
    expect(copy.nameRu, original.nameRu);
    expect(copy.nameKk, original.nameKk);
    expect(copy.icon, original.icon);
    expect(copy.colorValue, original.colorValue);
    expect(copy.unit, original.unit);
    expect(copy.maxValue, original.maxValue);
    expect(copy.pointsPerUnit, original.pointsPerUnit);
    expect(copy.pointsValue, original.pointsValue);
    expect(copy.orderIndex, original.orderIndex);
    expect(copy.createdAt, original.createdAt);
  });

  test('IbadatPeriod round-trips through toCacheJson', () {
    final original = IbadatPeriod.fromJson({
      'id': 'p1',
      'group_id': 'g1',
      'label': 'Неделя 1',
      'start_date': '2026-09-28',
      'end_date': '2026-10-04',
      'created_by': 'a1',
      'created_at': '2026-09-27T10:00:00+00:00',
      'is_personal': false,
    });

    final copy = IbadatPeriod.fromJson(original.toCacheJson());

    expect(copy.id, original.id);
    expect(copy.groupId, original.groupId);
    expect(copy.label, original.label);
    expect(copy.startDate, original.startDate);
    expect(copy.endDate, original.endDate);
    expect(copy.createdBy, original.createdBy);
    expect(copy.createdAt, original.createdAt);
    expect(copy.isPersonal, original.isPersonal);
  });

  test('IbadatReport round-trips through toCacheJson', () {
    final original = IbadatReport(
      id: 'r1',
      userId: 'u1',
      groupId: 'g1',
      periodId: 'p1',
      month: 9,
      year: 2026,
      metricValues: {'m1': 13, 'm2': 0},
      submittedAt: DateTime.utc(2026, 9, 29, 8),
      updatedAt: DateTime.utc(2026, 9, 30, 9),
    );

    final copy = IbadatReport.fromJson(original.toCacheJson());

    expect(copy.id, original.id);
    expect(copy.userId, original.userId);
    expect(copy.groupId, original.groupId);
    expect(copy.periodId, original.periodId);
    expect(copy.month, original.month);
    expect(copy.year, original.year);
    expect(copy.metricValues, original.metricValues);
    expect(copy.submittedAt, original.submittedAt);
    expect(copy.updatedAt, original.updatedAt);
  });
}
