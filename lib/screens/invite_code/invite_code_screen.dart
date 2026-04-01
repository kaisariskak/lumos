import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../models/invite_code.dart';
import '../../repositories/invite_code_repository.dart';

/// Guard screen shown after Google Sign-In when the user has no profile
/// or no group yet. The user must enter a valid invite code to proceed.
class InviteCodeScreen extends StatefulWidget {
  /// Called with the validated [InviteCode] once the user enters a correct code.
  final void Function(InviteCode code) onCodeValidated;

  /// Called when the user taps "Sign out".
  final VoidCallback onLogout;

  const InviteCodeScreen({
    super.key,
    required this.onCodeValidated,
    required this.onLogout,
  });

  @override
  State<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends State<InviteCodeScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _codeCtrl.text.trim();
    if (raw.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final s = S.of(context);
    try {
      final repo = InviteCodeRepository(Supabase.instance.client);
      final code = await repo.validateCode(raw);
      if (!mounted) return;
      widget.onCodeValidated(code);
    } on InviteCodeNotFoundException {
      if (!mounted) return;
      setState(() {
        _error = s.inviteCodeNotFound;
        _loading = false;
      });
    } on InviteCodeExpiredException {
      if (!mounted) return;
      setState(() {
        _error = s.inviteCodeExpired;
        _loading = false;
      });
    } on InviteCodeUsedException {
      if (!mounted) return;
      setState(() {
        _error = s.inviteCodeUsed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${s.error}: $e';
        _loading = false;
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
                // Icon
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
                    child: Text('🔑', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  s.inviteCodeTitle,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  s.inviteCodeSubtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Code input
                TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                  textAlign: TextAlign.center,
                  maxLength: 10,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'ADM-XXXXXX',
                    hintStyle: const TextStyle(
                      color: Color(0xFF334155),
                      letterSpacing: 2,
                      fontSize: 18,
                    ),
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
                        horizontal: 20, vertical: 18),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),

                // Error
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 20),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
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
                            s.inviteCodeCheck,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Logout
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
