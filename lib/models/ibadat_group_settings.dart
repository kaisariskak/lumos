import 'ibadat_category.dart';

class IbadatGroupSettings {
  final String groupId;
  final Map<String, int> maxValues;

  IbadatGroupSettings({required this.groupId, required this.maxValues});

  /// Returns the configured max for a category key, falling back to IbadatCategory.monthMax
  int getMax(String key) {
    final v = maxValues[key] ?? 0;
    if (v > 0) return v;
    return IbadatCategory.all
        .firstWhere((c) => c.key == key,
            orElse: () => IbadatCategory.all.first)
        .monthMax;
  }

  factory IbadatGroupSettings.fromJson(Map<String, dynamic> json) {
    final maxValues = <String, int>{};
    for (final cat in IbadatCategory.all) {
      final dbKey = '${cat.key}_max';
      final val = json[dbKey];
      if (val != null) maxValues[cat.key] = val as int;
    }
    return IbadatGroupSettings(
      groupId: json['group_id'] as String,
      maxValues: maxValues,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'group_id': groupId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    for (final entry in maxValues.entries) {
      map['${entry.key}_max'] = entry.value;
    }
    return map;
  }

  IbadatGroupSettings copyWithMax(String key, int value) {
    return IbadatGroupSettings(
      groupId: groupId,
      maxValues: {...maxValues, key: value},
    );
  }
}
