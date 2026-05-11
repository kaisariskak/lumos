import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/services/username_auth_mapper.dart';

void main() {
  group('UsernameAuthMapper', () {
    test('normalizes login before mapping it to a hidden auth email', () {
      expect(
        UsernameAuthMapper.toAuthEmail('  Kaisar_01  '),
        'kaisar_01@auth.reportdeepen.app',
      );
    });

    test('shows login instead of hidden auth email', () {
      expect(
        UsernameAuthMapper.displayLoginOrEmail(
          'kaisar_01@auth.reportdeepen.app',
        ),
        'kaisar_01',
      );
    });

    test('keeps real email visible for Google accounts', () {
      expect(
        UsernameAuthMapper.displayLoginOrEmail('user@gmail.com'),
        'user@gmail.com',
      );
    });

    test('allows latin letters, numbers, dot, dash, and underscore', () {
      expect(
        UsernameAuthMapper.normalizeLogin('nur.admin-01'),
        'nur.admin-01',
      );
    });

    test('rejects short, long, and malformed logins', () {
      expect(() => UsernameAuthMapper.normalizeLogin('ab'), throwsFormatException);
      expect(
        () => UsernameAuthMapper.normalizeLogin('a' * 33),
        throwsFormatException,
      );
      expect(
        () => UsernameAuthMapper.normalizeLogin('bad login'),
        throwsFormatException,
      );
      expect(
        () => UsernameAuthMapper.normalizeLogin('bad@mail.com'),
        throwsFormatException,
      );
    });
  });
}
