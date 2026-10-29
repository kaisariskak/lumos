import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/services/auth_logout_service.dart';

void main() {
  test(
    'signs out after local cleanup from Supabase and Google provider',
    () async {
      final calls = <String>[];

      await AuthLogoutService.signOut(
        localCleanup: () async => calls.add('cleanup'),
        supabaseSignOut: () async => calls.add('supabase'),
        googleSignOut: () async => calls.add('google'),
      );

      expect(calls, ['cleanup', 'supabase', 'google']);
    },
  );

  test('clearLocalAccountState clears pin and startup cache', () async {
    final calls = <String>[];

    await AuthLogoutService.clearLocalAccountState(
      clearPin: () async => calls.add('clearPin'),
      clearStartupCache: () async => calls.add('clearStartupCache'),
    );

    expect(calls, ['clearPin', 'clearStartupCache']);
  });

  test('finishDeletedAccountSession ignores provider failures', () async {
    final calls = <String>[];

    await AuthLogoutService.finishDeletedAccountSession(
      localCleanup: () async => calls.add('cleanup'),
      supabaseSignOut: () async {
        throw Exception('supabase failed');
      },
      googleSignOut: () async => calls.add('google'),
    );

    expect(calls, ['cleanup', 'google']);
  });
}
