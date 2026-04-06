import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../theme/accent_provider.dart';
import '../../models/ibadat_payment.dart';
import '../../models/ibadat_profile.dart';

class _ThousandSeparator extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(' ', '');
    if (digits.isEmpty) return next.copyWith(text: '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _fmt(double v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

class AddPaymentDialog extends StatefulWidget {
  final IbadatProfile member;
  final String groupId;
  final String createdBy;
  final IbadatPayment? existing;
  final double fixedMonthlyAmount;

  const AddPaymentDialog({
    super.key,
    required this.member,
    required this.groupId,
    required this.createdBy,
    this.existing,
    this.fixedMonthlyAmount = 0,
  });

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _amountCtrl = TextEditingController();
  DateTime? _paymentDate;
  bool _paidMonth = true;
  bool _paidExtra = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.existing!;
      _amountCtrl.text = _fmt(p.amount);
      _paymentDate = p.paymentDate;
      _paidMonth = p.paidMonth;
      _paidExtra = p.paidExtra;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: AccentProvider.instance.current.accent,
            surface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  bool _computePaidMonth(double amount) => _paidMonth;

  void _submit() {
    final raw = _amountCtrl.text.trim().replaceAll(' ', '');
    if (raw.isEmpty) return;
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) return;

    final payment = IbadatPayment(
      id: widget.existing?.id,
      groupId: widget.groupId,
      profileId: widget.member.id,
      amount: amount,
      paymentDate: _paymentDate,
      paidMonth: _computePaidMonth(amount),
      paidExtra: _paidExtra,
      createdBy: widget.createdBy,
    );
    Navigator.pop(context, payment);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AccentProvider.instance.current.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                      child: Text('💰', style: TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? s.editPayment : s.addPayment,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        widget.member.displayName,
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Amount
            Text(s.amountLabel,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ThousandSeparator()],
              style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                suffix: Text('₸',
                    style: TextStyle(
                        color: AccentProvider.instance.current.accent, fontWeight: FontWeight.w700)),
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
            const SizedBox(height: 16),

            // Date
            Text(s.paymentDate,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: AccentProvider.instance.current.accent, size: 16),
                    const SizedBox(width: 10),
                    Text(
                      _paymentDate == null
                          ? s.selectPaymentDate
                          : '${_paymentDate!.day.toString().padLeft(2, '0')}.${_paymentDate!.month.toString().padLeft(2, '0')}.${_paymentDate!.year}',
                      style: TextStyle(
                        color: _paymentDate == null
                            ? const Color(0xFF475569)
                            : const Color(0xFFE2E8F0),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Type toggles
            _TypeToggle(
              label: s.monthlyPayment,
              emoji: '📅',
              value: !_paidExtra,
              onTap: () => setState(() => _paidExtra = false),
            ),
            const SizedBox(height: 8),
            _TypeToggle(
              label: s.extraPayment,
              emoji: '⚡',
              value: _paidExtra,
              onTap: () => setState(() => _paidExtra = true),
            ),
            const SizedBox(height: 16),

            // Fixed amount info
            if (widget.fixedMonthlyAmount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        color: Color(0xFFA5B4FC), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s.fixedAmountLabel}: ${widget.fixedMonthlyAmount.toStringAsFixed(0)} ₸',
                        style: const TextStyle(
                            color: Color(0xFFA5B4FC), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Manual paid status toggle (always visible)
            GestureDetector(
              onTap: () => setState(() => _paidMonth = !_paidMonth),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _paidMonth
                      ? AccentProvider.instance.current.accent.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _paidMonth
                        ? AccentProvider.instance.current.accent.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _paidMonth
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: _paidMonth
                          ? AccentProvider.instance.current.accent
                          : const Color(0xFF475569),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _paidMonth ? s.paidStatus : s.unpaidStatus,
                      style: TextStyle(
                        color: _paidMonth
                            ? AccentProvider.instance.current.accent
                            : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(s.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AccentProvider.instance.current.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _isEdit ? s.save : s.add,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      )),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final String emoji;
  final bool value;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label,
    required this.emoji,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF6366F1).withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value
                ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: value
                    ? const Color(0xFFA5B4FC)
                    : const Color(0xFF64748B),
                fontSize: 13,
                fontWeight: value ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (value)
              const Icon(Icons.check, color: Color(0xFF6366F1), size: 16),
          ],
        ),
      ),
    );
  }
}
