import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/authentication/auth_profile_wait.dart';

void main() {
  group('AuthProfileWait', () {
    test('waits for profile when user was created with login metadata', () {
      expect(
        AuthProfileWait.shouldWaitForUsernameProfile({'login': 'kaizer'}),
        isTrue,
      );
    });

    test('does not wait for Google users without login metadata', () {
      expect(
        AuthProfileWait.shouldWaitForUsernameProfile({'provider': 'google'}),
        isFalse,
      );
      expect(AuthProfileWait.shouldWaitForUsernameProfile(null), isFalse);
    });
  });
}
