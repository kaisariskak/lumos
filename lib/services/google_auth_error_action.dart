import 'package:google_sign_in/google_sign_in.dart';

enum GoogleAuthErrorAction { cancel, browserOAuthFallback, showError }

GoogleAuthErrorAction googleAuthErrorActionFor(GoogleSignInException error) {
  if (error.code == GoogleSignInExceptionCode.canceled) {
    return GoogleAuthErrorAction.cancel;
  }

  final description = (error.description ?? '').toLowerCase();
  final isCredentialManagerNoCredential =
      description.contains('no credential') ||
      description.contains('no provider') ||
      description.contains('getcredentialasync');

  if (isCredentialManagerNoCredential) {
    return GoogleAuthErrorAction.browserOAuthFallback;
  }

  return GoogleAuthErrorAction.showError;
}
