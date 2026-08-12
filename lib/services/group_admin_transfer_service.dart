typedef AsyncAction = Future<void> Function();
typedef AsyncCheck = Future<bool> Function();

class GroupAdminTransferResult {
  final bool newAdminWasPromoted;
  final bool previousAdminWasDemoted;

  const GroupAdminTransferResult({
    required this.newAdminWasPromoted,
    required this.previousAdminWasDemoted,
  });
}

Future<GroupAdminTransferResult> transferGroupAdmin({
  required String groupId,
  required String previousAdminId,
  required String newAdminId,
  required bool newAdminAlreadyHasRole,
  required AsyncAction promoteNewAdmin,
  required AsyncAction transferOwnership,
  required AsyncCheck previousAdminHasOtherGroups,
  required AsyncAction demotePreviousAdmin,
}) async {
  if (groupId.isEmpty || previousAdminId.isEmpty || newAdminId.isEmpty) {
    throw ArgumentError('Group and admin IDs must not be empty.');
  }
  if (previousAdminId == newAdminId) {
    throw ArgumentError('The new admin must differ from the previous admin.');
  }

  var newAdminWasPromoted = false;
  if (!newAdminAlreadyHasRole) {
    await promoteNewAdmin();
    newAdminWasPromoted = true;
  }

  // The current owner must retain their permissions until this update succeeds.
  await transferOwnership();

  final keepPreviousAdminRole = await previousAdminHasOtherGroups();
  if (!keepPreviousAdminRole) {
    await demotePreviousAdmin();
  }

  return GroupAdminTransferResult(
    newAdminWasPromoted: newAdminWasPromoted,
    previousAdminWasDemoted: !keepPreviousAdminRole,
  );
}
