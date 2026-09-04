# Plan: View framework remediation batch (declaration keys, flex tight-fit, text caching)

- **Status:** active
- **RFC:** none (no invariant break; adds gate P17 and extends `ViewLayoutResult`
  with a defaulted field)
- **ADR:** [0034](../../decisions/0034-viewnode-declaration-coverage-gate.md),
  [0035](../../decisions/0035-tight-fit-child-remeasure.md)
- **Goal:** Remove the audit-identified weak points in the view framework:
  hand-maintained `declaration()` key coverage, weighted flex children never
  re-measured to their final frame, duplicate text shaping in the Skia
  renderer, unquantified `View::map` rebuild cost, and silent Effect-key
  supersession.
- **Non-goals:** splitting the `ViewNode` trait (blocked on MoonBit blanket
  impls — debt), persistent-structure view-state slots (debt), migrating
  `RendererSession` from the closure record to a trait (debt), full
  `View::map` fusion behind a type-erased map chain, any renderer-protocol or
  host-contract change.

## Public contract

- `moui/core`: `ViewLayoutResult` gains `child_frames_tight : Bool`;
  `ViewLayoutResult::new` accepts `child_frames_tight?` defaulting to `false`,
  so every existing construction site compiles unchanged (ADR 0035).
- New open-ended gate surface only: new validator package
  `tools/moui/validate_viewnode_declaration_coverage` (no framework API).
- No changes to `ViewNode`, `View`, `Program`, `Effect`, `Subscription`,
  `RendererProvider`/`RendererSession`, or backend contracts.

## Delivery sequence

1. **WS-A** — Declaration-key coverage gate (ADR 0034). New MoonBit validator
   package scans non-test `.mbt` files, pairs each `impl ... ViewNode for X`
   `declaration()` body with the fields of `struct X`, and fails on fields that
   appear in neither (or lack a `// declaration-exempt:` marker). Ship with a
   checked-in violation baseline (ratchet, like the maintenance baseline), then
   clear `moui/views` to zero and ratchet the baseline down. Thin `.mjs` shim +
   `checks/profiles.json` `pr` registration + invariant row P17.
2. **WS-E** — Effect-key diagnostics: `program_runtime_effect_tasks` warns
   through the runtime diagnostics channel when a live task key is superseded
   by a descriptor with a different `kind()`/`label()`; key-naming convention
   documented in `docs/tea-program-model.md`.
3. **WS-C** — Skia shaping cache: per-`RendererSession` LRU over
   `(text, font, wrap width, scale)` shaping segments in
   `moui_skia_renderer`; hit/miss folded into the existing
   `RenderFrameResult.cache_hit_count`/`cache_miss_count` fields (zero protocol
   change; P16-sanctioned renderer-owned cache).
4. **WS-B** — Tight-fit re-measure (ADR 0035): `ViewLayoutResult.child_frames_tight`;
   `place_with_text_system` re-measures a child with tight constraints derived
   from its final frame when the flag is set and the frame size differs from
   the measured size; `moui/views` flex layout sets the flag; regression tests
   pin `expanded` text wrapping to the weighted width.
5. **WS-D** — map cost: benchmark a deep tree with nested `View::map` layers
   in `benchmarks/full_cycle`; audit the double `children_snapshot.copy()` in
   `ViewAdapter::new`/`children()` and remove the inner copy only if the audit
   and benchmark agree; document flat-`Msg` guidance.
6. **WS-F** — Record three debt notes under `docs/plans/debt/`: trait
   decomposition (blocked), slot storage, session closure style.

## Acceptance

- [x] `node scripts/validate-viewnode-declaration-coverage.mjs` passes with a
  zeroed baseline for `moui/views`, is listed by
  `node scripts/check.mjs --profile pr --list`, and maps to P17 in
  `docs/invariants.md`.
- [x] A live task key superseded by a different kind/label emits one runtime
  diagnostic record (focused test).
- [x] Identical `DrawText` runs across frames report `cache_hit_count > 0`
  (wbtest in `moui_skia_renderer`; shaping here is width-independent, so the
  key is `(font spec, text, font resolution)` and a text change reports a miss).
- [ ] New `moui/runtime` tests: `expanded`/weighted text child wraps to its
  final weighted width (not the loose measure width and not clipped); all
  pre-existing flex tests stay green.
- [ ] `benchmarks/full_cycle` deep-tree `View::map` baseline recorded; copy
  audit conclusion written to this plan either way.
- [ ] Three debt notes exist under `docs/plans/debt/`.
- [ ] `sh scripts/check.sh --profile pr`, the pre-push static trio, and
  `node scripts/sync-website-docs.mjs` + `node scripts/check-website-docs.mjs`
  pass.

## Validation status (2026-09-04)

WS-A (declaration-key coverage gate) complete:
`tools/moui/validate_viewnode_declaration_coverage` scans `moui/**` non-test
sources, pairs each `impl ... ViewNode for X` `declaration()`/`identity()` body
with the fields of `struct X`, honours `// declaration-exempt: <reason>`
markers, skips string literals and line comments, and treats labelled argument
names (`paint=`) as non-references. `checks/viewnode-declaration-coverage.json`
carries a zeroed waiver list and fails on stale waivers. First run flagged 14
fields: 11 were safe-by-construction (closures consumed only by Uncacheable
channels, plus `Icon.verbs` derived from the keyed `label`) and now carry
markers; 3 were genuine coverage gaps and are fixed — `PickerRow` was fully
`constant()` while its layout/paint/semantics read `width`, `is_selected`,
`theme`, and `foreground`, and `value_text` was missing from the `Progress` and
`Slider` semantics keys. The gate is registered in the `pr` profile and flows
into `daily`/`full`; the maintenance budget catalog ratchets the three touched
`moui/views` files and the wrapper budget list. Evidence: 8 tool wbtests, 36
`moui/views` tests, `moon fmt --check`, `moon check`, and the static validators
(maintenance baseline, API surface, release closures, guidance consistency, doc
references, renderer capability) all pass; the shim reports
`OK (34 ViewNode nodes with declaration() overrides; rule P17)`.

WS-E (Effect-key supersession diagnostics) complete: a live task superseded
by a descriptor with a different `kind`/`label` is recorded once per distinct
collision shape in `superseded_effect_task_key_count` /
`superseded_effect_task_keys` on `ProgramRuntimeSnapshot` and
`RuntimeInspectorSnapshot` (supersession semantics unchanged); identical
kind+label restarts stay silent. Focused test
`moui/runtime/effect_task_supersession_test.mbt` drives it through pointer
events; the key-naming convention is documented in
`docs/tea-program-model.md`; `pkg.generated.mbti` regenerated and four runtime
line budgets ratcheted. 116 runtime tests, `moon check` warning-free, and the
static validators pass.

WS-C (Skia shaping cache) complete: session-scoped LRU (256 entries) of
resolved text layouts keyed by `(FontSpec, text, font resolution)` in
`moui_skia_renderer/renderer_text_shaping_cache.mbt`; `draw_text` replays
cached segment/glyph payloads and per-frame hit/miss deltas merge into the
existing `RenderFrameResult` counters (no protocol change). Failed shaping
attempts are misses but stay uncached. wbtests cover key separation, failed
reshape, LRU bounds with eviction order, and cross-frame hit visibility
through `render_frame`; 136 renderer tests green, no public API drift.

Remaining: WS-B, WS-D, WS-F — implementation not started.
