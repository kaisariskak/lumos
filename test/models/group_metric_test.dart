import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/models/group_metric.dart';

void main() {
  test('parses a group metric from json and serializes insert payload', () {
    final metric = GroupMetric.fromJson({
      'id': 'metric-1',
      'group_id': 'group-1',
      'name_ru': 'Страницы Корана',
      'name_kk': 'Құран беттері',
      'icon': 'book',
      'color_value': 0xFF0D9488,
      'unit': 'page',
      'max_value': 40,
      'order_index': 2,
      'created_at': '2026-04-18T10:00:00.000Z',
    });

    expect(metric.id, 'metric-1');
    expect(metric.groupId, 'group-1');
    expect(metric.nameRu, 'Страницы Корана');
    expect(metric.nameKk, 'Құран беттері');
    expect(metric.icon, 'book');
    expect(metric.colorValue, 0xFF0D9488);
    expect(metric.color, const Color(0xFF0D9488));
    expect(metric.unit, 'page');
    expect(metric.maxValue, 40);
    expect(metric.orderIndex, 2);
    expect(metric.createdAt, DateTime.parse('2026-04-18T10:00:00.000Z'));

    expect(metric.toJson(), {
      'group_id': 'group-1',
      'admin_id': null,
      'name_ru': 'Страницы Корана',
      'name_kk': 'Құран беттері',
      'icon': 'book',
      'color_value': 0xFF0D9488.toSigned(32),
      'unit': 'page',
      'max_value': 40,
      'order_index': 2,
      'created_at': '2026-04-18T10:00:00.000Z',
    });
  });

  test('parses admin-scoped metric with null group_id', () {
    final metric = GroupMetric.fromJson({
      'id': 'metric-2',
      'group_id': null,
      'admin_id': 'admin-1',
      'name_ru': 'Личное',
      'name_kk': 'Жеке',
      'icon': 'star',
      'color_value': 0xFF7C3AED,
      'unit': 'unit',
      'max_value': 5,
      'order_index': 0,
      'created_at': '2026-04-20T10:00:00.000Z',
    });

    expect(metric.groupId, isNull);
    expect(metric.adminId, 'admin-1');
  });

  test('falls back to legacy name when localized fields are missing', () {
    final metric = GroupMetric.fromJson({
      'id': 'metric-1',
      'group_id': 'group-1',
      'name': 'Quran pages',
      'icon': 'book',
      'color_value': 0xFF0D9488,
      'unit': 'page',
      'max_value': 40,
      'order_index': 2,
      'created_at': '2026-04-18T10:00:00.000Z',
    });

    expect(metric.nameRu, 'Quran pages');
    expect(metric.nameKk, 'Quran pages');
  });

  test('localizedName picks the right language and falls back', () {
    final metric = GroupMetric.test(nameRu: 'Страницы', nameKk: 'Беттер');
    expect(metric.localizedName('ru'), 'Страницы');
    expect(metric.localizedName('kk'), 'Беттер');

    final onlyRu = GroupMetric.test(nameRu: 'Страницы', nameKk: '');
    expect(onlyRu.localizedName('kk'), 'Страницы');

    final onlyKk = GroupMetric.test(nameRu: '', nameKk: 'Беттер');
    expect(onlyKk.localizedName('ru'), 'Беттер');
  });
}
