import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/services/auth_logout_service.dart';

void main() {
  test('signs out from Supabase and Google provider', () async {
    final calls = <String>[];

    await AuthLogoutService.signOut(
      supabaseSignOut: () async => calls.add('supabase'),
      googleSignOut: () async => calls.add('google'),
    );

    expect(calls, ['supabase', 'google']);
  });
}
