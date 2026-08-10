# Account Deletion Transfer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the completed account deletion implementation from `feature/account-deletion` onto `main` and verify it in the current testable branch.

**Architecture:** Apply the full branch diff to the current `main` working tree, inspect the resulting file set, resolve any conflicts locally, then run focused Flutter analysis and account deletion tests. The transfer preserves the existing implementation boundaries: service logic in `lib/services`, reusable UI in `lib/widgets`, screen integration in profile/admin, server deletion in Supabase Edge Function and SQL RPC.

**Tech Stack:** Flutter/Dart, Supabase Flutter, Supabase Edge Functions, SQL migrations, Flutter test.

---

## File Map

- Create: `db/migrations/2026-08-05_delete_account_data_rpc.sql` - trusted database RPC for account data deletion.
- Modify: `lib/l10n/app_strings.dart` - localized account deletion labels, dialog text, and error messages.
- Modify: `lib/screens/admin/admin_screen.dart` - show shared account section for non-`super_admin` admins.
- Modify: `lib/screens/profile/profile_screen.dart` - show shared account section for non-`super_admin` users.
- Create: `lib/services/account_deletion_service.dart` - client-side Edge Function caller and result mapping.
- Modify: `lib/services/auth_logout_service.dart` - shared local cleanup used by sign-out and deletion.
- Create: `lib/widgets/account_section.dart` - reusable sign-out/delete-account UI.
- Create: `supabase/functions/delete-account/README.md` - deployment and behavior notes.
- Create: `supabase/functions/delete-account/index.ts` - server-side account deletion function.
- Create: `test/l10n/app_strings_account_deletion_test.dart` - localization coverage.
- Create: `test/services/account_deletion_service_test.dart` - client service result mapping coverage.
- Modify: `test/services/auth_error_message_test.dart` - fixture updates for added strings.
- Modify: `test/services/auth_logout_service_test.dart` - cleanup behavior coverage.
- Create: `test/supabase_delete_account_function_test.dart` - static safety checks for Edge Function.
- Create: `test/widgets/account_section_test.dart` - widget and screen integration checks.

### Task 1: Apply Feature Branch Diff

**Files:**
- Create/Modify all files listed in File Map.

- [ ] **Step 1: Confirm clean transfer base**

Run:

```bash
git status --short --branch
```

Expected: current branch is `main`; no unrelated unstaged edits except this plan/spec work.

- [ ] **Step 2: Apply the branch diff**

Run:

```bash
git diff --binary main..feature/account-deletion | git apply --3way
```

Expected: patch applies cleanly or leaves conflict markers/files for manual resolution.

- [ ] **Step 3: Inspect transferred file set**

Run:

```bash
git diff --name-status
```

Expected: the file list matches the File Map and does not include unrelated branch changes.

### Task 2: Resolve Conflicts And Preserve Feature Tip Behavior

**Files:**
- Modify any conflicted files from Task 1.

- [ ] **Step 1: Search for conflict markers**

Run:

```bash
rg -n "<<<<<<<|=======|>>>>>>>" lib test db supabase docs
```

Expected: no output after conflicts are resolved.

- [ ] **Step 2: Verify `super_admin` deletion is hidden**

Run:

```bash
rg -n "super_admin|AccountSection|deleteAccount" lib/screens/profile/profile_screen.dart lib/screens/admin/admin_screen.dart lib/widgets/account_section.dart test/widgets/account_section_test.dart
```

Expected: profile/admin integration hides account deletion for `super_admin`, and tests cover that behavior.

### Task 3: Run Focused Verification

**Files:**
- Analyze and test transferred implementation files.

- [ ] **Step 1: Run Flutter analysis**

Run:

```bash
flutter analyze --no-pub lib/services/account_deletion_service.dart lib/services/auth_logout_service.dart lib/widgets/account_section.dart lib/screens/profile/profile_screen.dart lib/screens/admin/admin_screen.dart lib/l10n/app_strings.dart
```

Expected: `No issues found!`

- [ ] **Step 2: Run account deletion tests**

Run:

```bash
flutter test test/services/account_deletion_service_test.dart test/services/auth_logout_service_test.dart test/l10n/app_strings_account_deletion_test.dart test/widgets/account_section_test.dart test/supabase_delete_account_function_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 3: Report manual Supabase verification**

Record in the final response that full live deletion still requires deploying `delete-account` and testing with disposable Supabase users, because local Flutter tests cannot delete real hosted auth users.

### Task 4: Commit Transfer

**Files:**
- Commit all transferred files after verification.

- [ ] **Step 1: Review final diff summary**

Run:

```bash
git diff --stat
```

Expected: changes are limited to account deletion implementation, tests, SQL, and Supabase function files.

- [ ] **Step 2: Commit implementation**

Run:

```bash
git add -- db/migrations/2026-08-05_delete_account_data_rpc.sql lib/l10n/app_strings.dart lib/screens/admin/admin_screen.dart lib/screens/profile/profile_screen.dart lib/services/account_deletion_service.dart lib/services/auth_logout_service.dart lib/widgets/account_section.dart supabase/functions/delete-account/README.md supabase/functions/delete-account/index.ts test/l10n/app_strings_account_deletion_test.dart test/services/account_deletion_service_test.dart test/services/auth_error_message_test.dart test/services/auth_logout_service_test.dart test/supabase_delete_account_function_test.dart test/widgets/account_section_test.dart
git commit -m "feat: transfer account deletion implementation"
```

Expected: commit succeeds on `main`.
