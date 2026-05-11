import '../l10n/app_strings.dart';

String authErrorMessage(AppStrings s, String message) {
  final normalized = message.toLowerCase();
  if (normalized.contains('invalid login credentials')) {
    return s.languageCode == 'ru'
        ? 'Неверный логин или пароль'
        : 'Логин немесе құпиясөз дұрыс емес';
  }
  if (normalized.contains('user already registered') ||
      normalized.contains('already registered') ||
      normalized.contains('already exists')) {
    return s.languageCode == 'ru'
        ? 'Такой логин уже занят'
        : 'Бұл логин бос емес';
  }
  return message;
}
