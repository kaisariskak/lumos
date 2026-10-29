class IbadatPeriod {
  final String id;
  final String? groupId;
  final String label;
  final DateTime startDate;
  final DateTime endDate;
  final String createdBy;
  final DateTime createdAt;
  final bool isPersonal;

  IbadatPeriod({
    required this.id,
    this.groupId,
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.createdBy,
    required this.createdAt,
    this.isPersonal = false,
  });

  factory IbadatPeriod.fromJson(Map<String, dynamic> json) {
    return IbadatPeriod(
      id: json['id'] as String,
      groupId: json['group_id'] as String?,
      label: json['label'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isPersonal: json['is_personal'] as bool? ?? false,
    );
  }

  /// Full inverse of [IbadatPeriod.fromJson], used for the local cache.
  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'group_id': groupId,
      'label': label,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'is_personal': isPersonal,
    };
  }

  String get dateRangeLabel => dateRangeLabelLocalized('kk');

  String dateRangeLabelLocalized(String lang) {
    const kkMonths = [
      'қаң', 'ақп', 'нау', 'сәу', 'мам', 'мау',
      'шіл', 'там', 'қыр', 'қаз', 'қар', 'жел'
    ];
    const ruMonths = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    final months = lang == 'ru' ? ruMonths : kkMonths;
    return '${startDate.day} ${months[startDate.month - 1]} – '
        '${endDate.day} ${months[endDate.month - 1]}';
  }
}
