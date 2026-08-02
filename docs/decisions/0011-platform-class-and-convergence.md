# ADR 0011-0021: Platform Class and Convergence (merged)

> 原编号保留为小节锚点: 0011-platform-product-class-and-mobile-readiness,0020-platform-adapter-convergence-and-duplication-budget,0021-mobile-platform-experimental-downgrade

---

## 0011: Platform product class and mobile readiness semantics

- **Date**: 2026-07-16
- **Status**: Accepted (product-class decision superseded in part by ADR 0021 on 2026-08-02)
- **Deciders**: Agent-assisted (wzzc-dev)
- **Related**: `docs/platform-readiness-declaration.md`, ADR 0006, ADR 0010, ADR 0021

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

---

## 0020: Platform Bridge convergence and duplication budget

- **Date**: 2026-07-28, amended 2026-07-29, amended 2026-08-01
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

`moui/backend/platform_bridge` is the single owner of the platform-to-neutral
host bridge. It imports only `moui/core`, `moui/backend/host`, and `window`
value types. There is no compatibility package at the previous path.

The bridge owns only these cross-platform operations:

- Close, focus, resize, scale, and redraw conversion to `HostEvent`.
- Surface attach/detach, metrics, and lifecycle state.
- Logical-coordinate normalization.

Platform packages retain native pointer, keyboard, IME, drag-and-drop, and
modifier decoding, platform capability declarations, pacing, and host wiring.
This preserves the native payload boundary while requiring every applicable
desktop, Web, Android, iOS, and HarmonyOS backend to invoke the bridge after
it has decoded a neutral lifecycle event.

WeChat is included in the capability inventory and duplication scan as the
`direct-canvas-callback` exception. It must not fabricate a `WindowEvent`
dependency; the validator instead confirms that its Canvas lifecycle does not
redefine bridge responsibilities.

The enforced PR gate is a MoonBit tool at
`tools/moui/validate_platform_adapter_duplication`, kept reachable through the
thin Node wrapper `scripts/validate-platform-adapter-duplication.mjs`. Its
schema-v2 baseline declares the bridge modules, normalization token budgets,
and only justified native exceptions. The wrapper passes the current UTC date;
expired `allowUntil` entries fail, as do missing bridge imports/uses, bridge
helper redefinitions, duplicated normalization over budget, and invalid WeChat
usage.

### Consequences

- `platform_bridge` has a small, testable neutral contract and no renderer or
  runtime ownership.
- New applicable platform hosts must import and use the bridge rather than
  recreate lifecycle conversion helpers.
- A genuine platform-specific duplication exception needs a baseline allowlist
  reason and an expiry date; the budget may otherwise only shrink or remain
  stable.
- Bridge behavior is covered by `moon test moui/backend/platform_bridge
  --target native`; the validator has its own MoonBit fixture tests and is part
  of the PR profile.

### Amendment (2026-08-01): window-host coordination and file-level similarity gate

The window-lifecycle state that was previously re-implemented per backend now
lives in `WindowHostCoordinator` (moui/runtime, with `WindowSurfaceActions`
per-window projections). macOS/Windows/Linux and the Web backend all delegate
window records, runtime slots, platform-window maps, surface attachment,
redraw/IME/close coordination, and host-event dispatch to it; embedded-runtime
backends share `moui/backend/internal/embedded_runtime_backend`
(`HostedWindowBackend`/`HostedRuntimeSession`), leaving each platform's
`window_hosted.mbt` as a thin shell.

The api-surface validator gains a file-level mirror similarity gate
(`validate_platform_file_similarity` in
`tools/moui/validate_api_surface/platform_file_similarity.mbt`): platform
identifiers are normalized to a placeholder token, mirror file pairs scoring
above 80% similarity are rejected unless registered in
`platform_file_similarity_budgets` with a reason and a per-pair budget row.
Registered pairs include the Wave 2 shared embedded-runtime shells, renderer
provider adapter shells, and pre-existing duplicate helper files
(`menu_helpers`, `file_dialog_helpers`); new platform files must fold shared
logic into the coordinator/shared packages instead of copying it.

### Rejected alternatives

- Putting platform logic in `backend/host` would create host knowledge of
  concrete platforms and violates the host-contract boundary.
- Translating raw pointer/keyboard/IME/drag payloads in the bridge would erase
  necessary platform semantics.
- Leaving each backend to maintain equivalent lifecycle helpers would make the
  duplication budget unenforceable.

### References

- `docs/invariants.md`
- `docs/architecture-map.md`
- `checks/platform-adapter-duplication-baseline.json`

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

