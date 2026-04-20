class IbadatReport {
  final String? id;
  final String userId;
  final String? groupId;
  final String? periodId;
  final int month;
  final int year;
  final Map<String, int> metricValues;
  final DateTime? submittedAt;
  final DateTime? updatedAt;

  IbadatReport({
    this.id,
    required this.userId,
    this.groupId,
    this.periodId,
    required this.month,
    required this.year,
    Map<String, int>? metricValues,
    this.submittedAt,
    this.updatedAt,
  }) : metricValues = Map<String, int>.of(metricValues ?? const <String, int>{});

  factory IbadatReport.fromJson(Map<String, dynamic> json) {
    return IbadatReport(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      groupId: json['group_id'] as String?,
      periodId: json['period_id'] as String?,
      month: json['month'] as int,
      year: json['year'] as int,
      metricValues: _readMetricValues(json),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'group_id': groupId,
      if (periodId != null) 'period_id': periodId,
      'month': month,
      'year': year,
    };
  }

  IbadatReport copyWith({
    String? id,
    String? userId,
    String? groupId,
    String? periodId,
    int? month,
    int? year,
    Map<String, int>? metricValues,
    DateTime? submittedAt,
    DateTime? updatedAt,
  }) {
    return IbadatReport(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      periodId: periodId ?? this.periodId,
      month: month ?? this.month,
      year: year ?? this.year,
      metricValues: Map<String, int>.of(metricValues ?? this.metricValues),
      submittedAt: submittedAt ?? this.submittedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int valueForMetric(String metricId) => metricValues[metricId] ?? 0;

  int getValue(String key) => valueForMetric(key);

  void setValue(String key, int value) {
    metricValues[key] = value;
  }

  static Map<String, int> _readMetricValues(Map<String, dynamic> json) {
    final raw = json['metric_values'];
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value as int));
    }
    return const <String, int>{};
  }
}
