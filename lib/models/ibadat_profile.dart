class IbadatProfile {
  final String id;
  final String nickname;
  final String role;
  final String? currentGroupId;
  /// For admin users: the super-admin who created them
  final String? superAdminId;
  /// For regular users: the admin who added them to the system
  final String? createdByAdminId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IbadatProfile({
    required this.id,
    required this.nickname,
    required this.role,
    this.currentGroupId,
    this.superAdminId,
    this.createdByAdminId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';

  factory IbadatProfile.fromJson(Map<String, dynamic> json) {
    return IbadatProfile(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      role: json['role'] as String? ?? 'user',
      currentGroupId: json['current_group_id'] as String?,
      superAdminId: json['super_admin_id'] as String?,
      createdByAdminId: json['created_by_admin_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'role': role,
      'current_group_id': currentGroupId,
    };
  }

  IbadatProfile copyWith({
    String? nickname,
    String? role,
    String? currentGroupId,
    String? superAdminId,
    String? createdByAdminId,
  }) {
    return IbadatProfile(
      id: id,
      nickname: nickname ?? this.nickname,
      role: role ?? this.role,
      currentGroupId: currentGroupId ?? this.currentGroupId,
      superAdminId: superAdminId ?? this.superAdminId,
      createdByAdminId: createdByAdminId ?? this.createdByAdminId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
