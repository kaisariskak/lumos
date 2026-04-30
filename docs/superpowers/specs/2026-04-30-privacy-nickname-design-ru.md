# Приватность профилей: ник вместо Google-имени

**Дата:** 2026-04-30
**Статус:** Утверждённый дизайн
**Автор:** Қайсар Нұрланұлы

## Цель

Убрать персональные данные Google (email, имя, фамилия, аватар) из таблиц приложения. Участники группы видят друг друга только под ником, который пользователь выбирает при регистрации.

## Модель угроз

**Защищаем от:**
- **A.** Один участник группы видит email/реальное имя другого участника.
- **B.** Утечка дампа таблиц приложения (через RLS-баг, кривую RPC, ошибку в коде) выдаёт email/имя/фамилию.

**Не защищаем (out of scope):**
- Утечку самого Supabase / `auth.users` — это инфраструктурный уровень, encryption at rest и RLS-политики Supabase.
- Утечку `service_role` ключа — защищается тем, что ключа нет в клиенте.
- Анонимность от Google — Google знает email при OAuth по определению.

**Принцип:** минимизация. Чего нет в БД, то нельзя украсть. Email и реальное имя в `ibadat_profiles` не попадают вообще. В `auth.users` email живёт по необходимости (Supabase нужен для логина), доступ — только через стандартную RLS-политику Supabase «свой email видит только сам пользователь».

## Изменения в схеме данных

### Таблица `ibadat_profiles`

| Колонка | Сейчас | После | Действие |
|---|---|---|---|
| `id` | UUID (= `auth.users.id`) | без изменений | — |
| `display_name` | имя из Google | переименовать в `nickname`, заполняется пользователем | `RENAME` |
| `email` | email из Google | удалить | `DROP` |
| `avatar_url` | URL картинки Google | удалить | `DROP` |
| `role` | `user`/`admin`/`super_admin` | без изменений | — |
| `current_group_id` | UUID | без изменений | — |
| `super_admin_id` | UUID | без изменений | — |
| `created_by_admin_id` | UUID | без изменений | — |
| `created_at`, `updated_at` | timestamps | без изменений | — |

**Обоснование удаления `avatar_url`:** ссылка вида `https://lh3.googleusercontent.com/a/<id>` напрямую раскрывает Google-аккаунт по обратному поиску. Загрузка собственных картинок в Supabase Storage — отдельная задача, вне scope этого спека. До тех пор используются буквенные заглушки.

### Ограничения на `nickname`

- `NOT NULL`, `UNIQUE` (в рамках всей таблицы).
- Длина 2–32 символа.
- Разрешённые символы: латиница, кириллица, казахские буквы, цифры, пробел, `_`, `-`, `.`. Без эмодзи и спецсимволов.
- Проверка через `CHECK` constraint в БД, дублируется на клиенте для UX.

### Миграция существующих данных

- `ALTER TABLE ibadat_profiles RENAME COLUMN display_name TO nickname`.
- Реальные имена из старого `display_name` остаются в `nickname`. Пользователь может изменить ник в профиле.
- `DROP COLUMN email`, `DROP COLUMN avatar_url`.
- Никаких удалений строк или потери данных.

## Поток регистрации

### Сейчас

Google OAuth → `AuthGate` сразу создаёт профиль с `display_name = full_name`, `email = google email`, `avatar_url = google avatar` → запрос инвайт-кода → вход.

### После

```
┌─────────────────────────┐
│ 1. Google OAuth         │  Supabase создаёт auth.users
└────────────┬────────────┘  (email Google остаётся ТОЛЬКО там)
             │
             ▼
┌─────────────────────────┐
│ 2. RegistrationScreen   │  Один экран. Два обязательных поля:
│    - Лақап ат           │   - Лақап ат (ник)
│    - Шақыру коды        │   - Шақыру коды
│    [Тіркелу] [Шығу]     │
└────────────┬────────────┘
             │ submit
             ▼
┌─────────────────────────┐
│ register_with_invite    │  Атомарная Postgres RPC:
│ (Postgres RPC):         │   1. Валидация ника
│  1. Проверить ник       │   2. Валидация кода
│  2. Проверить код       │   3. INSERT в ibadat_profiles
│  3. Создать профиль     │   4. Если ADMIN-код — UPDATE used_at
│  4. mark_used (ADMIN)   │
└────────────┬────────────┘
             ▼
       MainScaffold
```

