import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_logout_service.dart';

enum AccountDeletionStatus {
  deleted,
  noSession,
  superAdminForbidden,
  groupOwnershipBlocked,
  retryableFailure,
  unknownFailure,
}

class AccountDeletionResult {
  final AccountDeletionStatus status;
  final bool appleRevoked;
  final bool showAppleManualRevokeNote;

  const AccountDeletionResult({
    required this.status,
    this.appleRevoked = false,
    this.showAppleManualRevokeNote = false,
  });
}

class AccountDeletionFunctionResponse {
  final int status;
  final Map<String, dynamic>? body;

  const AccountDeletionFunctionResponse({
    required this.status,
    required this.body,
  });
}

typedef AccountDeletionTokenReader = String? Function();
typedef AccountDeletionProviderReader = String? Function();
typedef AccountDeletionFunctionInvoker =
    Future<AccountDeletionFunctionResponse> Function({
      required String accessToken,
    });
typedef AccountDeletionCleanup = Future<void> Function();

class AccountDeletionService {
  final AccountDeletionTokenReader _currentAccessToken;
  final AccountDeletionProviderReader _currentProvider;
  final AccountDeletionFunctionInvoker _invokeDeleteAccount;
  final AccountDeletionCleanup _localCleanup;

  AccountDeletionService({
    AccountDeletionTokenReader? currentAccessToken,
    AccountDeletionProviderReader? currentProvider,
    AccountDeletionFunctionInvoker? invokeDeleteAccount,
    AccountDeletionCleanup? localCleanup,
  }) : _currentAccessToken =
           currentAccessToken ??
           (() => Supabase.instance.client.auth.currentSession?.accessToken),
       _currentProvider =
           currentProvider ??
           (() {
             final provider = Supabase
                 .instance
                 .client
                 .auth
                 .currentUser
                 ?.appMetadata['provider'];
             return provider is String ? provider : null;
           }),
       _invokeDeleteAccount = invokeDeleteAccount ?? _invokeSupabaseFunction,
       _localCleanup =
           localCleanup ?? AuthLogoutService.finishDeletedAccountSession;

  Future<AccountDeletionResult> deleteAccount() async {
    final accessToken = _currentAccessToken();
    final isAppleProvider = _currentProvider() == 'apple';
    if (accessToken == null || accessToken.isEmpty) {
      return const AccountDeletionResult(
        status: AccountDeletionStatus.noSession,
      );
    }

    final AccountDeletionFunctionResponse response;
    try {
      response = await _invokeDeleteAccount(accessToken: accessToken);
    } catch (error) {
      if (error is FunctionException) {
        return AccountDeletionResult(
          status: _statusForFunctionException(error),
        );
      }
      return const AccountDeletionResult(
        status: AccountDeletionStatus.retryableFailure,
      );
    }

    final body = response.body;
    if (body?['ok'] == true) {
      return AccountDeletionResult(
        status: AccountDeletionStatus.deleted,
        appleRevoked: body?['appleRevoked'] == true,
        showAppleManualRevokeNote:
            isAppleProvider && body?['appleRevoked'] != true,
      );
    }

    return AccountDeletionResult(
      status: _statusForCode(body?['code'] as String?),
    );
  }

  static AccountDeletionStatus _statusForCode(String? code) {
    return switch (code) {
      'no_session' => AccountDeletionStatus.noSession,
      'super_admin_forbidden' => AccountDeletionStatus.superAdminForbidden,
      'group_ownership_blocked' => AccountDeletionStatus.groupOwnershipBlocked,
      'function_unavailable' => AccountDeletionStatus.retryableFailure,
      _ => AccountDeletionStatus.unknownFailure,
    };
  }

  static AccountDeletionStatus _statusForFunctionException(
    FunctionException error,
  ) {
    final details = error.details;
    if (details is Map<String, dynamic>) {
      return _statusForCode(details['code'] as String?);
    }
    return AccountDeletionStatus.retryableFailure;
  }

  static Future<AccountDeletionFunctionResponse> _invokeSupabaseFunction({
    required String accessToken,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'delete-account',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final data = response.data;
    return AccountDeletionFunctionResponse(
      status: response.status,
      body: data is Map<String, dynamic> ? data : null,
    );
  }

  Future<void> finishDeletedAccountSession() => _localCleanup();
}
