import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/services/apple_sign_in_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  test('iOS uses native Apple ID-token flow', () {
    expect(
      appleSignInFlowFor(TargetPlatform.iOS),
      AppleSignInFlow.nativeIdToken,
    );
  });

  test('Android uses browser OAuth flow', () {
    expect(
      appleSignInFlowFor(TargetPlatform.android),
      AppleSignInFlow.browserOAuth,
    );
  });

  test('unsupported platforms do not start Apple authentication', () {
    for (final platform in [
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.fuchsia,
    ]) {
      expect(appleSignInFlowFor(platform), AppleSignInFlow.unsupported);
    }
  });

  test('canceled Apple authorization is handled silently', () {
    expect(
      appleAuthErrorActionFor(AuthorizationErrorCode.canceled),
      AppleAuthErrorAction.cancel,
    );
    expect(
      appleAuthErrorActionFor(AuthorizationErrorCode.failed),
      AppleAuthErrorAction.showError,
    );
  });
}
