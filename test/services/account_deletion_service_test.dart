import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/services/account_deletion_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AccountDeletionService', () {
    test(
          'success response returns deleted with appleRevoked false without immediate cleanup',
      () async {
        final calls = <String>[];
        final service = AccountDeletionService(
          currentAccessToken: () {
            calls.add('accessToken');
            return 'jwt-1';
          },
          invokeDeleteAccount: ({required accessToken}) async {
            calls.add('invoke:$accessToken');
            return const AccountDeletionFunctionResponse(
              status: 200,
              body: {'ok': true, 'appleRevoked': false},
            );
          },
          localCleanup: () async {
            calls.add('cleanup');
          },
        );

        final result = await service.deleteAccount();

        expect(result.status, AccountDeletionStatus.deleted);
        expect(result.appleRevoked, isFalse);
        expect(result.showAppleManualRevokeNote, isFalse);
        expect(calls, ['accessToken', 'invoke:jwt-1']);

        await service.finishDeletedAccountSession();

        expect(calls, ['accessToken', 'invoke:jwt-1', 'cleanup']);
      },
    );

    test('Apple provider success requests manual revoke note', () async {
      final service = AccountDeletionService(
        currentAccessToken: () => 'jwt-1',
        currentProvider: () => 'apple',
        invokeDeleteAccount: ({required accessToken}) async {
          return const AccountDeletionFunctionResponse(
            status: 200,
            body: {'ok': true, 'appleRevoked': false},
          );
        },
        localCleanup: () async {},
      );

      final result = await service.deleteAccount();

      expect(result.status, AccountDeletionStatus.deleted);
      expect(result.showAppleManualRevokeNote, isTrue);
    });

    test('Google provider success does not request manual Apple note', () async {
      final service = AccountDeletionService(
        currentAccessToken: () => 'jwt-1',
        currentProvider: () => 'google',
        invokeDeleteAccount: ({required accessToken}) async {
          return const AccountDeletionFunctionResponse(
            status: 200,
            body: {'ok': true, 'appleRevoked': false},
          );
        },
        localCleanup: () async {},
      );

      final result = await service.deleteAccount();

      expect(result.status, AccountDeletionStatus.deleted);
      expect(result.showAppleManualRevokeNote, isFalse);
    });

    test('no session returns noSession and does not call function', () async {
      final calls = <String>[];
      final service = AccountDeletionService(
        currentAccessToken: () {
          calls.add('accessToken');
          return null;
        },
        invokeDeleteAccount: ({required accessToken}) async {
          calls.add('invoke:$accessToken');
          return const AccountDeletionFunctionResponse(
            status: 200,
            body: {'ok': true, 'appleRevoked': false},
          );
        },
        localCleanup: () async {
          calls.add('cleanup');
        },
      );

      final result = await service.deleteAccount();

      expect(result.status, AccountDeletionStatus.noSession);
      expect(result.appleRevoked, isFalse);
      expect(calls, ['accessToken']);
    });

    test(
      'super admin forbidden response maps status and does not cleanup',
      () async {
        final calls = <String>[];
        final service = AccountDeletionService(
          currentAccessToken: () {
            calls.add('accessToken');
            return 'jwt-1';
          },
          invokeDeleteAccount: ({required accessToken}) async {
            calls.add('invoke:$accessToken');
            return const AccountDeletionFunctionResponse(
              status: 403,
              body: {'ok': false, 'code': 'super_admin_forbidden'},
            );
          },
          localCleanup: () async {
            calls.add('cleanup');
          },
        );

        final result = await service.deleteAccount();

        expect(result.status, AccountDeletionStatus.superAdminForbidden);
        expect(result.appleRevoked, isFalse);
        expect(calls, ['accessToken', 'invoke:jwt-1']);
      },
    );

    test(
      'group ownership blocked response maps status and does not cleanup',
      () async {
        final calls = <String>[];
        final service = AccountDeletionService(
          currentAccessToken: () {
            calls.add('accessToken');
            return 'jwt-1';
          },
          invokeDeleteAccount: ({required accessToken}) async {
            calls.add('invoke:$accessToken');
            return const AccountDeletionFunctionResponse(
              status: 409,
              body: {'ok': false, 'code': 'group_ownership_blocked'},
            );
          },
          localCleanup: () async {
            calls.add('cleanup');
          },
        );

        final result = await service.deleteAccount();

        expect(result.status, AccountDeletionStatus.groupOwnershipBlocked);
        expect(result.appleRevoked, isFalse);
        expect(calls, ['accessToken', 'invoke:jwt-1']);
      },
    );

    test(
      'thrown super admin FunctionException maps status and does not cleanup',
      () async {
        final calls = <String>[];
        final service = AccountDeletionService(
          currentAccessToken: () {
            calls.add('accessToken');
            return 'jwt-1';
          },
          invokeDeleteAccount: ({required accessToken}) async {
            calls.add('invoke:$accessToken');
            throw const FunctionException(
              status: 403,
              details: {'ok': false, 'code': 'super_admin_forbidden'},
            );
          },
          localCleanup: () async {
            calls.add('cleanup');
          },
        );

        final result = await service.deleteAccount();

        expect(result.status, AccountDeletionStatus.superAdminForbidden);
        expect(result.appleRevoked, isFalse);
        expect(calls, ['accessToken', 'invoke:jwt-1']);
      },
    );

    test(
      'thrown group ownership FunctionException maps status and does not cleanup',
      () async {
        final calls = <String>[];
        final service = AccountDeletionService(
          currentAccessToken: () {
            calls.add('accessToken');
            return 'jwt-1';
          },
          invokeDeleteAccount: ({required accessToken}) async {
            calls.add('invoke:$accessToken');
            throw const FunctionException(
              status: 409,
              details: {'ok': false, 'code': 'group_ownership_blocked'},
            );
          },
          localCleanup: () async {
            calls.add('cleanup');
          },
        );

        final result = await service.deleteAccount();

        expect(result.status, AccountDeletionStatus.groupOwnershipBlocked);
        expect(result.appleRevoked, isFalse);
        expect(calls, ['accessToken', 'invoke:jwt-1']);
      },
    );

    test('thrown invoke failure maps retryableFailure and does not cleanup', () async {
      final calls = <String>[];
      final service = AccountDeletionService(
        currentAccessToken: () {
          calls.add('accessToken');
          return 'jwt-1';
        },
        invokeDeleteAccount: ({required accessToken}) async {
          calls.add('invoke:$accessToken');
          throw Exception('network failed');
        },
        localCleanup: () async {
          calls.add('cleanup');
        },
      );

      final result = await service.deleteAccount();

      expect(result.status, AccountDeletionStatus.retryableFailure);
      expect(result.appleRevoked, isFalse);
      expect(calls, ['accessToken', 'invoke:jwt-1']);
    });
  });
}
