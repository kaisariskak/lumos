import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';

class GoogleSignInService {
  GoogleSignInService._();

  static Future<void>? _initialization;

  static Future<void> ensureInitialized() {
    final initialization = _initialization;
    if (initialization != null) {
      return initialization;
    }

    final nextInitialization = _initializeWithReset();
    _initialization = nextInitialization;
    return nextInitialization;
  }

  static Future<void> _initializeWithReset() async {
    try {
      await _initialize();
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  static Future<void> _initialize() async {
    final rawNonce = _generateNonce();
    AppConfig.googleSignInRawNonce = rawNonce;
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleWebClientId,
      nonce: hashedNonce,
    );
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}
