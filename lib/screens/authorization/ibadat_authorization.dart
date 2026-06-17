import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../l10n/app_strings.dart';
import '../../repositories/profile_repository.dart';
import '../../services/auth_error_message.dart';
import '../../services/google_auth_error_action.dart';
import '../../services/google_sign_in_service.dart';
import '../../services/username_auth_mapper.dart';

typedef PasswordSignIn = Future<void> Function(String login, String password);
typedef PasswordRegistration = Future<void> Function(
  String login,
  String password,
  String nickname,
  String code,
);
typedef RegistrationPreflight = Future<void> Function(
  String nickname,
  String code,
);

enum _AuthLoadingTarget { password, google }

class IbadatAuthorization extends StatefulWidget {
  final PasswordSignIn? signInWithPassword;
  final PasswordRegistration? registerWithPassword;
  final RegistrationPreflight? preflightRegistration;
  final Future<void> Function()? rollbackFailedRegistration;
  final VoidCallback? onUsernameRegistrationStarted;
  final VoidCallback? onUsernameRegistrationFinished;
  final VoidCallback? onUsernameRegistrationCompleted;

  const IbadatAuthorization({
    super.key,
    this.signInWithPassword,
    this.registerWithPassword,
    this.preflightRegistration,
    this.rollbackFailedRegistration,
    this.onUsernameRegistrationStarted,
    this.onUsernameRegistrationFinished,
    this.onUsernameRegistrationCompleted,
  });

  @override
  State<IbadatAuthorization> createState() => _IbadatAuthorizationState();
}

class _IbadatAuthorizationState extends State<IbadatAuthorization> {
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  _AuthLoadingTarget? _loadingTarget;
  bool _registerMode = false;
  bool _passwordVisible = false;
  String? _loginError;
  String? _passwordError;
  String? _nicknameError;
  String? _codeError;

  static final _nicknameRe = RegExp(
    r'^[A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі0-9 _.\-]+$',
  );

  @override
  void initState() {
    super.initState();
    _loginCtrl.addListener(_handleLoginChanged);
  }

