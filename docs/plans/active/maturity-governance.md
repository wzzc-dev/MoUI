# Plan: Governance truth — docs, readiness, and validators

- **Status**: active
- **Goal**: Make every platform/status statement match the recorded evidence
  and add checks that prevent the next drift.
- **Non-goals**: generated prose for every page, rewriting historical release
  notes, changing product-class decisions.

## Sync

1. `docs/feature-status-dashboard.md` removes the stale Android/iOS/WeChat
   experimental paragraph and the pending-device sentence.
2. `docs/android-support.md` and `docs/ios-support.md` open with the committed
   class and evidence boundary.
3. `docs/release-readiness.md`, `docs/feature-proof-matrix.md`, and the zh-Hans
   platform pages match `checks/platforms/*.json`.
4. `checks/compatibility-policy.json` `currentReleaseLine` moves to 0.6.x;
   `docs/compatibility-policy.md` covers 0.6.
5. `moui/backend/android/android_backend.mbt` and
   `moui/backend/ios/ios_backend.mbt` readiness reports match the platform
   matrix.
6. `docs/plans/README.md` points at `runtime/test_support`; completed plan
   checkboxes are updated.

## Validators

1. `scripts/validate-platform-claims.mjs`: compare English/zh-Hans prose
   claims against `checks/platform-matrix.json`; skip generated markers.
2. `validate-ecosystem-metadata.mjs`: `currentReleaseLine` must equal the
   module manifest line.
3. `validate-guidance-consistency`: zh-Hans platform pages must agree with the
   English pages.
4. `validate-active-plan-bookkeeping.mjs`: active plans whose acceptance boxes
   are all unchecked while referenced files exist produce a warning; release
   checklists require zero.
5. Add all new checks to the `pr` profile.

## Acceptance

- [ ] No committed page says Android/iOS are experimental.
- [ ] Backend readiness flags agree with `checks/platforms/*.json`.
- [ ] The new validators fail on a deliberately reintroduced contradiction.
- [ ] `sh scripts/check.sh --profile pr` passes.

## Decision log

| Date | Decision |
|---|---|
| 2026-11-10 | Prose is checked against the matrix, not hand-maintained in isolation |
| 2026-11-10 | New validators run in `pr`, not only nightly |

## Progress

| Date | Note |
|---|---|
| 2026-11-10 | Plan created; first pass fixes the dashboard, support pages, and backend flags. |
| 2026-11-10 | English + zh-Hans platform claims, backend readiness, compatibility line, and plan bookkeeping synced; guidance/doc-maintenance/API/platform validators pass. |
| 2026-11-10 | Claims drift check landed in `validate_portfolio_governance`: live Android/iOS lines may not say `experimental`/`ready=false`, and historical release notes are skipped. The validator caught and we fixed the last zh-Hans architecture and WeChat wording drift. |
