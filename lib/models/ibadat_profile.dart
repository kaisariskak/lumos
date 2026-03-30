class IbadatProfile {
  final String id;
  final String displayName;
  final String email;
  final String? avatarUrl;
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
    required this.displayName,
    required this.email,
    this.avatarUrl,
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
      displayName: json['display_name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
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
      'display_name': displayName,
      'email': email,
      'avatar_url': avatarUrl,
      'role': role,
      'current_group_id': currentGroupId,
    };
  }

  IbadatProfile copyWith({
    String? displayName,
    String? email,
    String? avatarUrl,
    String? role,
    String? currentGroupId,
    String? superAdminId,
    String? createdByAdminId,
  }) {
    return IbadatProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      currentGroupId: currentGroupId ?? this.currentGroupId,
      superAdminId: superAdminId ?? this.superAdminId,
      createdByAdminId: createdByAdminId ?? this.createdByAdminId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
