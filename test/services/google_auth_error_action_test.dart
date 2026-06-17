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

    test('uses browser fallback for Android developer configuration errors', () {
      const exception = GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description:
            'com.google.android.gms.common.api.ApiException: 10: DEVELOPER_ERROR',
      );

      expect(
        googleAuthErrorActionFor(exception),
        GoogleAuthErrorAction.browserOAuthFallback,
      );
    });

    test('uses browser fallback for Google provider configuration errors', () {
      const exception = GoogleSignInException(
        code: GoogleSignInExceptionCode.providerConfigurationError,
        description: 'The underlying auth SDK is unavailable or misconfigured',
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
