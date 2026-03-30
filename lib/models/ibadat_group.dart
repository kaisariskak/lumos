import 'ibadat_profile.dart';

class IbadatGroup {
  final String id;
  final String name;
  final String code;
  final String adminId;
  final String? financierId;
  final DateTime createdAt;
  List<IbadatProfile> members;

  IbadatGroup({
    required this.id,
    required this.name,
    required this.code,
    required this.adminId,
    this.financierId,
    required this.createdAt,
    this.members = const [],
  });

  factory IbadatGroup.fromJson(Map<String, dynamic> json) {
    return IbadatGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      adminId: json['admin_id'] as String,
      financierId: json['financier_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'admin_id': adminId,
      if (financierId != null) 'financier_id': financierId,
    };
  }
}
