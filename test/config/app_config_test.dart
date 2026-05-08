import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/config/app_config.dart';

void main() {
  test('Supabase OAuth redirect URL matches dashboard allowlist', () {
    expect(
      AppConfig.supabaseOAuthRedirectUrl,
      'io.supabase.flutterquickstart://login-callback/',
    );
  });
}
