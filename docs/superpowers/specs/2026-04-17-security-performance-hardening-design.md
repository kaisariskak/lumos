# Security And Performance Hardening Design

## Goal

Perform a balanced hardening pass across the Flutter client and Supabase layer to reduce the most meaningful security risks and remove avoidable performance overhead, without large-scale refactoring or behavior changes in unrelated screens.

## Scope

This pass will cover:

- Supabase SQL and RLS hardening for invite codes and related constraints.
- Local PIN storage hardening and basic brute-force resistance.
- Authentication and profile-loading flow cleanup in the Flutter client.
- Repository-level query tightening, normalization, and small round-trip reductions.

This pass will not cover:

- Re-architecting authentication around RPC or Edge Functions.
- Full replacement of local PIN storage with platform secure enclave storage.
- Broad UI redesigns or unrelated feature work.

## Current Risks

### Server-side data access

The current `ibadat_invite_codes` policies allow any authenticated user to read invite codes and perform updates too broadly. This makes invite-code disclosure and misuse much easier than intended, and server-side access control is the highest-priority risk because client-side checks cannot compensate for weak RLS.

### Local PIN storage

The PIN is stored as a plain SHA-256 hash in shared preferences. That is weak against offline guessing if the local store is exposed, and there is no throttling for repeated failed attempts.

### Auth flow cost and instability

`AuthGate` performs repeated profile fetches in a few branches and mixes state transitions that can lead to redundant requests or stale flags. This is not only slower on app entry, but also makes failure handling harder to reason about.

### Query shape and normalization

Several repository methods use broad `select()` calls when narrower selections are sufficient, and normalization of values such as email/code is repeated inconsistently. This increases payload size and leaves more room for edge-case bugs.

## Options Considered

### Option 1: Minimal patch set

Patch only the most severe RLS issues, add a stronger PIN format, and trim a few obvious queries.

Pros:

- Fastest to implement.
- Lowest chance of colliding with active feature work.

Cons:

- Leaves auth-flow inefficiencies and some resilience issues in place.

### Option 2: Balanced hardening

Fix the server-side access risks, upgrade PIN handling with migration support, and streamline the client auth/profile flow plus repository queries.

Pros:

- Best security-to-change-size ratio.
- Meaningful performance improvement in common flows.
- Keeps changes local and reviewable.

Cons:

- Slightly larger diff than a minimal patch.

### Option 3: Deep backend redesign

Move sensitive invite-code operations behind RPC/functions and introduce stronger server-managed workflows.

Pros:

- Strongest long-term server-side model.

Cons:

- Too large for the current pass.
- Higher delivery risk in a dirty worktree.

## Chosen Approach

Use Option 2.

The implementation should prioritize closing the server-side invite-code exposure, then harden PIN storage, then streamline auth/profile loading and repository queries. This sequence reduces risk first while keeping the runtime behavior stable.

## Design

### 1. Supabase SQL and RLS hardening

Create a new migration that tightens `ibadat_invite_codes`:

- Restrict `SELECT` so users do not get blanket visibility into all invite codes.
- Restrict `UPDATE` so invite codes can only be marked used in the intended scenarios instead of by any authenticated caller.
- Add or validate defensive constraints for `role_type`, expiration semantics, and useful lookup indexes.
- Preserve existing app flows where possible, but prefer server-side enforcement over client trust.

Because the app currently validates invite codes from the client, the policy update will be designed to still support code entry while minimizing exposure. If direct validation still requires broader read access than acceptable, the code path should be adjusted toward a narrower query pattern within the current repository design.

### 2. Versioned PIN hashing with migration

Upgrade `PinService` to use a versioned stored format with:

- A random per-PIN salt.
- A stronger derived hash than the current unsalted SHA-256 flow.
- Backward-compatible verification of existing stored PINs.
- Automatic migration of legacy hashes to the new format after successful verification.

Add a lightweight local attempt-throttling mechanism using shared preferences metadata:

- Count recent failed attempts.
- Introduce a short lockout window after repeated failures.
- Keep the UX simple so existing `PinScreen` integration stays stable.

This will not be framed as a full secure-storage redesign. The intent is to materially raise the cost of offline guessing and local brute force while keeping the existing app structure intact.

### 3. Auth flow cleanup

Refine `AuthGate` to:

- Reduce duplicate profile fetches.
- Normalize state transitions for signed-in, signed-out, invite-code, and PIN-required states.
- Reset error and visibility flags consistently before and after load attempts.
- Avoid unnecessary follow-up queries when enough information is already available.

The goal is not a full state-machine rewrite. The goal is a smaller, safer async flow with fewer redundant network calls and clearer failure recovery.

### 4. Repository tightening

Update the relevant repositories to:

- Normalize email and invite-code input in one place per operation.
- Use narrower selected columns where full rows are not needed.
- Add small guard checks where invalid input should fail fast.
- Reduce extra read-after-write fetches where the returned inserted/updated row is already sufficient.

This will focus on `ProfileRepository`, `InviteCodeRepository`, and `IbadatReportRepository`, plus any directly affected model parsing.

## Error Handling

- Preserve user-facing error messages unless a change is required for correctness.
- Avoid leaking server implementation details in auth errors when a generic localized message is sufficient.
- Keep failure states recoverable with retry or logout paths already present in the UI.

## Testing Strategy

The verification pass should include:

- Flutter static analysis.
- Existing automated tests that still apply.
- Targeted manual reasoning for PIN migration and invite-code access rules.

If SQL cannot be executed locally in this environment, the migration will still be written and called out as needing application in Supabase before the hardening is fully effective.

## Risks And Mitigations

- Existing invite-code flow may rely on broad reads.
  Mitigation: change policies and repository usage together so the client still performs the intended validation path.

- Users with legacy PIN hashes could be locked out if migration is wrong.
  Mitigation: keep dual verification support until a successful login migrates the value.

- Dirty worktree increases merge risk.
  Mitigation: keep edits targeted and avoid unrelated files.

## Success Criteria

The hardening pass is successful when:

- Invite-code access is no longer broadly exposed through permissive RLS.
- PIN verification supports legacy values while storing stronger new values.
- Sign-in and profile bootstrap use fewer redundant calls and clearer state handling.
- Repository methods avoid obvious over-fetching and repeated normalization.
- The Flutter project still passes available verification steps after the code changes.
