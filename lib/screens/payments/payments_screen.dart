import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../models/ibadat_group.dart';
import '../../models/ibadat_member_settings.dart';
import '../../models/ibadat_payment.dart';
import '../../models/ibadat_profile.dart';
import '../../repositories/ibadat_group_repository.dart';
import '../../repositories/member_settings_repository.dart';
import '../../repositories/payment_repository.dart';
import 'member_payments_screen.dart';

class PaymentsScreen extends StatefulWidget {
  final IbadatProfile profile;
  final IbadatGroup group;

  const PaymentsScreen({
    super.key,
    required this.profile,
    required this.group,
  });

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late final PaymentRepository _paymentRepo;
  late final IbadatGroupRepository _groupRepo;
  late final MemberSettingsRepository _settingsRepo;

  List<IbadatProfile> _members = [];
  Map<String, List<IbadatPayment>> _paymentsMap = {};
  Map<String, IbadatMemberSettings> _settingsMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _paymentRepo = PaymentRepository(client);
    _groupRepo = IbadatGroupRepository(client);
    _settingsRepo = MemberSettingsRepository(client);
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _groupRepo.getGroupMembers(widget.group.id),
        _paymentRepo.getPaymentsByGroup(widget.group.id),
        _settingsRepo.getSettingsForGroup(widget.group.id),
      ]);

      final members = results[0] as List<IbadatProfile>;
      final allPayments = results[1] as List<IbadatPayment>;
      final settings = results[2] as Map<String, IbadatMemberSettings>;

      final map = <String, List<IbadatPayment>>{};
      for (final m in members) {
        map[m.id] = allPayments.where((p) => p.profileId == m.id).toList();
      }

      setState(() {
        _members = members;
        _paymentsMap = map;
        _settingsMap = settings;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  double _totalForMember(String profileId) =>
      (_paymentsMap[profileId] ?? [])
          .fold(0.0, (s, p) => s + p.amount);

  bool _paidThisMonth(String profileId) {
    final now = DateTime.now();
    final fixed = _settingsMap[profileId]?.fixedMonthlyAmount ?? 0;
    final monthPayments = (_paymentsMap[profileId] ?? []).where((p) =>
        !p.paidExtra &&
        p.paymentDate != null &&
        p.paymentDate!.year == now.year &&
        p.paymentDate!.month == now.month);

    if (fixed > 0) {
      final monthTotal =
          monthPayments.fold(0.0, (s, p) => s + p.amount);
      return monthTotal >= fixed;
    }
    return monthPayments.any((p) => p.paidMonth);
  }

  double get _grandTotal => _members.fold(
      0.0, (s, m) => s + _totalForMember(m.id));

  int get _paidCount =>
      _members.where((m) => _paidThisMonth(m.id)).length;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💼', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.profile.displayName} · ${s.financierLabel}',
                        style: const TextStyle(
                          color: Color(0xFF6EE7B7),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFF6EE7B7), Color(0xFF10B981)],
                  ).createShader(b),
                  child: Text(
                    s.paymentsTitle,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF10B981)))
          else ...[
            // Summary card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF064E3B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      emoji: '👥',
                      label: s.allMembers,
                      value: '${_members.length}',
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.15)),
                  Expanded(
                    child: _SummaryItem(
                      emoji: '✅',
                      label: s.thisMonth,
                      value: '$_paidCount/${_members.length}',
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.15)),
                  Expanded(
                    child: _SummaryItem(
                      emoji: '💰',
                      label: s.total,
                      value: _formatAmount(_grandTotal),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              '👥 ${s.membersTitle}',
              style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
            const SizedBox(height: 10),

            if (_members.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(s.noMembers,
                      style: const TextStyle(color: Color(0xFF64748B))),
                ),
              )
            else
              ..._members.asMap().entries.map((e) {
                final idx = e.key;
                final member = e.value;
                final paid = _paidThisMonth(member.id);
                final total = _totalForMember(member.id);
                final count = (_paymentsMap[member.id] ?? []).length;
                final fixed =
                    _settingsMap[member.id]?.fixedMonthlyAmount ?? 0;
                return _MemberPaymentTile(
                  member: member,
                  index: idx,
                  paidThisMonth: paid,
                  totalPaid: total,
                  paymentCount: count,
                  fixedMonthlyAmount: fixed,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemberPaymentsScreen(
                          member: member,
                          groupId: widget.group.id,
                          financierId: widget.profile.id,
                        ),
                      ),
                    );
                    _load();
                  },
                );
              }),
          ],
        ],
      ),
    );
  }

  String _formatAmount(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}М ₸';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}К ₸';
    return '${v.toStringAsFixed(0)} ₸';
  }
}

class _SummaryItem extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _SummaryItem(
      {required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        Text(label,
            style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 10)),
      ],
    );
  }
}

class _MemberPaymentTile extends StatelessWidget {
  final IbadatProfile member;
  final int index;
  final bool paidThisMonth;
  final double totalPaid;
  final int paymentCount;
  final double fixedMonthlyAmount;
  final VoidCallback onTap;

  static const _colors = [
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
  ];

  const _MemberPaymentTile({
    required this.member,
    required this.index,
    required this.paidThisMonth,
    required this.totalPaid,
    required this.paymentCount,
    this.fixedMonthlyAmount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  color.withValues(alpha: 0.4),
                  color.withValues(alpha: 0.2),
                ]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  member.displayName[0].toUpperCase(),
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.displayName,
                      style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '$paymentCount ${S.of(context).paymentUnit} · ${totalPaid.toStringAsFixed(0)} ₸',
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 11),
                  ),
                  if (fixedMonthlyAmount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${S.of(context).fixedAmountLabel}: ${fixedMonthlyAmount.toStringAsFixed(0)} ₸',
                      style: const TextStyle(
                          color: Color(0xFF6366F1), fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: paidThisMonth
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    paidThisMonth ? S.of(context).paidLabel : S.of(context).unpaidLabel,
                    style: TextStyle(
                      color: paidThisMonth
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF475569), size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
