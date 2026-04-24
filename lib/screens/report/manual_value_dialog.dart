import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ManualValueDialog extends StatefulWidget {
  final int current;
  final String unitLabel;
  final Color color;
  final String title;
  final String hint;
  final String saveLabel;
  final String cancelLabel;

  const ManualValueDialog({
    super.key,
    required this.current,
    required this.unitLabel,
    required this.color,
    required this.title,
    required this.hint,
    required this.saveLabel,
    required this.cancelLabel,
  });

  @override
  State<ManualValueDialog> createState() => _ManualValueDialogState();
}

class _ManualValueDialogState extends State<ManualValueDialog> {
  late final TextEditingController _ctrl;
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current.toString());
    _isValid = widget.current >= 0;
    _ctrl.addListener(_onChanged);
  }

  void _onChanged() {
    final text = _ctrl.text.trim();
    final parsed = int.tryParse(text);
    setState(() => _isValid = text.isNotEmpty && parsed != null && parsed >= 0);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: const TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              suffixText: widget.unitLabel,
              suffixStyle: const TextStyle(color: Color(0xFF94A3B8)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: widget.color, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.hint,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel, style: const TextStyle(color: Color(0xFF94A3B8))),
        ),
        TextButton(
          onPressed: _isValid
              ? () => Navigator.of(context).pop(int.parse(_ctrl.text.trim()))
              : null,
          child: Text(
            widget.saveLabel,
            style: TextStyle(color: _isValid ? widget.color : const Color(0xFF475569), fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
