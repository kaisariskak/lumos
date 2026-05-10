class UsernameAuthMapper {
  UsernameAuthMapper._();

  static const hiddenDomain = 'auth.reportdeepen.app';

  static final _loginPattern = RegExp(r'^[a-z0-9._-]{3,32}$');

  static String normalizeLogin(String login) {
    final normalized = login.trim().toLowerCase();
    if (!_loginPattern.hasMatch(normalized)) {
      throw const FormatException(
        'Login must be 3-32 characters: a-z, 0-9, dot, dash, underscore.',
      );
    }
    return normalized;
  }

  static String toAuthEmail(String login) {
    return '${normalizeLogin(login)}@$hiddenDomain';
  }
}
