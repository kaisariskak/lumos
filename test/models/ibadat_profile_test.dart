import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/models/ibadat_profile.dart';

void main() {
  test('parses nickname and ignores absent email/avatar_url', () {
    final profile = IbadatProfile.fromJson({
      'id': 'user-1',
      'nickname': 'kaisar',
      'role': 'user',
      'current_group_id': 'group-1',
      'super_admin_id': null,
      'created_by_admin_id': 'admin-1',
      'created_at': '2026-04-30T10:00:00.000Z',
      'updated_at': '2026-04-30T10:00:00.000Z',
    });

    expect(profile.id, 'user-1');
    expect(profile.nickname, 'kaisar');
    expect(profile.currentGroupId, 'group-1');
    expect(profile.role, 'user');
  });

  test('toJson emits nickname and no email/avatar_url', () {
    final profile = IbadatProfile(
      id: 'user-1',
      nickname: 'kaisar',
      role: 'user',
      currentGroupId: 'group-1',
      createdAt: DateTime.parse('2026-04-30T10:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-30T10:00:00.000Z'),
    );

    final json = profile.toJson();
    expect(json['nickname'], 'kaisar');
    expect(json.containsKey('email'), isFalse);
    expect(json.containsKey('avatar_url'), isFalse);
    expect(json.containsKey('display_name'), isFalse);
  });

  test('copyWith updates nickname and bumps updatedAt', () async {
    final original = IbadatProfile(
      id: 'user-1',
      nickname: 'old',
      role: 'user',
      createdAt: DateTime.parse('2026-04-30T10:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-30T10:00:00.000Z'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1));

    final updated = original.copyWith(nickname: 'new');
    expect(updated.nickname, 'new');
    expect(updated.id, original.id);
    expect(updated.updatedAt.isAfter(original.updatedAt), isTrue);
  });
}
