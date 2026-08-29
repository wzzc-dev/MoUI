# ADR 0011-0021: Platform Class and Convergence (merged)

> 原编号保留为小节锚点: 0011-platform-product-class-and-mobile-readiness,0020-platform-bridge-convergence,0021-mobile-platform-experimental-downgrade

---

## 0011: Platform product class and mobile readiness semantics

- **Date**: 2026-07-16
- **Status**: Accepted (product-class decision superseded in part by ADR 0021 on 2026-08-02 and by ADR 0031 on 2026-08-29)
- **Deciders**: Agent-assisted (wzzc-dev)
- **Related**: `docs/platform-readiness-declaration.md`, ADR 0006, ADR 0010, ADR 0021, ADR 0031

### Context

Embedded runtime backends reported `ready: false` with blockers such as “lifecycle glue
is not wired” and Skia preflight `runtime_status=experimental-scaffold`, while
embedded runtime backends, `EmbedderHostChannel` services, and host-sim coverage
already existed. That binary narrative was both too harsh
(“completely broken”) and too easy to misread against Linux, where `ready: true`
means host usability, not full L3 green.

Docs, Gallery labels, and capability matrices also mixed packaging success,
runtime evidence, and product promotion.

### Decision

1. Publish an explicit **product_class** matrix:
   - macOS / Web: `committed`
   - Windows / Linux: `committed_with_gaps`
   - Android / iOS / HarmonyOS: `runtime_partial`
2. Redefine mobile `ready: true` as **window-hosted path usable for
   development and demos**, aligned with Linux host usability.
3. Add mobile `readiness.status = "runtime_partial"` for evidence class.
4. Set capability/service flags from **code wiring**, not only from complete
   matching-device promotion evidence.
5. Change Skia mobile preflight `runtime_status` from `experimental-scaffold`
   to `runtime_partial`.
6. Do **not** raise `checks/platforms/*.json` L3/presenter fields without new
   evidence; do **not** claim GPU seven-gate promotion.

### Options Considered

### Option A: Keep `ready: false` and only rewrite strings

- Pros: smaller semantic change
- Cons: still false-negative vs Linux; callers keep treating mobile as unusable

### Option B: Multi-state readiness + `ready=true` for usable host (chosen)

- Pros: matches reality; separates usable vs promoted
- Cons: public struct gains `status`; tests and docs must update

### Option C: Flip mobile to product-complete

- Pros: simplest marketing story
- Cons: contradicts matching-device evidence gaps, signing, presenter verification

### Rationale

Option B stops two failure modes: claiming six-platform product readiness, and
claiming mobile is empty scaffold. Capability truth tracks wiring; promotion
truth stays in checks JSON, smoke manifests, and product_class docs.

### Consequences

- Callers must not treat `ready=true` as “L3 passed / seven-gate claimed.”
- Guidance, README, Gallery, and support docs share one product_class table.
- Follow-up: matching-device re-smokes and signed HarmonyOS full suite before any
  product_class promotion.

### Amendment (2026-08-02, ADR 0021)

ADR 0021 downgrades Android / iOS / HarmonyOS / WeChat Mini Program from
`runtime_partial` to **`experimental`** (`ready=false`): the code paths compile
and host-sim tests pass, but no development/demonstration usability or product
commitment is made without matching-device evidence. Decision points 1, 2, 3,
and 5 above are superseded in part by ADR 0021. The capability/service wiring
and host-sim coverage this ADR describes remain intact.

### Amendment (2026-08-29, ADR 0031)

ADR 0031 promotes Windows from **`committed_with_gaps`** to
**`committed`**: the matching-host Win32 runtime smoke transcript and the
Showcase first-frame evidence were captured on 2026-08-29, raising
`checks/platforms/windows.json` `runtimeL3` to `passed`. The `committed_with_gaps`
classification for Windows in decision point 1 above is superseded; Linux
remains `committed_with_gaps` and mobile remains `experimental`. See ADR 0031
for the evidence chain and the repaired evidence-loop defects.

---

## 0020: Platform Bridge convergence

- **Date**: 2026-07-28, amended 2026-07-29, 2026-08-01, 2026-08-05
- **Status**: Accepted
- **Related**: ADR 0011 (platform product class), ADR 0018 (host contract
  split), ADR 0019 (renderer providers), invariants P5/M6

### Context

Native hosts and embedded hosts all translate a small set of platform-neutral
window lifecycle facts. Historically, copy-pasted resize, scale, focus, close,
redraw, surface-lifecycle, and coordinate-normalization helpers made that seam
drift while disguising it as native-platform code. The shared owner must not
decode native input or gain a reverse dependency on a platform package.

### Decision

`moui/backend/common` is the single owner of the platform-to-neutral
host bridge. It imports only `moui/core`, `moui/backend`, and `window`
value types. There is no compatibility package at the previous path.

The bridge owns only these cross-platform operations:

- Close, focus, resize, scale, and redraw conversion to `Event`.
- Surface attach/detach, metrics, and lifecycle state.
- Logical-coordinate normalization.

Platform packages retain native pointer, keyboard, IME, drag-and-drop, and
modifier decoding, platform capability declarations, pacing, and host wiring.
This preserves the native payload boundary while requiring every applicable
desktop, Web, Android, iOS, and HarmonyOS backend to invoke the bridge after
it has decoded a neutral lifecycle event.

WeChat is included in the capability inventory and boundary validation as the
`direct-canvas-callback` exception. It must not fabricate a `WindowEvent`
dependency; the validator instead confirms that its Canvas lifecycle does not
redefine bridge responsibilities.

