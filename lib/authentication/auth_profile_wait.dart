class AuthProfileWait {
  AuthProfileWait._();

  static bool shouldWaitForUsernameProfile(Map<String, dynamic>? metadata) {
    final login = metadata?['login'];
    return login is String && login.trim().isNotEmpty;
  }
}
