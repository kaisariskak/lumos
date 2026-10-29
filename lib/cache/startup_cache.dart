import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Last-known startup data (profile, group, home screen) kept on the device so
/// the first screen can render before the network answers. Values are plain
/// JSON; any read/write failure is treated as "no cache".
class StartupCache {
  StartupCache._();

  static const _prefix = 'startup_cache_v1:';

  static String _key(String userId, String name) => '$_prefix$userId:$name';

  static Future<Object?> read(String userId, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId, name));
      if (raw == null) return null;
      return jsonDecode(raw);
    } catch (e) {
      debugPrint('StartupCache.read $name failed: $e');
      return null;
    }
  }

  static Future<void> write(String userId, String name, Object? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(userId, name), jsonEncode(value));
    } catch (e) {
      debugPrint('StartupCache.write $name failed: $e');
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('StartupCache.clear failed: $e');
    }
  }
}
