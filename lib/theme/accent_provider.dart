import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppAccent {
  final String name;
  final Color accent;
  final Color accentDark;
  final Color accentLight;
  final Color gradientMid;

  const AppAccent({
    required this.name,
    required this.accent,
    required this.accentDark,
    required this.accentLight,
    required this.gradientMid,
  });
}

const List<AppAccent> appAccents = [
  AppAccent(
    name: 'Indigo',
    accent: Color(0xFF6366F1),
    accentDark: Color(0xFF4F46E5),
    accentLight: Color(0xFFA5B4FC),
    gradientMid: Color(0xFF1E1B4B),
  ),
  AppAccent(
    name: 'Emerald',
    accent: Color(0xFF10B981),
    accentDark: Color(0xFF059669),
    accentLight: Color(0xFF6EE7B7),
    gradientMid: Color(0xFF0C2A1F),
  ),
  AppAccent(
    name: 'Rose',
    accent: Color(0xFFEC4899),
    accentDark: Color(0xFFDB2777),
    accentLight: Color(0xFFF9A8D4),
    gradientMid: Color(0xFF2A0C1E),
  ),
  AppAccent(
    name: 'Amber',
    accent: Color(0xFFF59E0B),
    accentDark: Color(0xFFD97706),
    accentLight: Color(0xFFFCD34D),
    gradientMid: Color(0xFF2A1C00),
  ),
];

class AccentProvider extends ValueNotifier<int> {
  static final AccentProvider instance = AccentProvider._internal(0);

  AccentProvider._internal(super.value);

  static const _key = 'app_accent_index';

  AppAccent get current => appAccents[value];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getInt(_key) ?? 0;
  }

  Future<void> setAccent(int index) async {
    value = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, index);
  }
}
