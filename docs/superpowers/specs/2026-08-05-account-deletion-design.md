# Account Deletion Design

## Context

Lumos Daily needs an in-app account section that lets regular users and admins sign out or delete their account. The app uses Flutter with Supabase Auth, Supabase tables, Google Sign-In, and Apple Sign-In. Account deletion must not expose a `service_role` key in the Flutter app. Supabase admin deletion must run only on trusted server code.

`super_admin` accounts are excluded from this feature. They should not see account deletion controls.

## Goals

- Add an `Account` section at the bottom of `ProfileScreen` and `AdminScreen`.
- Show `Sign out` and `Delete account` actions in that section.
- Style `Delete account` as a red destructive action.
- Require confirmation before permanent deletion.
- Delete the authenticated user and their related personal data through a Supabase Edge Function.
- Clear local app state and return to the sign-in screen after successful deletion.
- Keep Apple Sign-In deletion compliant even when Apple tokens are not yet stored.

## Non-Goals

- Do not add account deletion for `super_admin`.
- Do not store Supabase `service_role` keys in Flutter.
- Do not require the user to contact support or send email to delete an account.
- Do not automatically delete shared group data that belongs to other members.
- Do not implement full Apple token persistence in this first pass.

## User Experience

Create a reusable account section widget or helper used by both profile and admin screens. The section appears at the bottom of the screen after existing settings.

The section title is:

```text
Аккаунт
```

Actions:

```text
Выйти из аккаунта
Удалить аккаунт
```

`Выйти из аккаунта` uses the existing logout behavior. `Удалить аккаунт` uses a red destructive style.

When the user taps `Удалить аккаунт`, show a confirmation dialog:

```text
Удалить аккаунт?

Аккаунт и связанные с ним данные будут удалены без возможности восстановления.

Отмена
Удалить навсегда
```

`Удалить навсегда` is red. While deletion is running, disable destructive controls and show progress. On success, clear local app data, sign out from Supabase and Google where applicable, and let the auth gate return the user to sign-in.

If Apple access or refresh tokens are not available for revoke, deletion still succeeds. The app should show a short message before returning to sign-in, explaining that Apple access may also be revoked manually from Apple ID settings.

## Flutter Architecture

Add an `AccountDeletionService` that owns the client-side call to the Edge Function. Screens should not construct function payloads or parse low-level Supabase errors directly.

Responsibilities:

- Read the current Supabase session.
- Fail with a typed result if there is no active session.
- Call the `delete-account` Edge Function with the current JWT.
- Parse structured responses such as success, forbidden role, blocked group ownership, or generic failure.
- On success, invoke local cleanup and sign-out logic.

Update `AuthLogoutService` so account deletion and normal sign-out share local cleanup behavior. PIN data and other locally persisted account state must be cleared during deletion.

Localization should be added to `app_strings.dart` for Russian and Kazakh:

- Account section title.
- Sign out from account.
- Delete account.
- Delete confirmation title.
- Delete confirmation body.
- Delete forever.
- Deletion progress/error/success messages.
- Apple manual revoke note.
- Group ownership blocking message.

## Server Architecture

Add a Supabase Edge Function:

```text
supabase/functions/delete-account/index.ts
```

The function runs with:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

The Flutter app calls this function with the current authenticated JWT. The function must validate that JWT before deleting anything.

Flow:

1. Read the `Authorization: Bearer <jwt>` header.
2. Create a user-scoped Supabase client with the JWT.
3. Call `auth.getUser()` to identify the current user.
4. Load `ibadat_profiles` for `user.id`.
5. Reject deletion if the profile role is `super_admin`.
6. Use an admin Supabase client with `SUPABASE_SERVICE_ROLE_KEY` for deletion.
7. Delete related personal rows.
8. Delete or detach the profile.
9. Call `supabaseAdmin.auth.admin.deleteUser(user.id)`.
10. Return a structured success response.

Expected success response:

```json
{
  "ok": true,
  "appleRevoked": false
}
```

Expected blocked response for unsafe admin group ownership:

```json
{
  "ok": false,
  "code": "group_ownership_blocked"
}
```

Expected forbidden response:

```json
{
  "ok": false,
  "code": "super_admin_forbidden"
}
```

## Data Deletion Rules

Delete personal data tied directly to the account:

- `report_metric_values` for reports owned by the user.
- `ibadat_reports` where `user_id = user.id`.
- `ibadat_member_settings` where `profile_id = user.id`.
- `ibadat_payments` where `profile_id = user.id`.
- `ibadat_periods` where `created_by = user.id`.
- `group_metrics` where `admin_id = user.id`.
- `ibadat_invite_codes` where `created_by = user.id`.
- `ibadat_profiles` where `id = user.id`.

Shared group handling:

- Never delete a group simply because one user deletes their account.
- If schema allows `ibadat_groups.admin_id` to become null, detach deleted admins from their groups by setting `admin_id = null`.
- If `admin_id` is required, block deletion for admins who still own groups and return `group_ownership_blocked`.
- For `financier_id = user.id`, set the value to null if schema allows it.
- Other group members and their reports must remain intact.

The implementation should prefer foreign keys with `ON DELETE CASCADE` for private dependent rows where that matches ownership. For shared tables, deletion or nulling must be explicit.

## Apple Sign-In

Apple recommends revoking Apple tokens when deleting an account created through Sign in with Apple. This design does not assume those tokens are currently stored.

First pass behavior:

- Delete the Supabase account and app data even if Apple tokens are unavailable.
- Return `appleRevoked: false` from the function.
- Show a short user-facing note that Apple access can be revoked manually from Apple ID settings.

Future-compatible behavior:

- If Apple access or refresh tokens are later stored securely on the server, the Edge Function can call Apple's revoke endpoint before or after app data deletion.
- The Flutter UI should already be able to read `appleRevoked` from the function response.

## Error Handling

Flutter should map function responses to clear user messages:

- `no_session`: ask the user to sign in again.
- `super_admin_forbidden`: account deletion is not available for this role.
- `group_ownership_blocked`: transfer or resolve owned groups before deleting the account.
- network/function failure: show a retryable error.
- unknown failure: show a generic failure and keep the user signed in.

The Edge Function should avoid leaking service-role details. Logs can contain internal details; client responses should use stable error codes.

## Testing

Flutter verification:

- Run `flutter analyze --no-pub` on changed Dart files.
- Add unit tests for `AccountDeletionService` covering success, no session, forbidden response, blocked group ownership, and generic function failure.
- If practical, add a focused widget test for the account section confirmation dialog.

Server verification:

- Add a small README or inline deployment notes for the Edge Function environment variables.
- Validate the function rejects missing or invalid JWT.
- Validate the function rejects `super_admin`.
- Validate personal rows are deleted before `auth.admin.deleteUser`.
- Validate shared groups are not deleted.

## Rollout Notes

Deploy the Edge Function before releasing the Flutter UI. If the function is missing, the app should fail gracefully and tell the user to try again later.

Because account deletion is a compliance-sensitive feature, test the flow using a disposable user before submitting to app review.