### Ключевые отличия

1. **`RegistrationScreen` — один экран** с двумя обязательными полями: ник и инвайт-код. Заменяет нынешний `InviteCodeScreen` для случая «нет профиля». Старый `InviteCodeScreen` остаётся **только** для сценария «профиль есть, но `current_group_id` пуст» — тут ник уже выбран, нужен только новый USER-код для группы.
2. **Атомарная серверная операция** через RPC `register_with_invite(p_nickname text, p_code text)`. Уникальность ника и потребление кода — в одной транзакции, гонок не будет.
3. **UX ошибок на одном экране.** RPC возвращает `reason ∈ {nickname_taken, invalid_code, expired_code, already_registered, invalid_nickname, not_authenticated}`:
   - `nickname_taken` → подсветить поле ника, оставить код.
   - `invalid_code` / `expired_code` → подсветить поле кода, оставить ник.
   - `already_registered` → перезагрузить профиль через `_loadProfile`.
4. **`AuthGate._loadProfile`** различает три состояния отсутствия профиля:
   - Сессии нет → `IbadatAuthorization`.
   - Сессия есть, профиля нет → `RegistrationScreen` (ник + код).
   - Сессия есть, профиль есть, нет `current_group_id` → старый `InviteCodeScreen` (только код).
5. **Никаких обращений к `user.userMetadata?['full_name']`, `['name']`, `['avatar_url']`** в коде после изменений — текущие места в [auth_gate.dart:135-150](lib/authentication/auth_gate.dart#L135-L150) удаляются.

## Изменения в UI

| Место | Сейчас | После |
|---|---|---|
| [profile_screen.dart:124](lib/screens/profile/profile_screen.dart#L124) — свой профиль | `widget.profile.email` | `Supabase.instance.client.auth.currentUser?.email ?? ''` |
| [detail_screen.dart:249](lib/screens/detail/detail_screen.dart#L249) — карточка участника | `profile.email` | строку с email убрать. Только ник + статистика. |
| [admin_screen.dart:1220](lib/screens/admin/admin_screen.dart#L1220) — список админов | `admin.email` | строку убрать. Только `admin.nickname` + бэйдж 👑 |
| [admin_screen.dart:1365](lib/screens/admin/admin_screen.dart#L1365) — список юзеров | `user.email` | строку убрать. Только `user.nickname`. |
| [admin_screen.dart:1866](lib/screens/admin/admin_screen.dart#L1866) — карточка участника | `m.email` | строку убрать. Только `m.nickname`. |
| Аватарки везде | `NetworkImage(profile.avatarUrl)` | `Text(nickname[0].toUpperCase())` — буквенная заглушка с цветом из `accent_provider`. |

### Что удаляем целиком

Управление админами уже работает через ADM-коды (генерация в [super_admin_codes_screen.dart](lib/screens/super_admin/super_admin_codes_screen.dart)). Альтернативный путь повышения через email-поиск дублирует первый и удаляется:

- [admin_screen.dart:357-389](lib/screens/admin/admin_screen.dart#L357-L389) — функция `_addAdmin()`.
- [admin_screen.dart:76, :142, :1244-1290](lib/screens/admin/admin_screen.dart#L76) — поле `_emailCtrl`, его dispose, и весь UI «Add new admin form» с полем email + кнопкой.
- [profile_repository.dart:19-27](lib/repositories/profile_repository.dart#L19-L27) — метод `getUserByEmail`.
- [profile_repository.dart:87-92](lib/repositories/profile_repository.dart#L87-L92) — метод `setSuperAdminId`.
- В [app_strings.dart](lib/l10n/app_strings.dart) — строки `emailHint`, `emailLabel`, `addAdminHint` (если они нигде больше не используются — проверить в плане).

Супер-админ управляет админами **только** через ADM-коды. Никаких email-инпутов в админке вообще.

## RLS-политики и серверные функции

### RLS на `ibadat_profiles`

```sql
ALTER TABLE ibadat_profiles ENABLE ROW LEVEL SECURITY;
```

| Операция | Кто может | Условие |
|---|---|---|
| `SELECT` свой профиль | сам пользователь | `auth.uid() = id` |
| `SELECT` чужой профиль в той же группе | участники одной группы | `current_group_id IN (SELECT current_group_id FROM ibadat_profiles WHERE id = auth.uid())` |
| `SELECT` всех своих юзеров | админ группы | `id IN (SELECT id FROM ibadat_profiles p2 WHERE p2.current_group_id IN (SELECT id FROM ibadat_groups WHERE admin_id = auth.uid()))` |
| `SELECT` своих админов | супер-админ | `super_admin_id = auth.uid()` |
| `UPDATE nickname` | только сам | `auth.uid() = id` с `WITH CHECK`, не разрешая менять `role`, `super_admin_id`, `created_by_admin_id` |
| `INSERT` | через RPC `register_with_invite` | политики на `INSERT` нет — RPC `SECURITY DEFINER` обходит RLS осознанно |
| `DELETE` | супер-админ или сам пользователь | по аналогии с существующей политикой |

**Заметка про утечку по `UNIQUE nickname`:** `unique_violation` через `INSERT` может выдать факт существования ника. Это допустимо: ник публичен в группе по дизайну. Главное — за пределами группы профиль (включая ник) не должен быть достижим. Проверяется в плане реализации.

### RPC `register_with_invite`

```sql
CREATE OR REPLACE FUNCTION register_with_invite(
  p_nickname text,
  p_code text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_code record;
  v_profile record;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  IF length(p_nickname) < 2 OR length(p_nickname) > 32 THEN
    RETURN jsonb_build_object('error', 'invalid_nickname');
  END IF;

  IF p_nickname !~ '^[A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі0-9 _.\-]+$' THEN
    RETURN jsonb_build_object('error', 'invalid_nickname');
  END IF;

  SELECT * INTO v_code FROM ibadat_invite_codes
   WHERE code = p_code
     AND (used_at IS NULL OR role_type = 'USER')
     AND (expires_at IS NULL OR expires_at > now())
   LIMIT 1;

  IF v_code IS NULL THEN
    RETURN jsonb_build_object('error', 'invalid_code');
  END IF;

  IF EXISTS(SELECT 1 FROM ibadat_profiles WHERE id = v_user_id) THEN
    RETURN jsonb_build_object('error', 'already_registered');
  END IF;

  BEGIN
    INSERT INTO ibadat_profiles (
      id, nickname, role, current_group_id, super_admin_id, created_by_admin_id
    )
    VALUES (
      v_user_id,
      p_nickname,
      CASE WHEN v_code.role_type = 'ADMIN' THEN 'admin' ELSE 'user' END,
      v_code.group_id,
      CASE WHEN v_code.role_type = 'ADMIN' THEN v_code.created_by ELSE NULL END,
      CASE WHEN v_code.role_type = 'USER' THEN v_code.created_by ELSE NULL END
    )
    RETURNING * INTO v_profile;
  EXCEPTION
    WHEN unique_violation THEN
      RETURN jsonb_build_object('error', 'nickname_taken');
  END;

  IF v_code.role_type = 'ADMIN' THEN
    UPDATE ibadat_invite_codes SET used_at = now() WHERE id = v_code.id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'profile', row_to_json(v_profile));
END;
$$;

REVOKE ALL ON FUNCTION register_with_invite FROM PUBLIC;
GRANT EXECUTE ON FUNCTION register_with_invite TO authenticated;
```

### RPC `is_nickname_taken` (для UX)

Чтобы экран регистрации мог заранее (на потерю фокуса с поля) подсветить занятый ник:

```sql
CREATE OR REPLACE FUNCTION is_nickname_taken(p_nickname text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS(SELECT 1 FROM ibadat_profiles WHERE nickname = p_nickname);
$$;
GRANT EXECUTE ON FUNCTION is_nickname_taken TO authenticated;
```

### Что НЕ делаем

- Не трогаем `auth.users`.
- Не выдаём `service_role` ключ клиенту.
- Не создаём триггер на `auth.users` для автозаведения профиля. Профиль появляется только через `register_with_invite`.

## Миграция и тестирование

### SQL-миграция (одна транзакция)

```sql
BEGIN;

-- 1. Schema changes
ALTER TABLE ibadat_profiles RENAME COLUMN display_name TO nickname;
ALTER TABLE ibadat_profiles DROP COLUMN email;
ALTER TABLE ibadat_profiles DROP COLUMN avatar_url;

-- 2. Constraints
ALTER TABLE ibadat_profiles
  ADD CONSTRAINT nickname_length CHECK (length(nickname) BETWEEN 2 AND 32),
  ADD CONSTRAINT nickname_format CHECK (
    nickname ~ '^[A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі0-9 _.\-]+$'
  );
CREATE UNIQUE INDEX IF NOT EXISTS ibadat_profiles_nickname_uniq
  ON ibadat_profiles (nickname);

-- 3. RLS policies (DROP старые, CREATE новые — см. выше)
-- 4. RPC functions: register_with_invite, is_nickname_taken

COMMIT;
```

**Идемпотентность:** `IF EXISTS` / `IF NOT EXISTS` где возможно. `RENAME COLUMN` идемпотентным сделать нельзя — если миграция упадёт между шагами 1 и 2, придётся откатывать вручную. Поэтому `BEGIN/COMMIT` и проверка на staging-окружении (если есть) перед prod.

### Чек-лист тестирования

1. Новый юзер регистрируется через `RegistrationScreen` (ник + ADM-код) → профиль создан, в БД нет email/google-имени.
2. Регистрация с занятым ником → `nickname_taken`, поле подсвечено, код не сожжён.
3. Регистрация с битым кодом → `invalid_code`, поле кода подсвечено, ник не теряется.
4. Гонка двух регистраций с одним ником одновременно → ровно один проходит, второй получает `nickname_taken`.
5. Юзер A в группе G1 не может прочитать профиль юзера B в группе G2 через REST/RLS.
6. Юзер A в группе G1 может прочитать ник (не email) юзера C в той же группе G1.
7. Email из `ibadat_profiles` не возвращается ни в одном запросе — снять дамп всех `SELECT *` из приложения, убедиться, что колонки `email` нет в результате.
8. `auth.users.email` всё ещё доступен пользователю для своего собственного аккаунта через `auth.currentUser.email` (показывается в `ProfileScreen`).
9. Удаление `_addAdmin` UI — супер-админ всё ещё управляет админами через `super_admin_codes_screen`.
10. Аватарки работают как буквенные заглушки, нигде не падает на `null` `avatar_url`.

### Метрики успеха

```sql
-- В проде после миграции должен возвращать пустоту
SELECT column_name FROM information_schema.columns
 WHERE table_name = 'ibadat_profiles'
   AND column_name IN ('email', 'avatar_url');
```

На клиенте — `grep -rn "\.email" lib/ | grep -v "auth.currentUser"` показывает только использования `auth.currentUser.email`.

## Open questions / на будущее

- **Загрузка собственных аватаров в Supabase Storage** — отдельный спек, после этого.
- **Не-уникальный ник + `@handle`** — если ников станет много и захочется тегать друг друга. Сейчас явно не нужно.
- **Аудит-лог** доступа к `auth.users.email` — если паранойя усилится. Не обязательно.
- **«Теневой логин»** (Edge Function проверяет Google ID-token и создаёт `auth.users` с синтетическим email) — over-engineering для текущей модели угроз, не делаем.
