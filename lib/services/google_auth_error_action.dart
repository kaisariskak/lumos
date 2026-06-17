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
  final isNativeProviderMisconfigured =
      error.code == GoogleSignInExceptionCode.providerConfigurationError ||
      description.contains('developer_error') ||
      description.contains('apiexception: 10');

  if (isCredentialManagerNoCredential || isNativeProviderMisconfigured) {
    return GoogleAuthErrorAction.browserOAuthFallback;
  }

  return GoogleAuthErrorAction.showError;
}
