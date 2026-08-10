# delete-account Edge Function

Deletes the currently authenticated regular user or admin account with the
Supabase service-role key kept server-side in the Edge Function environment.
The Flutter app calls the function with the user's JWT only.

## Required Environment Variables

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Set secrets with:

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
```

Apply the database cleanup RPC migration before deploying the function. This
repo stores SQL migrations under `db/migrations`, so apply
`db/migrations/2026-08-05_delete_account_data_rpc.sql` in the Supabase SQL
Editor, or move it into your Supabase CLI migrations directory before running
CLI migrations.

Deploy with:

```bash
supabase functions deploy delete-account
```

## Client Contract

Call `delete-account` with `POST` and
`Authorization: Bearer <current-user-jwt>`.

Success:

```json
{ "ok": true, "appleRevoked": false }
```

Blocked admin group ownership:

```json
{ "ok": false, "code": "group_ownership_blocked" }
```

`super_admin` accounts are rejected:

```json
{ "ok": false, "code": "super_admin_forbidden" }
```

Missing or invalid session:

```json
{ "ok": false, "code": "no_session" }
```

## Retry Behavior

Database cleanup runs transactionally inside `delete_account_data` before the
Supabase auth user is deleted. If auth deletion fails after database cleanup,
retrying this function is safe: the profile may already be gone, but the RPC is
idempotent and the retry can still delete the auth user.
