# Username Password Auth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add username/password registration and sign-in while keeping Google sign-in available.

**Architecture:** The app accepts a user-chosen login, normalizes it, and maps it to a hidden synthetic email for Supabase Auth. New users sign up with login/password, then immediately create their profile through the existing `register_with_invite` RPC using nickname and invite code. Existing Google users continue through the current Google flow.

**Tech Stack:** Flutter, Dart, Supabase Auth, existing `register_with_invite` RPC, `flutter_test`.

---

### Task 1: Username Mapping

**Files:**
- Create: `lib/services/username_auth_mapper.dart`
- Test: `test/services/username_auth_mapper_test.dart`

- [ ] Write tests for login normalization, allowed characters, hidden email mapping, and invalid inputs.
- [ ] Run the test and verify it fails because the mapper does not exist.
- [ ] Implement `UsernameAuthMapper`.
- [ ] Run the mapper test and verify it passes.

### Task 2: Authorization Screen Auth Flow

**Files:**
- Modify: `lib/screens/authorization/ibadat_authorization.dart`
- Test: `test/screens/authorization/ibadat_authorization_test.dart`

- [ ] Add a widget test that the username/password form starts in sign-in mode.
- [ ] Add a widget test that switching to registration shows login, nickname, invite code, and password fields.
- [ ] Add a widget test that submit remains disabled until required fields are valid.
- [ ] Implement sign-in with `Supabase.auth.signInWithPassword(email: mappedLoginEmail, password: password)`.
- [ ] Implement registration with `Supabase.auth.signUp(email: mappedLoginEmail, password: password)`, then `ProfileRepository.registerWithInvite`.
- [ ] Keep the Google button visible as an alternate path.

### Task 3: Registration UI Polish

**Files:**
- Modify: `lib/screens/authorization/ibadat_authorization.dart`
- Modify: `lib/l10n/app_strings.dart`

- [ ] Add localized strings for login, password, create account, already have account, and validation errors.
- [ ] Replace the old single-button layout with a polished responsive auth panel.
- [ ] Use icons, strong focus states, a calm dark background, and stable field/button sizing.
- [ ] Make errors field-specific where possible and use snackbars for backend auth errors.

### Task 4: Verification

**Files:**
- Existing tests.

- [ ] Run focused widget and service tests.
- [ ] Run analyzer on touched files.
- [ ] Run the full test suite if focused tests and analyzer are clean.
- [ ] Manually note that Supabase email confirmation must be disabled for synthetic-login registration to complete immediately, or registration will require a server-side signup function later.
