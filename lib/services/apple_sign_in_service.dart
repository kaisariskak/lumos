import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

enum AppleSignInFlow { nativeIdToken, browserOAuth, unsupported }

enum AppleAuthErrorAction { cancel, showError }

class AppleSignInCanceled implements Exception {
  const AppleSignInCanceled();
}

AppleSignInFlow appleSignInFlowFor(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.iOS => AppleSignInFlow.nativeIdToken,
    TargetPlatform.android => AppleSignInFlow.browserOAuth,
    _ => AppleSignInFlow.unsupported,
  };
}

AppleAuthErrorAction appleAuthErrorActionFor(AuthorizationErrorCode code) {
  return code == AuthorizationErrorCode.canceled
      ? AppleAuthErrorAction.cancel
      : AppleAuthErrorAction.showError;
}

class AppleSignInService {
  final SupabaseClient _client;

  AppleSignInService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<void> signIn(TargetPlatform platform) async {
    switch (appleSignInFlowFor(platform)) {
      case AppleSignInFlow.nativeIdToken:
        await _signInNatively();
        return;
      case AppleSignInFlow.browserOAuth:
        await _client.auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: AppConfig.supabaseOAuthRedirectUrl,
        );
        return;
      case AppleSignInFlow.unsupported:
        throw UnsupportedError(
          'Apple Sign-In is supported only on iOS and Android.',
        );
    }
  }

  Future<void> _signInNatively() async {
    final rawNonce = _client.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException('Apple identity token is missing.');
      }
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (appleAuthErrorActionFor(error.code) == AppleAuthErrorAction.cancel) {
        throw const AppleSignInCanceled();
      }
      rethrow;
    }
  }
}
