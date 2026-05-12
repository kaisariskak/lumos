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
    name: 'Nur',
    accent: Color(0xFF22C55E),
    accentDark: Color(0xFF059669),
    accentLight: Color(0xFF86EFAC),
    gradientMid: Color(0xFF132B2B),
  ),
  AppAccent(
    name: 'Sage',
    accent: Color(0xFF2DD4BF),
    accentDark: Color(0xFF0F766E),
    accentLight: Color(0xFF99F6E4),
    gradientMid: Color(0xFF102F2D),
  ),
  AppAccent(
    name: 'Sky',
    accent: Color(0xFF38BDF8),
    accentDark: Color(0xFF0284C7),
    accentLight: Color(0xFFBAE6FD),
    gradientMid: Color(0xFF102A3A),
  ),
  AppAccent(
    name: 'Gold',
    accent: Color(0xFFF6C453),
    accentDark: Color(0xFFD99A12),
    accentLight: Color(0xFFFDE68A),
    gradientMid: Color(0xFF302711),
  ),
  AppAccent(
    name: 'Rose',
    accent: Color(0xFFFB7185),
    accentDark: Color(0xFFE11D48),
    accentLight: Color(0xFFFDA4AF),
    gradientMid: Color(0xFF321722),
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
