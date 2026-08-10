# Account Deletion Transfer Design

## Context

The `feature/account-deletion` branch contains the completed account deletion implementation, but that branch cannot be tested in the current workflow. The `main` branch already contains the account deletion design and implementation plan, but not the implementation itself.

## Goal

Move the full account deletion implementation from `feature/account-deletion` onto `main` so it can be analyzed and tested from the current branch.

## Scope

Transfer the complete feature surface from `feature/account-deletion`:

- Flutter localization strings for the account deletion flow.
- Shared account deletion UI section.
- Account deletion service and shared local logout cleanup.
- Profile and admin screen integration.
- Supabase Edge Function for trusted account deletion.
- SQL migration/RPC used by the Edge Function.
- Focused tests for localization, services, widgets, and Edge Function safety checks.

Do not intentionally bring unrelated changes from other branches.

## Recommended Approach

Apply the diff from `feature/account-deletion` to the current `main` working tree, then inspect the resulting diff before verification.

This keeps the current `main` branch as the testing base while giving tight control over the files moved across. It also avoids a broad merge and avoids replaying each feature-branch commit one by one.

## Verification

After transfer:

- Review `git diff --name-status` and the relevant code diffs.
- Run Flutter analysis for the touched Dart files.
- Run focused account deletion tests.
- Report any environment-dependent failures separately from code failures.

## Risks

- `main` may have changed since the feature branch was created, causing conflicts in profile/admin screens or localization tests.
- Supabase Edge Function behavior cannot be fully verified locally without deployment and disposable test users.
- The transfer must preserve the `super_admin` exclusion added at the tip of `feature/account-deletion`.
