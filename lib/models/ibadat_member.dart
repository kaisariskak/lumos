class IbadatMember {
  final String id;
  final String userId;
  final String groupId;
  final DateTime joinedAt;

  const IbadatMember({
    required this.id,
    required this.userId,
    required this.groupId,
    required this.joinedAt,
  });

  factory IbadatMember.fromJson(Map<String, dynamic> json) {
    return IbadatMember(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      groupId: json['group_id'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
