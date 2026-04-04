import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../models/ibadat_member_settings.dart';
import '../../models/ibadat_payment.dart';
import '../../models/ibadat_profile.dart';
import '../../repositories/member_settings_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../theme/accent_provider.dart';
import 'add_payment_dialog.dart';

class MemberPaymentsScreen extends StatefulWidget {
  final IbadatProfile member;
  final String groupId;
  final String financierId;

  const MemberPaymentsScreen({
    super.key,
    required this.member,
    required this.groupId,
    required this.financierId,
  });

  @override
  State<MemberPaymentsScreen> createState() => _MemberPaymentsScreenState();
}

class _MemberPaymentsScreenState extends State<MemberPaymentsScreen> {
  late final PaymentRepository _repo;
  late final MemberSettingsRepository _settingsRepo;
  List<IbadatPayment> _payments = [];
  double _fixedMonthlyAmount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _repo = PaymentRepository(client);
    _settingsRepo = MemberSettingsRepository(client);
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repo.getPaymentsByProfile(widget.groupId, widget.member.id),
        _settingsRepo.getSettings(widget.groupId, widget.member.id),
      ]);
      setState(() {
        _payments = results[0] as List<IbadatPayment>;
        final settings = results[1] as IbadatMemberSettings?;
        _fixedMonthlyAmount = settings?.fixedMonthlyAmount ?? 0;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editFixedAmount() async {
    final ctrl = TextEditingController(
        text: _fixedMonthlyAmount > 0
            ? _fixedMonthlyAmount.toStringAsFixed(0)
            : '');
    final s = S.of(context);
    final result = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.fixedMonthlyAmount,
            style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 20,
              fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: s.fixedAmountHint,
            hintStyle: const TextStyle(color: Color(0xFF475569)),
            suffix: Text('₸',
                style: TextStyle(
                    color: AccentProvider.instance.current.accent,
                    fontWeight: FontWeight.w700)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AccentProvider.instance.current.accent),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel,
                style: const TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim()) ?? 0;
              Navigator.pop(context, v);
            },
            child: Text(s.save,
                style: TextStyle(color: AccentProvider.instance.current.accent)),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await _settingsRepo.upsertSettings(IbadatMemberSettings(
        groupId: widget.groupId,
        profileId: widget.member.id,
        fixedMonthlyAmount: result,
      ));
      setState(() => _fixedMonthlyAmount = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
    }
  }

  Future<void> _addOrEdit([IbadatPayment? existing]) async {
    final result = await showDialog<IbadatPayment>(
      context: context,
      builder: (_) => AddPaymentDialog(
        member: widget.member,
        groupId: widget.groupId,
        createdBy: widget.financierId,
        existing: existing,
        fixedMonthlyAmount: _fixedMonthlyAmount,
      ),
    );
    if (result == null) return;
    try {
      if (existing != null) {
        await _repo.updatePayment(result);
      } else {
        await _repo.addPayment(result);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${S.of(context).error}: $e')));
    }
  }

  Future<void> _delete(IbadatPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Builder(
          builder: (ctx) {
            final s = S.of(ctx);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🗑️', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 12),
                Text(
                  s.deletePaymentConfirm,
                  style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).no,
                style: const TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).delete,
                style: const TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.deletePayment(payment.id!);
      await _load();
    }
  }

  double get _totalPaid =>
      _payments.fold(0.0, (s, p) => s + p.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0F172A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button + header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chevron_left,
                                color: Color(0xFF94A3B8), size: 20),
                            Text(S.of(context).back,
                                style: const TextStyle(
                                    color: Color(0xFF94A3B8), fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.member.displayName,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: _editFixedAmount,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline,
                                color: Color(0xFFA5B4FC), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _fixedMonthlyAmount > 0
                                  ? '${_fixedMonthlyAmount.toStringAsFixed(0)} ₸'
                                  : S.of(context).fixedAmountLabel,
                              style: const TextStyle(
                                  color: Color(0xFFA5B4FC), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Stats card
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AccentProvider.instance.current.accentDark.withValues(alpha: 0.8),
                        AccentProvider.instance.current.accentDark,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatItem(
                          label: S.of(context).allPaymentsLabel,
                          value: '${_payments.length}',
                          unit: S.of(context).timesUnit,
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withValues(alpha: 0.15)),
                      Expanded(
                        child: _StatItem(
                          label: S.of(context).total,
                          value: _formatAmount(_totalPaid),
                          unit: '₸',
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withValues(alpha: 0.15)),
                      Expanded(
                        child: _StatItem(
                          label: S.of(context).fixedAmountLabel,
                          value: _fixedMonthlyAmount > 0
                              ? _formatAmount(_fixedMonthlyAmount)
                              : '—',
                          unit: _fixedMonthlyAmount > 0 ? '₸' : '',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Payments list
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: AccentProvider.instance.current.accent))
                    : _payments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('💸',
                                    style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                Text(
                                  S.of(context).noPayments,
                                  style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 15),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () => _addOrEdit(),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: Text(S.of(context).addPayment),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AccentProvider.instance.current.accent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: _payments.length,
                            itemBuilder: (_, i) => _PaymentTile(
                              payment: _payments[i],
                              fixedMonthlyAmount: _fixedMonthlyAmount,
                              onEdit: () => _addOrEdit(_payments[i]),
                              onDelete: () => _delete(_payments[i]),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _payments.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _addOrEdit(),
              backgroundColor: AccentProvider.instance.current.accent,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  String _formatAmount(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}М';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}К';
    return v.toStringAsFixed(0);
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatItem(
      {required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20)),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(unit,
                  style: TextStyle(
                      color: AccentProvider.instance.current.accentLight, fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: AccentProvider.instance.current.accentLight, fontSize: 10)),
      ],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final IbadatPayment payment;
  final double fixedMonthlyAmount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PaymentTile({
    required this.payment,
    required this.fixedMonthlyAmount,
    required this.onEdit,
    required this.onDelete,
  });

  bool _isPaid() {
    final date = payment.paymentDate;
    final now = DateTime.now();
    final isCurrentMonth = date != null &&
        date.year == now.year &&
        date.month == now.month;

    // Текущий месяц + фиксированная сумма → автоматический расчёт
    if (isCurrentMonth && fixedMonthlyAmount > 0) {
      return payment.amount >= fixedMonthlyAmount;
    }

    // Прошлые месяцы → ручной статус финансиста
    return payment.paidMonth;
  }

  @override
  Widget build(BuildContext context) {
    final date = payment.paymentDate;
    final dateStr = date != null
        ? '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'
        : '—';
    final isPaid = _isPaid();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isPaid
                  ? AccentProvider.instance.current.accent.withValues(alpha: 0.12)
                  : const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                isPaid ? Icons.check_circle : Icons.schedule,
                color: isPaid
                    ? AccentProvider.instance.current.accent
                    : const Color(0xFFEF4444),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${payment.amount.toStringAsFixed(0)} ₸',
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: payment.paidExtra
                            ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                            : AccentProvider.instance.current.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        payment.paidExtra ? S.of(context).extraLabel : S.of(context).monthlyLabel,
                        style: TextStyle(
                          color: payment.paidExtra
                              ? const Color(0xFFA5B4FC)
                              : AccentProvider.instance.current.accentLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 10, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(dateStr,
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 11)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? AccentProvider.instance.current.accent.withValues(alpha: 0.1)
                            : const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isPaid ? S.of(context).paidStatus : S.of(context).unpaidStatus,
                        style: TextStyle(
                          color: isPaid
                              ? AccentProvider.instance.current.accent
                              : const Color(0xFFEF4444),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined,
                color: Color(0xFF94A3B8), size: 16),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                color: Color(0xFFEF4444), size: 16),
            style: IconButton.styleFrom(
              backgroundColor:
                  const Color(0xFFEF4444).withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}