  @override
  void dispose() {
    _loginCtrl.removeListener(_handleLoginChanged);
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  bool get _loginValid {
    try {
      UsernameAuthMapper.normalizeLogin(_loginCtrl.text);
      return true;
    } on FormatException {
      return false;
    }
  }

  bool get _loginLooksLikeEmail => _loginCtrl.text.trim().contains('@');

  String? _loginValidationError(AppStrings s, {required bool showEmpty}) {
    if (_loginLooksLikeEmail) return s.authLoginEmailInvalid;
    if (_loginCtrl.text.trim().isEmpty && !showEmpty) return null;
    return _loginValid ? null : s.authLoginInvalid;
  }

  bool get _passwordValid => _passwordCtrl.text.length >= 6;

  bool get _isLoading => _loadingTarget != null;
  bool get _isPasswordLoading => _loadingTarget == _AuthLoadingTarget.password;
  bool get _isGoogleLoading => _loadingTarget == _AuthLoadingTarget.google;

  bool get _nicknameValid {
    final nickname = _nicknameCtrl.text.trim();
    return nickname.length >= 2 &&
        nickname.length <= 32 &&
        _nicknameRe.hasMatch(nickname);
  }

  bool get _codeValid => _codeCtrl.text.trim().isNotEmpty;

  bool get _formValid {
    if (!_loginValid || !_passwordValid) return false;
    if (!_registerMode) return true;
    return _nicknameValid && _codeValid;
  }

  void _syncValidation() {
    _loginError = _loginValidationError(S.of(context), showEmpty: false);
    if (_passwordError != null && _passwordValid) _passwordError = null;
    if (_nicknameError != null && _nicknameValid) _nicknameError = null;
    if (_codeError != null && _codeValid) _codeError = null;
  }

  void _handleLoginChanged() {
    if (!mounted) return;
    setState(() {
      _loginError = _loginValidationError(S.of(context), showEmpty: false);
    });
  }

  Future<void> _rollbackFailedUsernameRegistration(bool authWasCreated) async {
    if (!_registerMode || !authWasCreated) return;
    try {
      await (widget.rollbackFailedRegistration ??
          Supabase.instance.client.auth.signOut)();
    } catch (_) {
      // The visible validation error is more useful than a secondary sign-out
      // failure. AuthGate will recover on the next auth/profile refresh.
    }
  }

  Future<void> _submitUsernamePassword() async {
    final s = S.of(context);
    setState(() {
      _syncValidation();
      _loginError = _loginValidationError(s, showEmpty: true);
      _passwordError = _passwordValid ? null : s.authPasswordInvalid;
      if (_registerMode) {
        _nicknameError = _nicknameValid ? null : s.errorNicknameInvalid;
        _codeError = _codeValid ? null : s.errorInviteInvalid;
      }
    });

    if (!_formValid || _isLoading) return;

    setState(() => _loadingTarget = _AuthLoadingTarget.password);
    var authWasCreated = false;
    try {
      final authEmail = UsernameAuthMapper.toAuthEmail(_loginCtrl.text);
      if (_registerMode) {
        widget.onUsernameRegistrationStarted?.call();
        final nickname = _nicknameCtrl.text.trim();
        final code = _codeCtrl.text.trim().toUpperCase();
        final repo = ProfileRepository(Supabase.instance.client);
        final injectedPreflight = widget.preflightRegistration;
        if (injectedPreflight != null) {
          await injectedPreflight(nickname, code);
        } else if (widget.registerWithPassword == null) {
          await repo.preflightRegistration(nickname: nickname, code: code);
        }

        final injectedRegistration = widget.registerWithPassword;
        if (injectedRegistration != null) {
          authWasCreated = true;
          await injectedRegistration(
            _loginCtrl.text,
            _passwordCtrl.text,
            nickname,
            code,
          );
        } else {
          await Supabase.instance.client.auth.signUp(
            email: authEmail,
            password: _passwordCtrl.text,
            data: {'login': UsernameAuthMapper.normalizeLogin(_loginCtrl.text)},
          );
          authWasCreated = true;

          if (Supabase.instance.client.auth.currentSession == null) {
            throw AuthException(s.authRegistrationNeedsSession);
          }

          await repo.registerWithInvite(
            nickname: nickname,
            code: code,
          );
        }
        widget.onUsernameRegistrationCompleted?.call();
      } else {
        final injectedSignIn = widget.signInWithPassword;
        if (injectedSignIn != null) {
          await injectedSignIn(_loginCtrl.text, _passwordCtrl.text);
        } else {
          await Supabase.instance.client.auth.signInWithPassword(
            email: authEmail,
            password: _passwordCtrl.text,
          );
        }
      }
    } on RegistrationException catch (e) {
      await _rollbackFailedUsernameRegistration(authWasCreated);
      if (!mounted) return;
      setState(() {
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
            _codeError = '${s.error}: ${e.reason}';
        }
      });
    } on AuthException catch (e) {
      await _rollbackFailedUsernameRegistration(authWasCreated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authErrorMessage(S.of(context), e.message)),
          duration: const Duration(seconds: 5),
        ),
      );
    } on FormatException catch (_) {
      if (!mounted) return;
      setState(() => _loginError = s.authLoginInvalid);
    } catch (e) {
      await _rollbackFailedUsernameRegistration(authWasCreated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${s.error}: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (_registerMode) {
        widget.onUsernameRegistrationFinished?.call();
      }
      if (mounted) setState(() => _loadingTarget = null);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loadingTarget = _AuthLoadingTarget.google);
    try {
      await GoogleSignInService.ensureInitialized();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final auth = googleUser.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('ID token missing');
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        nonce: AppConfig.googleSignInRawNonce,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        setState(() => _loadingTarget = null);
        return;
      }
      if (!mounted) return;
      final s = S.of(context);
      switch (googleAuthErrorActionFor(e)) {
        case GoogleAuthErrorAction.cancel:
          return;
        case GoogleAuthErrorAction.browserOAuthFallback:
          await _signInWithGoogleOAuth();
          return;
        case GoogleAuthErrorAction.showError:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${s.error}: ${e.description ?? e.code.name}'),
              duration: const Duration(seconds: 5),
            ),
          );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _showGoogleAuthError(e.message, e.statusCode);
    } catch (e) {
      if (!mounted) return;
      _showGoogleAuthError(e.toString(), null);
    } finally {
      if (mounted) setState(() => _loadingTarget = null);
    }
  }

  void _showGoogleAuthError(String message, String? statusCode) {
    final isNotRegistered = message.contains('Database error saving new user') ||
        message.contains('unexpected_failure') ||
        statusCode == '422';
    final s = S.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isNotRegistered ? s.notRegistered : message),
        backgroundColor: isNotRegistered ? const Color(0xFFDC2626) : null,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _signInWithGoogleOAuth() {
    return Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.supabaseOAuthRedirectUrl,
      queryParams: const {'prompt': 'select_account'},
    );
  }

  void _toggleMode() {
    setState(() {
      _registerMode = !_registerMode;
      _loginError = null;
      _passwordError = null;
      _nicknameError = null;
      _codeError = null;
    });
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
                    _BrandHeader(subtitle: s.appSubtitle, title: s.appTitle),
                    const SizedBox(height: 24),
                    _AuthPanel(
                      registerMode: _registerMode,
                      loading: _isLoading,
                      passwordLoading: _isPasswordLoading,
                      formValid: _formValid,
                      loginController: _loginCtrl,
                      passwordController: _passwordCtrl,
                      nicknameController: _nicknameCtrl,
                      codeController: _codeCtrl,
                      loginError: _loginError,
                      passwordError: _passwordError,
                      nicknameError: _nicknameError,
                      codeError: _codeError,
                      passwordVisible: _passwordVisible,
                      onChanged: () => setState(_syncValidation),
                      onTogglePassword: () =>
                          setState(() => _passwordVisible = !_passwordVisible),
                      onSubmit: _submitUsernamePassword,
                      onToggleMode: _toggleMode,
                    ),
                    const SizedBox(height: 16),
                    _DividerLabel(text: s.authOr),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('auth-google-button'),
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        icon: _isGoogleLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFE8F3EE),
                                ),
                              )
                            : const _GoogleIcon(),
                        label: Text(
                          _isGoogleLoading ? s.signingIn : s.signInGoogle,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE8F3EE),
                          side: const BorderSide(color: Color(0x334ADE80)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
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

class _BrandHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _BrandHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
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
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFB8C7C1), fontSize: 14),
        ),
      ],
    );
  }
}

