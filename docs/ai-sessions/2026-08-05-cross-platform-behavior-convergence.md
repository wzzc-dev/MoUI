# 2026-08-05: Cross-platform behavior convergence

- **Agent**: Codex
- **Goal**: Remove platform similarity budgets and make shared services,
  window coordination, redraw, and embedded lifecycle single-owner behavior.
- **Outcome**: Success for code and repository gates; manual window publication
  and matching-device evidence remain owner-operated release steps.

## Summary

Deleted file-similarity accounting and replaced it with a structural Platform
Bridge boundary gate. Desktop service routing/filesystem behavior now lives in
`moui/backend/common/desktop`; desktop resize/request/redraw behavior
is `WindowCoordinator` in `moui/backend/common`;
Android/iOS/HarmonyOS
logical lifecycle lives in `EmbeddedWindowCoordinator` in
`moui/backend/common`,
while `wzzc-dev/window/internal/embedded_dispatch` is physical callback dispatch;
post-callback mobile runtime assembly remains in `moui/backend/common/embedded`. Mobile service
request ids, FIFO pending drain, one-shot completion, and dispose cancellation
live in `host_services_embedded`, which is reachable only through that runtime.

## Changes Made

| Surface | Change | Reason |
|---|---|---|
| Validators | Removed similarity source, baseline JSON, old tool/wrapper; added budget-free boundary validator | Ownership is structural, not a token score |
| Desktop backends | Shared service router, request/resize dispatch, host-event routing, and redraw state machine | One behavior implementation |
| Window mobile hosts | Added pure command/effect kernel and retained platform payload decoding/effect application | Preserve native ABI while removing three lifecycle states |
| MoUI mobile backends | Centralized surface retry/recreation, renderer kit, session, redraw, and IME | Keep post-callback lifecycle in one package |
| Host service layers | Flattened `host_services_desktop` and `host_services_embedded`; split embedded runtime messages, IME, semantics, platform views, transport, and lifecycle files | Keep neutral contracts shared while preserving direct desktop and callback mobile execution models |

## Key Decisions

- Similarity thresholds, allowlists, expiration dates, and accepted duplication
  are not architecture tools; shared behavior moves to its owner immediately.
- `window/core` remains neutral. The kernel is an internal sibling importing
  only `window/core` and `window/dpi`.
- Platform files retain nominal type adaptation, raw payload decoding, native
  composition, and ABI-specific FFI only.

## Validation

```sh
moon info
sh scripts/window-hosted-hostsim-smoke.sh
node scripts/platform-services-check.mjs
sh scripts/check.sh --profile pr
sh scripts/check.sh --profile platform
```

Focused results include runtime 95/95, macOS 26/26, Windows 24/24, Linux
25/25, Web 39/39, embedded runtime 10/10, window kernel 6/6, and window mobile
hosts 5/5, 6/6, 5/5. Local window macOS tests pass 110/110. Published-package
macOS smoke could not run because the pinned `0.5.4-0.1.4` archive does not
contain `scripts/check_moui_macos_smoke.sh`.

## Follow-Up

- [ ] Repository owner publishes the changed `wzzc-dev/window`, updates all
  consumer pins, and runs the published-package desktop smoke.
- [ ] Matching-device Android/iOS/HarmonyOS evidence remains required before
  changing experimental readiness claims.

## Promote

- [x] Durable ownership facts added to `memories/repo/`.
- [x] ADR 0020 amendment records behavior uniqueness.
- [x] Multi-package release handoff remains in the active plan.
- [x] Canonical architecture, invariant, testing, and window-hosted docs updated.
