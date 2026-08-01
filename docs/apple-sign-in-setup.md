# Настройка Sign in with Apple

Код приложения поддерживает нативный Apple ID token на iOS/iPadOS и браузерный Supabase OAuth на Android. Следующие действия выполняет владелец Apple Developer и Supabase перед проверкой на устройствах.

## Значения проекта

- iOS App ID / Bundle ID: `kz.kaizerproduct.lumos`
- Android application ID: `kz.kaizer.lumos`
- Apple Services ID: `kz.kaizerproduct.lumos.service`
- Supabase domain: `sydskxivdjickwwyjeqb.supabase.co`
- Apple return URL: `https://sydskxivdjickwwyjeqb.supabase.co/auth/v1/callback`
- App redirect: `io.supabase.flutterquickstart://login-callback/`

## Apple Developer

1. Откройте Certificates, Identifiers & Profiles → Identifiers → App IDs → `kz.kaizerproduct.lumos`.
2. Включите capability **Sign in with Apple**, выберите **Enable as a primary App ID** и сохраните.
3. Создайте Services ID `kz.kaizerproduct.lumos.service`.
4. Включите для Services ID Sign in with Apple и свяжите его с App ID `kz.kaizerproduct.lumos`.
5. Добавьте domain `sydskxivdjickwwyjeqb.supabase.co`.
6. Добавьте return URL `https://sydskxivdjickwwyjeqb.supabase.co/auth/v1/callback`.
7. Создайте Key с capability Sign in with Apple и выбранным primary App ID.
8. Сохраните Team ID и Key ID в менеджере секретов. Скачайте файл `.p8`: Apple позволяет скачать его только один раз.
9. Никогда не копируйте `.p8`, private key или сгенерированный client secret в этот репозиторий.

## Supabase

1. Откройте Authentication → Providers → Apple и включите provider.
2. В Client IDs первым укажите `kz.kaizerproduct.lumos.service`, вторым — `kz.kaizerproduct.lumos`. Первый ID используется Android OAuth; оба допустимы для проверки native token.
3. Сгенерируйте Apple client secret из Services ID, Team ID, Key ID и `.p8` официальным инструментом в документации Supabase.
4. Вставьте client secret в Apple provider и сохраните.
5. Откройте Authentication → URL Configuration и убедитесь, что Redirect URLs содержит `io.supabase.flutterquickstart://login-callback/`.

## Xcode и provisioning

1. Откройте `ios/Runner.xcworkspace`.
2. Выберите Runner → Signing & Capabilities.
3. Проверьте Bundle Identifier: `kz.kaizerproduct.lumos`.
4. Выберите правильную Team и включите Automatically manage signing либо вручную обновите provisioning profiles.
5. Убедитесь, что Sign in with Apple присутствует среди capabilities без предупреждений.

## Ротация client secret

Apple OAuth client secret для Android необходимо обновлять каждые шесть месяцев.

1. Создайте календарное напоминание за 14 дней до истечения.
2. Сгенерируйте новый secret из сохранённого `.p8`.
3. Замените secret в Supabase Apple provider.
4. Проверьте Android OAuth и iOS native login.
5. Зафиксируйте дату следующей ротации.

Если `.p8` потерян или раскрыт, немедленно отзовите key в Apple Developer, создайте новый key и client secret.

## Проверка на реальных устройствах

### iPhone/iPad

- Зарегистрированный пользователь входит и попадает в существующий профиль.
- Отмена Apple sheet не показывает ошибку.
- Неизвестный пользователь видит «Вы не зарегистрированы» и не получает профиль.

### Android

- Системный браузер открывает Apple и возвращает приложение через `io.supabase.flutterquickstart://login-callback/`.
- Зарегистрированный пользователь входит.
- Отмена не создаёт сессию и не показывает ошибку приложения.
- Неизвестный пользователь видит «Вы не зарегистрированы».

### Регрессия Google

- Нативный Google Sign-In продолжает работать.
- При ошибке Android Credential Manager браузерный Google OAuth fallback продолжает работать.