class _AuthPanel extends StatelessWidget {
  final bool registerMode;
  final bool loading;
  final bool passwordLoading;
  final bool formValid;
  final bool passwordVisible;
  final TextEditingController loginController;
  final TextEditingController passwordController;
  final TextEditingController nicknameController;
  final TextEditingController codeController;
  final String? loginError;
  final String? passwordError;
  final String? nicknameError;
  final String? codeError;
  final VoidCallback onChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;

  const _AuthPanel({
    required this.registerMode,
    required this.loading,
    required this.passwordLoading,
    required this.formValid,
    required this.passwordVisible,
    required this.loginController,
    required this.passwordController,
    required this.nicknameController,
    required this.codeController,
    required this.loginError,
    required this.passwordError,
    required this.nicknameError,
    required this.codeError,
    required this.onChanged,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onToggleMode,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  registerMode ? s.authCreateAccount : s.authWelcomeBack,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('auth-mode-toggle'),
                onPressed: loading ? null : onToggleMode,
                child: Text(
                  registerMode ? s.authHaveAccount : s.authNeedAccount,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AuthField(
            key: const ValueKey('auth-login-field'),
            controller: loginController,
            label: s.authLoginLabel,
            hint: s.authLoginHint,
            icon: Icons.alternate_email_rounded,
            errorText: loginError,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          _AuthField(
            key: const ValueKey('auth-password-field'),
            controller: passwordController,
            label: s.authPasswordLabel,
            hint: s.authPasswordHint,
            icon: Icons.lock_outline_rounded,
            errorText: passwordError,
            obscureText: !passwordVisible,
            suffixIcon: IconButton(
              onPressed: onTogglePassword,
              icon: Icon(
                passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onSubmit(),
          ),
          if (registerMode) ...[
            const SizedBox(height: 12),
            _AuthField(
              key: const ValueKey('auth-nickname-field'),
              controller: nicknameController,
              label: s.nicknameLabel,
              hint: s.nicknameHint,
              icon: Icons.badge_outlined,
              errorText: nicknameError,
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 12),
            _AuthField(
              key: const ValueKey('auth-code-field'),
              controller: codeController,
              label: s.inviteCodeLabel,
              hint: s.inviteCodeShortHint,
              icon: Icons.key_rounded,
              errorText: codeError,
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
          ],
          const SizedBox(height: 18),
          ElevatedButton(
            key: const ValueKey('auth-submit-button'),
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
            child: passwordLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF062014),
                    ),
                  )
                : Text(
                    registerMode ? s.submitRegistration : s.authSignIn,
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

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? errorText;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  const _AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.errorText,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        color: Color(0xFFF8FAFC),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: Icon(icon, color: const Color(0xFF8DB9A5)),
        suffixIcon: suffixIcon,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  final String text;

  const _DividerLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0x334ADE80))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF789085), fontSize: 12),
          ),
        ),
        const Expanded(child: Divider(color: Color(0x334ADE80))),
      ],
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.13;

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), -2.36, 1.57, false, paint);

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), -0.79, 1.57, false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), 0.79, 1.57, false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), 2.36, 1.57, false, paint);
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}
