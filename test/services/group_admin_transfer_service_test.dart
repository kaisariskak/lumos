import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/services/group_admin_transfer_service.dart';

void main() {
  test(
    'transfers group ownership before demoting the previous admin',
    () async {
      final calls = <String>[];

      final result = await transferGroupAdmin(
        groupId: 'group-1',
        previousAdminId: 'old-admin',
        newAdminId: 'new-admin',
        newAdminAlreadyHasRole: false,
        promoteNewAdmin: () async => calls.add('promote-new'),
        transferOwnership: () async => calls.add('transfer-group'),
        previousAdminHasOtherGroups: () async => false,
        demotePreviousAdmin: () async => calls.add('demote-old'),
      );

      expect(calls, ['promote-new', 'transfer-group', 'demote-old']);
      expect(result.newAdminWasPromoted, isTrue);
      expect(result.previousAdminWasDemoted, isTrue);
    },
  );

  test('keeps previous admin role when they own another group', () async {
    final calls = <String>[];

    final result = await transferGroupAdmin(
      groupId: 'group-1',
      previousAdminId: 'old-admin',
      newAdminId: 'new-admin',
      newAdminAlreadyHasRole: true,
      promoteNewAdmin: () async => calls.add('promote-new'),
      transferOwnership: () async => calls.add('transfer-group'),
      previousAdminHasOtherGroups: () async => true,
      demotePreviousAdmin: () async => calls.add('demote-old'),
    );

    expect(calls, ['transfer-group']);
    expect(result.newAdminWasPromoted, isFalse);
    expect(result.previousAdminWasDemoted, isFalse);
  });
}
