import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ValueNotifier<Locale> {
  static final LocaleProvider instance =
      LocaleProvider._internal(const Locale('kk'));

  LocaleProvider._internal(super.value);

  static const _key = 'app_locale';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString(_key) ?? 'kk';
    value = Locale(lang);
  }

  Future<void> setLocale(Locale locale) async {
    value = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }
}
