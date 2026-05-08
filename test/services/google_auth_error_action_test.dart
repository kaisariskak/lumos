import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:reportdeepen/services/google_auth_error_action.dart';

void main() {
  group('googleAuthErrorActionFor', () {
    test('uses browser fallback when Credential Manager has no credential', () {
      const exception = GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'No credential available: getCredentialAsync failed',
      );

      expect(
        googleAuthErrorActionFor(exception),
        GoogleAuthErrorAction.browserOAuthFallback,
      );
    });

    test('treats user cancel as cancel', () {
      const exception = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      expect(googleAuthErrorActionFor(exception), GoogleAuthErrorAction.cancel);
    });
  });
}
