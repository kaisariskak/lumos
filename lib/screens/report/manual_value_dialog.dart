import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/accent_provider.dart';

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

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  void _cancel() {
    _dismissKeyboard();
    Navigator.of(context).pop();
  }

  void _save() {
    if (!_isValid) return;
    _dismissKeyboard();
    Navigator.of(context).pop(int.parse(_ctrl.text.trim()));
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AccentProvider.instance.current;
    return AlertDialog(
      backgroundColor: const Color(0xFF152A2D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: const TextStyle(
          color: Color(0xFFE2E8F0),
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onEditingComplete: _dismissKeyboard,
            onSubmitted: (_) => _dismissKeyboard(),
            keyboardType: const TextInputType.numberWithOptions(
              signed: false,
              decimal: false,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              suffixText: widget.unitLabel,
              suffixStyle: const TextStyle(color: Color(0xFF94A3B8)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: accent.accent, width: 2),
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
          onPressed: _cancel,
          child: Text(
            widget.cancelLabel,
            style: const TextStyle(color: Color(0xFF94A3B8)),
          ),
        ),
        TextButton(
          onPressed: _isValid ? _save : null,
          child: Text(
            widget.saveLabel,
            style: TextStyle(
              color: _isValid ? accent.accentLight : const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
