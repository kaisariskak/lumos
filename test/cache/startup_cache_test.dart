import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reportdeepen/cache/startup_cache.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('writes and reads a value for a user', () async {
    await StartupCache.write('u1', 'group', {'id': 'g1', 'n': 2});

    expect(await StartupCache.read('u1', 'group'), {'id': 'g1', 'n': 2});
  });

  test('values are isolated per user', () async {
    await StartupCache.write('u1', 'group', {'id': 'g1'});

    expect(await StartupCache.read('u2', 'group'), isNull);
  });

  test('corrupted value reads as null', () async {
    SharedPreferences.setMockInitialValues({
      'startup_cache_v1:u1:group': '{not json',
    });

    expect(await StartupCache.read('u1', 'group'), isNull);
  });

  test('clear removes only cache keys', () async {
    SharedPreferences.setMockInitialValues({'pin_hash': 'x'});
    await StartupCache.write('u1', 'group', {'id': 'g1'});
    await StartupCache.write('u2', 'home', [1, 2]);

    await StartupCache.clear();

    expect(await StartupCache.read('u1', 'group'), isNull);
    expect(await StartupCache.read('u2', 'home'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pin_hash'), 'x');
  });
}
