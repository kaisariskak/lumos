import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../models/ibadat_profile.dart';
import '../../repositories/profile_repository.dart';

/// Combined nickname + invite code screen shown after Google sign-in
/// when the user has no profile yet. Calls the `register_with_invite`
/// RPC atomically.
class RegistrationScreen extends StatefulWidget {
  /// Called with the freshly created profile on successful registration.
  final void Function(IbadatProfile profile) onRegistered;

  /// Called when the user taps "Sign out".
  final VoidCallback onLogout;

  const RegistrationScreen({
    super.key,
    required this.onRegistered,
    required this.onLogout,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nicknameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _nicknameError;
  String? _codeError;

  static final _nicknameRe = RegExp(r'^[A-Za-z\u0400-\u04FF0-9 _.\-]+$');

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  bool get _formValid {
    final n = _nicknameCtrl.text.trim();
    final c = _codeCtrl.text.trim();
    return n.length >= 2 &&
        n.length <= 32 &&
        _nicknameRe.hasMatch(n) &&
        c.isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_formValid || _loading) return;
    final s = S.of(context);
    setState(() {
      _loading = true;
      _nicknameError = null;
      _codeError = null;
    });

    final repo = ProfileRepository(Supabase.instance.client);
    try {
      final profile = await repo.registerWithInvite(
        nickname: _nicknameCtrl.text.trim(),
        code: _codeCtrl.text.trim().toUpperCase(),
      );
      if (!mounted) return;
      widget.onRegistered(profile);
    } on RegistrationException catch (e) {
      if (!mounted) return;
      // not_authenticated / already_registered are recoverable only via re-auth:
      // sign the user out so AuthGate refetches the profile from a clean state.
      if (e.reason == 'not_authenticated' || e.reason == 'already_registered') {
        widget.onLogout();
        return;
      }
      setState(() {
        _loading = false;
        switch (e.reason) {
          case 'nickname_taken':
            _nicknameError = s.errorNicknameTaken;
            break;
          case 'invalid_nickname':
            _nicknameError = s.errorNicknameInvalid;
            break;
          case 'invalid_code':
            _codeError = s.errorInviteInvalid;
            break;
          case 'expired_code':
          case 'code_already_used':
            _codeError = s.errorInviteExpired;
            break;
          default:
            _codeError = '${s.error}: $e';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _codeError = '${s.error}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF101820), Color(0xFF132B2B), Color(0xFF1F2430)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _RegistrationBrandHeader(),
                    const SizedBox(height: 24),
                    _RegistrationPanel(
                      loading: _loading,
                      formValid: _formValid,
                      nicknameController: _nicknameCtrl,
                      codeController: _codeCtrl,
                      nicknameError: _nicknameError,
                      codeError: _codeError,
                      onChanged: () => setState(() {}),
                      onSubmit: _submit,
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: widget.onLogout,
                      child: Text(
                        s.logout,
                        style: const TextStyle(color: Color(0xFF789085)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegistrationBrandHeader extends StatelessWidget {
  const _RegistrationBrandHeader();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: const Color(0xFF152A2D),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x334ADE80)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3322C55E),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            color: Color(0xFFF6C453),
            size: 38,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          s.appTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.appSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFB8C7C1), fontSize: 14),
        ),
      ],
    );
  }
}

class _RegistrationPanel extends StatelessWidget {
  final bool loading;
  final bool formValid;
  final TextEditingController nicknameController;
  final TextEditingController codeController;
  final String? nicknameError;
  final String? codeError;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  const _RegistrationPanel({
    required this.loading,
    required this.formValid,
    required this.nicknameController,
    required this.codeController,
    required this.nicknameError,
    required this.codeError,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xE61B2528),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x244ADE80)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.registrationTitle,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _RegistrationField(
            controller: nicknameController,
            label: s.nicknameLabel,
            hint: s.nicknameHint,
            icon: Icons.badge_outlined,
            errorText: nicknameError,
            maxLength: 32,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          _RegistrationField(
            controller: codeController,
            label: s.inviteCodeLabel,
            hint: s.inviteCodeShortHint,
            icon: Icons.key_rounded,
            errorText: codeError,
            maxLength: 12,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                return newValue.copyWith(text: newValue.text.toUpperCase());
              }),
            ],
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: formValid && !loading ? onSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: const Color(0xFF062014),
              disabledBackgroundColor: const Color(0x5534D399),
              disabledForegroundColor: const Color(0x889DB5AB),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF062014),
                    ),
                  )
                : Text(
                    s.submitRegistration,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? errorText;
  final int maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  const _RegistrationField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.errorText,
    required this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      style: const TextStyle(
        color: Color(0xFFF8FAFC),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: Icon(icon, color: const Color(0xFF8DB9A5)),
        filled: true,
        fillColor: const Color(0xFF111A1D),
        labelStyle: const TextStyle(color: Color(0xFF9DB5AB)),
        hintStyle: const TextStyle(color: Color(0xFF51635D)),
        errorMaxLines: 2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x2234D399)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x2234D399)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF22C55E), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
    );
  }
}
