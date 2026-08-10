# Apple Delete Note Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the Apple manual revoke note after account deletion only for Apple-authenticated users.

**Architecture:** `AccountDeletionService` reads the current provider before invoking deletion and stores the decision in `AccountDeletionResult`. `AccountSection` renders the Apple note only from that explicit result flag.

**Tech Stack:** Flutter/Dart, Supabase Flutter, Flutter test.

---

### Task 1: Service Provider Flag

**Files:**
- Modify: `lib/services/account_deletion_service.dart`
- Test: `test/services/account_deletion_service_test.dart`

- [ ] Add tests proving Apple provider sets `showAppleManualRevokeNote` and Google provider does not.
- [ ] Add a provider reader dependency to `AccountDeletionService`.
- [ ] Set the result flag only when deletion succeeds and provider is `apple`.
- [ ] Run `flutter test test/services/account_deletion_service_test.dart`.

### Task 2: Widget Note Condition

**Files:**
- Modify: `lib/widgets/account_section.dart`
- Test: `test/widgets/account_section_test.dart`

- [ ] Update the existing Apple-note widget test to pass `showAppleManualRevokeNote: true`.
- [ ] Add a successful non-Apple deletion widget test that expects no Apple note.
- [ ] Update `AccountSection` to use `result.showAppleManualRevokeNote`.
- [ ] Run `flutter test test/widgets/account_section_test.dart`.

### Task 3: Verification

**Files:**
- Analyze and test touched files.

- [ ] Run `flutter analyze --no-pub lib/services/account_deletion_service.dart lib/widgets/account_section.dart`.
- [ ] Run `flutter test test/services/account_deletion_service_test.dart test/widgets/account_section_test.dart`.
- [ ] Commit the implementation.
