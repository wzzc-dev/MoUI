# 0021: Mobile platforms downgraded to experimental product class

- **Date**: 2026-08-02
- **Status**: Accepted
- **Deciders**: Agent-assisted (wzzc-dev)
- **Related**: ADR 0011 (superseded in part), `docs/platform-readiness-declaration.md`, `docs/architecture-map.md`

## Context

ADR 0011 (2026-07-16) classified Android / iOS / HarmonyOS as `runtime_partial`
and changed the Skia mobile preflight `runtime_status` from
`experimental-scaffold` to `runtime_partial`, defining mobile `ready: true` as
"window-hosted path usable for development and demos" (aligned with Linux host
usability).

Since then, the four mobile-adjacent platforms — Android, iOS, HarmonyOS, and
WeChat Mini Program — have not accumulated matching-device presenter/service
evidence. `checks/platforms/{android,ios,harmonyos,wechat}.json` all report
`sourceBuild=partial`, `rendererL2=partial`, `runtimeL3=partial`, and
`actualPresenterRoute=unverified` (as of 2026-08-01). The `runtime_partial`
claim ("usable for development/demonstration") overstates what can be verified
today, and it cannot be validated by the default daily CI on any of these
platforms.

## Decision

1. Add a new product class **`experimental`**, deliberately below
   `runtime_partial`, and assign it to **Android, iOS, HarmonyOS, and WeChat
   Mini Program** in the product_class matrix
   (`docs/platform-readiness-declaration.md`).
2. Mobile `experimental` semantics: code paths compile and host-sim tests
   pass, but **no** development/demonstration usability or product commitment
   is made without matching-device presenter/service evidence.
3. Flip mobile backend `readiness.ready` from `true` to `false` and set
   `readiness.status` to `"experimental"` in
   `moui/backend/{android,ios,harmonyos,wechat}/*_backend.mbt`, with
   `blocked_by` naming the `experimental` product class as the first blocker.
4. Change the Skia mobile preflight `runtime_status` from `runtime_partial`
   to `experimental` in `moui/backend/{android,ios,harmonyos}/skia/*_provider.mbt`.
5. Keep the host path, host-sim coverage, `wzzc-dev/window` templates, and the
   capability/service wiring intact. The downgrade is about the **claim**, not
   the code: the backends and IME/clipboard/a11y channels exist; the gap is
   the evidence loop and promotion.
6. The route labels in `docs/architecture.md` / `docs/architecture-map.md`
   and the Showcase platform status display use `experimental`.

## Options Considered

### Option A: Keep `runtime_partial`, add device evidence

- Pros: no claim change; aligned with ADR 0011 trajectory
- Cons: evidence does not exist today; `ready=true` remains an unverifiable
  promise on four platforms that default CI cannot exercise

### Option B: Downgrade to `experimental` with `ready=false` (chosen)

- Pros: honest; removes the unverifiable "usable for development/demos" claim;
  matches the actual evidence state; matches the WGPU-diagnostic precedent of
  being explicit about non-mainline status
- Cons: reverses part of ADR 0011; docs, tests, and code strings must update;
  Showcase progress indicators look less rosy

### Option C: Drop mobile platforms from the matrix entirely

- Pros: simplest
- Cons: erases the real host-sim coverage and the window-hosted route that
  exists; would mislead contributors into thinking the backends are absent

## Rationale

Option B stops claiming what cannot be verified. The four platforms are
structurally present (templates, adapters, host-sim tests, packaging), but
their `runtime_partial` label promised development usability that requires
matching-device evidence no one has recorded. `experimental` keeps the code
visible and usable as a starting point while removing the over-claim. This
mirrors how Native WGPU is labeled `diagnostic`: non-mainline statuses are
named explicitly rather than blurred.

## Consequences

- Callers must treat `ready=false` on mobile backends as "no usability
  commitment"; apps should not claim Android/iOS/HarmonyOS/WeChat support for
  development or demonstration without recording matching-device evidence.
- Guidance, README, feature dashboard, architecture routes, Showcase, and the
  support docs share one `experimental` product_class table
  (`docs/platform-readiness-declaration.md`).
- Follow-up: re-promote to `runtime_partial` (or higher) only after
  matching-device presenter/service evidence is recorded in
  `checks/platforms/*.json` and host-sim smoke is re-run with `--require-passed`.
- ADR 0011 remains accepted but its product-class decision is superseded in
  part by this record; the preflight `runtime_status` change in ADR 0011
  point 5 is reverted by decision 4 above.

## Agent Notes

- **Session context**: Architecture review asked for a mobile-platform
  downgrade; user instruction: "移动4平台降级为实验性".
- **Agent model**: AtomCode (deepseek-v4-flash)
- **Key prompt or instruction**: Downgrade the four mobile platforms
  (android/ios/harmonyos/wechat) from `runtime_partial` to experimental.
- **Validation**: `moon test moui/backend/{android,ios,harmonyos,wechat}`
  plus the repo pre-push validators (maintenance baseline, API surface,
  guidance consistency).

## References

- `docs/platform-readiness-declaration.md` (product_class matrix)
- `docs/architecture-map.md` (product classification table)
- `checks/platforms/{android,ios,harmonyos,wechat}.json` (evidence state)
- ADR 0011: Platform product class and mobile readiness
