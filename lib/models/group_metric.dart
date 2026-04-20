import 'package:flutter/material.dart';

class GroupMetric {
  final String? id;
  final String? groupId;
  final String? adminId;
  final String nameRu;
  final String nameKk;
  final String icon;
  final int colorValue;
  final String unit;
  final int maxValue;
  final int orderIndex;
  final DateTime createdAt;

  const GroupMetric({
    this.id,
    this.groupId,
    this.adminId,
    required this.nameRu,
    required this.nameKk,
    required this.icon,
    required this.colorValue,
    required this.unit,
    required this.maxValue,
    required this.orderIndex,
    required this.createdAt,
  }) : assert(
          (groupId != null) != (adminId != null),
          'Exactly one of groupId or adminId must be non-null',
        );

  factory GroupMetric.fromJson(Map<String, dynamic> json) {
    final legacyName = (json['name'] as String?) ?? '';
    final nameRu = (json['name_ru'] as String?)?.trim();
    final nameKk = (json['name_kk'] as String?)?.trim();
    return GroupMetric(
      id: json['id'] as String?,
      groupId: json['group_id'] as String?,
      adminId: json['admin_id'] as String?,
      nameRu: (nameRu == null || nameRu.isEmpty) ? legacyName : nameRu,
      nameKk: (nameKk == null || nameKk.isEmpty) ? legacyName : nameKk,
      icon: json['icon'] as String,
      colorValue: (json['color_value'] as num).toInt().toUnsigned(32),
      unit: json['unit'] as String,
      maxValue: (json['max_value'] as num).toInt(),
      orderIndex: (json['order_index'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Color get color => Color(colorValue.toUnsigned(32));

  /// Returns the name for the given language code, falling back to the other
  /// language if the requested one is empty.
  String localizedName(String lang) {
    if (lang == 'ru') {
      if (nameRu.isNotEmpty) return nameRu;
      return nameKk;
    }
    if (nameKk.isNotEmpty) return nameKk;
    return nameRu;
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'admin_id': adminId,
      'name_ru': nameRu,
      'name_kk': nameKk,
      'icon': icon,
      'color_value': colorValue.toSigned(32),
      'unit': unit,
      'max_value': maxValue,
      'order_index': orderIndex,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory GroupMetric.test({
    String? id,
    String? groupId = 'group-1',
    String? adminId,
    String nameRu = 'Показатель',
    String nameKk = 'Көрсеткіш',
    String icon = 'star',
    int colorValue = 0xFF6366F1,
    String unit = 'unit',
    int maxValue = 10,
    int orderIndex = 0,
    DateTime? createdAt,
  }) {
    return GroupMetric(
      id: id,
      groupId: adminId != null ? null : groupId,
      adminId: adminId,
      nameRu: nameRu,
      nameKk: nameKk,
      icon: icon,
      colorValue: colorValue,
      unit: unit,
      maxValue: maxValue,
      orderIndex: orderIndex,
      createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
