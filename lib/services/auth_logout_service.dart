import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AsyncLogoutStep = Future<void> Function();

class AuthLogoutService {
  AuthLogoutService._();

  static Future<void> signOut({
    AsyncLogoutStep? supabaseSignOut,
    AsyncLogoutStep? googleSignOut,
  }) async {
    await (supabaseSignOut ?? Supabase.instance.client.auth.signOut)();
    await (googleSignOut ?? GoogleSignIn.instance.signOut)();
  }
}
