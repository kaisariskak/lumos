import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../l10n/app_strings.dart';

class IbadatAuthorization extends StatefulWidget {
  const IbadatAuthorization({super.key});

  @override
  State<IbadatAuthorization> createState() => _IbadatAuthorizationState();
}

class _IbadatAuthorizationState extends State<IbadatAuthorization> {
  bool _isLoading = false;

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      await GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleWebClientId,
        nonce: hashedNonce,
      );
      await GoogleSignIn.instance.signOut();
      final googleUser = await GoogleSignIn.instance.authenticate().timeout(
        const Duration(seconds: 60),
      );
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) throw Exception('ID token жоқ');
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        nonce: rawNonce,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final isNotRegistered = e.message.contains('Database error saving new user') ||
          e.message.contains('unexpected_failure') ||
          e.statusCode == '422';
      final s = S.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNotRegistered ? s.notRegistered : e.message),
          backgroundColor: isNotRegistered ? const Color(0xFFDC2626) : null,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final isNotRegistered = msg.contains('Database error saving new user') ||
          msg.contains('unexpected_failure');
      final s = S.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNotRegistered ? s.notRegistered : '${s.error}: $e'),
          backgroundColor: isNotRegistered ? const Color(0xFFDC2626) : null,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glow ambient
                  const _AmbientGlow(),

                  // App icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x664F46E5),
                          blurRadius: 32,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('📖', style: TextStyle(fontSize: 48)),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Title
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFE2E8F0), Color(0xFFA5B4FC)],
                    ).createShader(bounds),
                    child: Text(
                      s.appTitle,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.appSubtitle,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Google Sign-In button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black54,
                              ),
                            )
                          : const _GoogleIcon(),
                      label: Text(
                        _isLoading ? s.signingIn : s.signInGoogle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1F2937),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        shadowColor: Colors.black26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    s.noPassword,
                    style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
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
    // Simplified Google 'G' logo approximation using colored arcs
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = s * 0.13;

    // Red arc (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), -2.36, 1.57, false, paint);

    // Blue arc (right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), -0.79, 1.57, false, paint);

    // Yellow arc (bottom)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), 0.79, 1.57, false, paint);

    // Green arc (left)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), 2.36, 1.57, false, paint);
  }

  @override
  bool shouldRepaint(_GooglePainter old) => false;
}