The enforced PR gate is the MoonBit tool
`tools/moui/validate_backend_common_boundary`, reached through the thin Node
wrapper `scripts/validate-backend-common-boundary.mjs`. It checks direct bridge
use by desktop/Web backends, shared embedded-runtime use by mobile backends,
bridge-helper redefinitions, and the fixed WeChat direct-canvas boundary. It
does not measure file similarity and has no threshold, budget, allowlist, or
expiry date.

### Consequences

- `platform_bridge` has a small, testable neutral contract and no renderer or
  runtime ownership.
- New applicable platform hosts must import and use the bridge rather than
  recreate lifecycle conversion helpers.
- Shared behavior found in platform packages must move to its owning shared
  package. Nominal type adaptation, native payload decode, and ABI-specific FFI
  symbols remain platform-local.
- Bridge behavior is covered by `moon test moui/backend/common
  --target native`; the validator has its own MoonBit fixture tests and is part
  of the PR profile.

### Amendment (2026-08-01): window-host coordination

The window-lifecycle state that was previously re-implemented per backend now
lived in the then-current `WindowCoordinator` (formerly `moui/runtime`, with `WindowSurfaceActions`
per-window projections). macOS/Windows/Linux and the Web backend all delegate
window records, runtime slots, platform-window maps, surface attachment,
redraw/IME/close coordination, and host-event dispatch to it; embedded-runtime
backends share `moui/backend/common/embedded`
(`HostedWindowBackend`/`HostedRuntimeSession`), leaving each platform's
`window_hosted.mbt` as a thin shell.

### Amendment (2026-08-05): unified window-host owner (ADR 0024)

The 2026-08-01 placement is superseded by ADR 0024. The desktop/Web
`WindowCoordinator`, embedded `EmbeddedWindowCoordinator`, and shared
`FrameCoordinator` now live in `moui/backend/common`.
`moui/runtime` retains `AppRuntime`, scene resolution, and `HostRuntimeDriver`
only. `wzzc-dev/window/internal/embedded_dispatch` dispatches physical
callbacks without logical phase, generation, primary-window, or exit state;
embedded sessions and transport remain in `embedded_runtime`.

### Amendment (2026-08-05): behavior uniqueness replaces similarity accounting

File similarity and duplication-budget enforcement are removed. Similarity is
not a sound proxy for ownership: nominal adapters can be intentionally alike,
while behaviorally duplicated state machines can evade token thresholds. The
acceptance rule is now structural: desktop service routing lives in
`moui/backend/common/desktop`; embedded pending request/completion
state lives in `moui/backend/common/embedded/services` and is consumed
only by `moui/backend/common/embedded`; desktop request/resize/redraw
state lives in `WindowCoordinator` in
`moui/backend/common`; Android/iOS/HarmonyOS logical lifecycle
and surface state live in `EmbeddedWindowCoordinator` in that package,
while `wzzc-dev/window/internal/embedded_dispatch` is physical callback
dispatch; post-callback mobile session/renderer/redraw/IME/semantics/
platform-view/transport behavior lives in `embedded_runtime`.

### Rejected alternatives

- Putting platform logic in `backend` would create host knowledge of
  concrete platforms and violates the host-contract boundary.
- Translating raw pointer/keyboard/IME/drag payloads in the bridge would erase
  necessary platform semantics.
- Leaving each backend to maintain equivalent lifecycle helpers would preserve
  multiple behavioral owners and is rejected even when files are textually
  dissimilar.

### References

- `docs/invariants.md`
- `docs/architecture-map.md`
- `tools/moui/validate_backend_common_boundary`

---

## 0021: Mobile platforms downgraded to experimental product class

- **Date**: 2026-08-02
- **Status**: Accepted
- **Related**: ADR 0011 (superseded in part), `docs/platform-readiness-declaration.md`

### Context

ADR 0011 classified Android / iOS / HarmonyOS as `runtime_partial` and defined
mobile `ready: true` as "usable for development and demos". Since then, none of
the four mobile-adjacent platforms (Android, iOS, HarmonyOS, WeChat Mini
Program) has accumulated matching-device presenter/service evidence —
`checks/platforms/{android,ios,harmonyos,wechat}.json` all report
`partial`/`unverified` as of 2026-08-01, and default CI cannot validate them.
The `runtime_partial` claim overstates what is verifiable today.

### Decision

1. Add a new product class **`experimental`**, deliberately below
   `runtime_partial`, and assign it to **Android, iOS, HarmonyOS, and WeChat
   Mini Program** in the product_class matrix.
2. Semantics: code paths compile and host-sim tests pass, but **no**
   development/demonstration usability or product commitment is made without
   matching-device presenter/service evidence.
3. Flip mobile backend `readiness.ready` to `false` and set `status` to
   `"experimental"` in `moui/backend/{android,ios,harmonyos,wechat}`.
4. Change Skia mobile preflight `runtime_status` to `experimental` in
   `moui/backend/{android,ios,harmonyos}/skia/*_provider.mbt`.
5. Keep host path, host-sim coverage, `wzzc-dev/window` templates, and
   capability/service wiring intact — the downgrade is about the **claim**,
   not the code.

### Rationale

Option B of ADR 0011 ("usable host") is reversed because the evidence it
depends on does not exist: `ready=true` is an unverifiable promise on four
platforms default CI cannot exercise. `experimental` keeps the code visible
and usable as a starting point while removing the over-claim, mirroring how
WGPU is labeled non-mainline.

### Consequences

- Callers must treat mobile `ready=false` as "no usability commitment".
- Guidance, README, feature dashboard, architecture routes, Showcase, and
  support docs share one `experimental` table.
- Re-promotion requires matching-device evidence in `checks/platforms/*.json`
  and host-sim smoke re-run with `--require-passed`.
- ADR 0011 remains accepted; its product-class decisions (points 1, 2, 3, 5)
  are superseded in part by this record.
