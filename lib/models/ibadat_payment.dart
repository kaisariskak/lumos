class IbadatPayment {
  final int? id;
  final String groupId;
  final String profileId;
  final double amount;
  final DateTime? paymentDate;
  final bool paidMonth;
  final bool paidExtra;
  final String? createdBy;
  final DateTime? createdAt;

  const IbadatPayment({
    this.id,
    required this.groupId,
    required this.profileId,
    required this.amount,
    this.paymentDate,
    required this.paidMonth,
    required this.paidExtra,
    this.createdBy,
    this.createdAt,
  });

  factory IbadatPayment.fromJson(Map<String, dynamic> json) {
    return IbadatPayment(
      id: json['id'] as int?,
      groupId: json['group_id'] as String,
      profileId: json['profile_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentDate: json['payment_date'] != null
          ? DateTime.parse(json['payment_date'] as String)
          : null,
      paidMonth: json['paid_month'] as bool? ?? false,
      paidExtra: json['paid_extra'] as bool? ?? false,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'profile_id': profileId,
      'amount': amount,
      'payment_date': paymentDate?.toIso8601String().split('T').first,
      'paid_month': paidMonth,
      'paid_extra': paidExtra,
      if (createdBy != null) 'created_by': createdBy,
    };
  }

  IbadatPayment copyWith({
    double? amount,
    DateTime? paymentDate,
    bool? paidMonth,
    bool? paidExtra,
  }) {
    return IbadatPayment(
      id: id,
      groupId: groupId,
      profileId: profileId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paidMonth: paidMonth ?? this.paidMonth,
      paidExtra: paidExtra ?? this.paidExtra,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}
