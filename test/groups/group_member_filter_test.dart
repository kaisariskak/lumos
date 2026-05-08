import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/groups/group_member_filter.dart';
import 'package:reportdeepen/models/ibadat_profile.dart';

void main() {
  test('excludes the group admin from visible members', () {
    final members = [
      _profile(id: 'admin', nickname: 'Admin'),
      _profile(id: 'user', nickname: 'User'),
    ];

    final visible = visibleGroupMembers(members, adminId: 'admin');

    expect(visible.map((member) => member.id), ['user']);
  });
}

IbadatProfile _profile({required String id, required String nickname}) {
  return IbadatProfile(
    id: id,
    userId: id,
    nickname: nickname,
    email: '$id@example.com',
    role: 'user',
    currentGroupId: 'group',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}
