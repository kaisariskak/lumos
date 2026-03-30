class IbadatMemberSettings {
  final String groupId;
  final String profileId;
  final double fixedMonthlyAmount;

  const IbadatMemberSettings({
    required this.groupId,
    required this.profileId,
    required this.fixedMonthlyAmount,
  });

  factory IbadatMemberSettings.fromJson(Map<String, dynamic> json) {
    return IbadatMemberSettings(
      groupId: json['group_id'] as String,
      profileId: json['profile_id'] as String,
      fixedMonthlyAmount:
          (json['fixed_monthly_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'profile_id': profileId,
        'fixed_monthly_amount': fixedMonthlyAmount,
      };
}
