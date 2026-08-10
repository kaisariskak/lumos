import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pin_service.dart';

typedef AsyncLogoutStep = Future<void> Function();

class AuthLogoutService {
  AuthLogoutService._();

  static Future<void> signOut({
    AsyncLogoutStep? supabaseSignOut,
    AsyncLogoutStep? googleSignOut,
    AsyncLogoutStep? localCleanup,
  }) async {
    await (localCleanup ?? clearLocalAccountState)();
    await (supabaseSignOut ?? Supabase.instance.client.auth.signOut)();
    await (googleSignOut ?? GoogleSignIn.instance.signOut)();
  }

  static Future<void> finishDeletedAccountSession({
    AsyncLogoutStep? localCleanup,
    AsyncLogoutStep? supabaseSignOut,
    AsyncLogoutStep? googleSignOut,
  }) async {
    await (localCleanup ?? clearLocalAccountState)();
    await _ignoreFailure(
      supabaseSignOut ?? Supabase.instance.client.auth.signOut,
    );
    await _ignoreFailure(googleSignOut ?? GoogleSignIn.instance.signOut);
  }

  static Future<void> clearLocalAccountState({
    AsyncLogoutStep? clearPin,
  }) async {
    await (clearPin ?? PinService.clearPin)();
  }

  static Future<void> _ignoreFailure(AsyncLogoutStep step) async {
    try {
      await step();
    } catch (_) {
      // Account deletion already happened on the server; local navigation must continue.
    }
  }
}
