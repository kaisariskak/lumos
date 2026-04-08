import 'package:flutter/material.dart';

import '../../services/pin_service.dart';
import '../../theme/accent_provider.dart';
import '../../l10n/app_strings.dart';

enum PinMode { enter, setup, confirm }

class PinScreen extends StatefulWidget {
  /// Called when PIN is successfully verified (enter mode) or set (setup mode).
  final VoidCallback onSuccess;

  /// If true — setup mode (set new PIN). If false — enter mode (verify PIN).
  final bool isSetup;

  /// Optional cancel callback (shown as back button).
  final VoidCallback? onCancel;

  const PinScreen({
    super.key,
    required this.onSuccess,
    this.isSetup = false,
    this.onCancel,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with SingleTickerProviderStateMixin {
  static const int _pinLength = 4;

  PinMode _mode = PinMode.enter;
  String _pin = '';
  String _firstPin = '';
  // 'wrong' | 'mismatch' | null
  String? _errorKey;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _mode = widget.isSetup ? PinMode.setup : PinMode.enter;

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin += digit;
      _errorKey = null;
    });
    if (_pin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 100), _submit);
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_mode == PinMode.enter) {
      final ok = await PinService.verifyPin(_pin);
      if (ok) {
        widget.onSuccess();
      } else {
        _shake();
        setState(() {
          _pin = '';
          _errorKey = 'wrong';
        });
      }
    } else if (_mode == PinMode.setup) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _mode = PinMode.confirm;
      });
    } else if (_mode == PinMode.confirm) {
      if (_pin == _firstPin) {
        await PinService.setPin(_pin);
        widget.onSuccess();
      } else {
        _shake();
        setState(() {
          _pin = '';
          _firstPin = '';
          _mode = PinMode.setup;
          _errorKey = 'mismatch';
        });
      }
    }
  }

  void _shake() {
    _shakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final accent = AccentProvider.instance.current.accent;
    final s = S.of(context);

    String titleText;
    switch (_mode) {
      case PinMode.enter:
        titleText = s.pinEnter;
        break;
      case PinMode.setup:
        titleText = s.pinNewCode;
        break;
      case PinMode.confirm:
        titleText = s.pinConfirm;
        break;
    }

    final errorText = _errorKey == 'mismatch' ? s.pinMismatch : _errorKey == 'wrong' ? s.pinWrong : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (widget.onCancel != null)
                    IconButton(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF94A3B8), size: 20),
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                ],
              ),
            ),

            const Spacer(),

            // Lock icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.lock_outline_rounded, color: accent, size: 36),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              titleText,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            // Error
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: errorText != null
                  ? Text(
                      errorText,
                      key: ValueKey(errorText),
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                    )
                  : const SizedBox(height: 16),
            ),
            const SizedBox(height: 24),

            // PIN dots
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                final offset = _shakeAnimation.value * 12 * ((_shakeAnimation.value * 6).toInt() % 2 == 0 ? 1 : -1);
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? accent : Colors.transparent,
                      border: Border.all(
                        color: filled ? accent : const Color(0xFF475569),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),

            const Spacer(),

            // Numpad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3']),
                  const SizedBox(height: 16),
                  _buildRow(['4', '5', '6']),
                  const SizedBox(height: 16),
                  _buildRow(['7', '8', '9']),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 72),
                      _DigitBtn(digit: '0', onTap: _onDigit),
                      _DeleteBtn(onTap: _onDelete),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _DigitBtn(digit: d, onTap: _onDigit)).toList(),
    );
  }
}

class _DigitBtn extends StatelessWidget {
  final String digit;
  final void Function(String) onTap;

  const _DigitBtn({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(digit),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 26,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteBtn extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.backspace_outlined, color: Color(0xFF94A3B8), size: 22),
        ),
      ),
    );
  }
}
