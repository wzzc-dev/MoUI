# Golden Principles

Short, opinionated rules optimized for **future agent runs**. Prefer encoding
these into validators (`tools/moui/*`, `checks/`) over restating them in prose.

When a principle is mechanical, point `docs/invariants.md` Detection at the
script. When it is still taste, keep it here and clear AI residue in small PRs.

## Boundaries

1. **One owning package per capability** — extend the owner; do not fork helpers into examples or sibling packages.
2. **Parse at boundaries** — host payloads, manifests, and FFI results are validated or typed at the edge; no YOLO field poking deep in app logic.
3. **App packages stay app-safe** — only `wzzc-dev/moui`, domain facades, and `views` (see P8/P9).
4. **Platform entrypoints are wiring** — no product state machines in `*_skia` / `web_wasm`.
5. **Renderers consume `DrawCommand`** — no view-constructor dependency in reverse.

## Mainline honesty

6. **Native Skia is mainline; native WGPU is experimental (engineering gate `diagnostic`)** — do not soft-reclassify in docs or examples; do not present WGPU as product-capable.
7. **Mobile claims need evidence grades** — `passed` / `partial` / `failed` only via manifests; packaging ≠ runtime proof.
8. **Embedded runtime backends are canonical for Android/iOS/HarmonyOS** — `wzzc-dev/window` owns platform lifecycle, surface, and input; examples keep only thin MoonBit entrypoints.

## Agent-operable repo

9. **Maps over manuals** — `AGENTS.md` stays a directory; depth lives under `docs/` with `INDEX.md` links.
10. **Single source of truth** — invariants, validation policy, and package boundary each have one canonical file; other files link.
11. **Smallest useful check first** — path-local `moon test` / validators before `daily` / `platform`.
12. **Fix hints in tools** — validator failures should name the invariant and the fix doc anchor.
13. **Plans for multi-package work** — `docs/plans/active/` before large coding loops.
14. **Promote discoveries** — session logs → `memories/repo/` (short) or ADR (decisions); do not leave critical rules only in chat.

## Residue control

15. **Prefer shared utilities** already in-tree over new one-off helpers.
16. **No compatibility shims** for removed APIs unless explicitly requested.
17. **Garbage-collect weekly patterns** — duplicated helpers, stale docs, forbidden imports: small automated or agent-driven PRs, not quarterly rewrites.

## Structure triggers

Pre-written review conditions: when a trigger fires, the named review happens
before the growth lands — do not pre-pay the structure, do not sleep through
the signal (plan `cohesion-governance-convergence`, D1/D2).

18. **`moui/core` package split** — trigger: at least two independent signals
    fire: `pkg.generated.mbti` exceeds ~3.5k lines; public declarations exceed
    ~1,200; importing package manifests exceed ~180; a measured change-coupling
    or compile-critical-path review shows `core` dominates. Action: split by
    domain into `core/<domain>` subpackages with the root facade re-exporting
    (`pub using`); consumers keep `wzzc-dev/moui/core`. At the 0.4.0 window the
    measured values are 2,735 mbti lines, 1,159 public declarations, and 146
    importing manifests, so the split is not triggered; re-measure at each
    release window. Until then file-level organization is the contract.
19. **Host orchestration seam** — **actioned by ADR 0059**: `HostRuntimeDriver`,
    `AppBuilder`/`run_app`, `RedrawScheduler`, and the host event adapters live
    in `moui/apphost`; `moui/runtime` production imports only `moui/core`.
    Mechanization: `checks/backend-common-ownership.json` requires apphost and
    forbids runtime in every `backend/common` owner, and
    `validate-host-import-baseline.mjs` keeps root `backend` free of apphost.
    Re-open only if a new host package needs a second orchestration layer or
    apphost itself starts owning tree/state.
20. **MoonBit toolchain upgrade checklist** — on every moon version bump, re-read
    the reopen conditions in `docs/plans/debt/`: the three ViewNode-trait limits
    (`viewnode-trait-decomposition.md` — bare-`T` impl target, single parent
    trait, trait-object narrowing) and the manual `Eq+Hash` key structs
    introduced where derives were missing (Skia shaping/layer caches). Upgrade
    any workaround the new compiler retires; note it in the debt note.
21. **New-renderer touchpoints** — adding a renderer module is catalog-driven:
    `checks/release-modules.json` + capability report + composition root;
    validators derive their closed sets from the catalog (no validator edits).
    Checklist owner: `docs/renderer-capability-report.md`.

## Related

- Constraints table: `docs/invariants.md`
- Mechanization batch1: `docs/plans/done/harness-mechanize-invariants-batch1.md`
- Agent workflow: `docs/ai-collaboration.md`
