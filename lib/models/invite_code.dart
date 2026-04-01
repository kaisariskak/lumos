class InviteCode {
  final int id;
  final String code;
  final String roleType;   // 'ADMIN' or 'USER'
  final String? groupId;
  final bool isUsed;
  final DateTime expiresAt;
  final String? createdBy;

  const InviteCode({
    required this.id,
    required this.code,
    required this.roleType,
    this.groupId,
    required this.isUsed,
    required this.expiresAt,
    this.createdBy,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isUsed && !isExpired;

  factory InviteCode.fromJson(Map<String, dynamic> json) {
    return InviteCode(
      id: json['id'] as int,
      code: json['code'] as String,
      roleType: json['role_type'] as String,
      groupId: json['group_id'] as String?,
      isUsed: json['is_used'] as bool,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'role_type': roleType,
        'group_id': groupId,
        'is_used': isUsed,
        'expires_at': expiresAt.toIso8601String(),
        'created_by': createdBy,
      };
}
