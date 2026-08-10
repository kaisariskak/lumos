import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/l10n/app_strings.dart';

void main() {
  test('Russian account deletion strings are present', () {
    final s = AppStrings.ru;

    expect(s.accountSectionTitle, 'Аккаунт');
    expect(s.signOutOfAccount, 'Выйти из аккаунта');
    expect(s.deleteAccount, 'Удалить аккаунт');
    expect(s.deleteAccountTitle, 'Удалить аккаунт?');
    expect(
      s.deleteAccountBody,
      'Аккаунт и связанные с ним данные будут удалены без возможности восстановления.',
    );
    expect(s.deleteForever, 'Удалить навсегда');
    expect(s.deletingAccount, 'Удаляем аккаунт...');
    expect(s.deleteAccountSuccess, 'Аккаунт удалён');
    expect(s.deleteAccountNoSession, 'Сессия не найдена. Войдите снова.');
    expect(
      s.deleteAccountSuperAdminForbidden,
      'Удаление аккаунта недоступно для этой роли.',
    );
    expect(
      s.deleteAccountGroupOwnershipBlocked,
      'Перед удалением аккаунта передайте группы другому администратору.',
    );
    expect(
      s.deleteAccountRetryableFailure,
      'Не удалось удалить аккаунт. Попробуйте позже.',
    );
    expect(
      s.deleteAccountUnknownFailure,
      'При удалении аккаунта произошла ошибка.',
    );
    expect(
      s.deleteAccountAppleManualRevoke,
      'Доступ через Apple также можно отозвать вручную в настройках Apple ID.',
    );
  });

  test('Kazakh account deletion strings are present', () {
    final s = AppStrings.kk;

    expect(s.accountSectionTitle, 'Аккаунт');
    expect(s.signOutOfAccount, 'Аккаунттан шығу');
    expect(s.deleteAccount, 'Аккаунтты жою');
    expect(s.deleteAccountTitle, 'Аккаунтты жою?');
    expect(
      s.deleteAccountBody,
      'Аккаунт және оған байланысты деректер қалпына келтіру мүмкіндігінсіз жойылады.',
    );
    expect(s.deleteForever, 'Біржола жою');
    expect(s.deletingAccount, 'Аккаунт жойылуда...');
    expect(s.deleteAccountSuccess, 'Аккаунт жойылды');
    expect(s.deleteAccountNoSession, 'Сессия табылмады. Қайта кіріңіз.');
    expect(
      s.deleteAccountSuperAdminForbidden,
      'Бұл рөл үшін аккаунтты жою қолжетімді емес.',
    );
    expect(
      s.deleteAccountGroupOwnershipBlocked,
      'Аккаунтты жою үшін алдымен топтарды басқа администраторға беріңіз.',
    );
    expect(
      s.deleteAccountRetryableFailure,
      'Аккаунтты жою мүмкін болмады. Кейін қайталап көріңіз.',
    );
    expect(
      s.deleteAccountUnknownFailure,
      'Аккаунтты жою кезінде қате пайда болды.',
    );
    expect(
      s.deleteAccountAppleManualRevoke,
      'Apple арқылы кіру рұқсатын Apple ID баптауларынан қолмен қайтарып алуға болады.',
    );
  });
}
