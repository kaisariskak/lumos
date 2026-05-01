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

  static final _nicknameRe = RegExp(
    r'^[A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі0-9 _.\-]+$',
  );

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  bool get _formValid {
    final n = _nicknameCtrl.text.trim();
    final c = _codeCtrl.text.trim();
    return n.length >= 2 && n.length <= 32 && _nicknameRe.hasMatch(n) && c.isNotEmpty;
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
          case 'already_registered':
            // Server says profile exists — bounce back via onRegistered.
            // Caller's _loadProfile will refetch and route correctly.
            // We have no profile object here, so just log out / let parent reload.
            _codeError = '${s.error}: $e';
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Text('🌙', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  s.registrationTitle,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Nickname
                TextField(
                  controller: _nicknameCtrl,
                  onChanged: (_) => setState(() {}),
                  maxLength: 32,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: s.nicknameLabel,
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    hintText: s.nicknameHint,
                    hintStyle: const TextStyle(color: Color(0xFF334155)),
                    errorText: _nicknameError,
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Color(0xFF6366F1), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),

                // Invite code
                TextField(
                  controller: _codeCtrl,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return newValue.copyWith(text: newValue.text.toUpperCase());
                    }),
                  ],
                  maxLength: 12,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: s.inviteCodeLabel,
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    hintText: s.inviteCodeShortHint,
                    hintStyle: const TextStyle(
                      color: Color(0xFF334155),
                      letterSpacing: 2,
                    ),
                    errorText: _codeError,
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Color(0xFF6366F1), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_formValid && !_loading) ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF4F46E5).withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            s.submitRegistration,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: widget.onLogout,
                  child: Text(
                    s.logout,
                    style: const TextStyle(color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
