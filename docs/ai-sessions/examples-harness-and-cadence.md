# Examples, harness and framework cadence (2026-07 → 2026-11)

Durable summary of the example-consolidation, harness-engineering, governance and
framework-maturity sessions. Canonical: `docs/INDEX.md`, `docs/ai-collaboration.md`,
`docs/plans/README.md`, `docs/feature-status-dashboard.md`.

## 2026-07-07 — native Code Editor example

See `text-and-editors.md`. Landing rule: new examples register in `docs/examples.md`,
`docs/architecture.md`/`development.md` where relevant, `moon.work` and
`examples/catalog.json`; website docs are generated and ignored under
`website/web_wasm/docs`.

## 2026-07-16 — harness-engineering map

Outcome: docs/harness surface reworked; validator implementation deferred to a plan
(landed later as `plans/done/harness-mechanize-invariants-batch1.md`).

- Progressive disclosure: short `AGENTS.md` router, `docs/INDEX.md` catalog,
  one-page `docs/architecture-map.md`, `docs/golden-principles.md`.
- `AGENTS.md` stayed token-compatible with `validate_guidance_consistency`; the
  contract was not relaxed in the same change. Prefer extending MoonBit validators
  over new Node-only logic.
- Session workflow: promote to `memories/repo/`, ADR, and/or plan.

## 2026-07-16 — Showcase consolidation

- Restored the Showcase root TEA shell over four feature packages, added
  `program_with_initial_route`, retired `component_gallery` / `platform_lab` /
  `moui_example`. Root always owns four child models; workspace switch does not reset
  them; Platform subscriptions stay mapped while hidden. ADR 0012/0013.
- Unified shell redesign: root owns chrome; packages export catalog + `view_body`;
  Diagnostics trimmed to five runtime items; probe only on Platform.

## 2026-11-01 — hot-path convergence + maintainability

- Ten workstreams / 24 acceptance items executed over one session with parallel
  subagents; 16 slice commits + a momark fix. Structural finds: theme/environment
  scope modifiers declared Constant channels (subtree theme switching never
  invalidated); P17 declaration gate paired structs/impls per file and scanned
  nothing after codegen; PlanOp lowering was a per-frame DTO copy (PlanOp deleted —
  renderers match `@core.DrawCommand` directly).
- D1 fingerprinting must cover message identity via latest-commands indirection, not
  `ActionCommand` equality. Diagnostics gate became a single-traversal fold with no
  extra walk and no API surface.
- F1 whole-subtree skip / wrapper reuse were rejected with evidence; F3 stayed
  `FullSurface` for 4/5 scenarios (force-full rebuild classes, sibling resizes).
  `View::theme`/`View::environment` scopes key declarations on the scoped value
  (`environment_scope_declaration`).
- Lesson: a green validator can hide `scanned=0`; drill it by deleting a field.

## 2026-11-07 — maturity gap closures (15 commits)

One commit per slice: `fdf2784ac` macOS a11y capability after AX L2; `221c8f5c6`
scroll fling inertia (runtime frame pump + offset-space velocity + decay);
`d0d1fbf75` golden image regression harness; `e991185a5` frame-trace overlay;
`8a9309623` `range_slider`; `7c25279a8` `AppEvent::Gesture` end to end;
`79783b870` trackpad-gesture evidence card; `1b4573f02` inspector tree/trace
timeline; `facbbcc2c` `carousel`; `f0bbfc8da` `refresh_indicator`; `7c0755186`
automatic route transitions; `36cc9a99d` + `5c556797c` RTL steps 1–2;
`b386e5460` two-finger pinch/rotation recognizer; `14e8b526e` `color_picker`.

- Patterns: the frame pump (dispatching `AppEvent::FrameTick` into latched
  subtrees) powered both fling inertia and route transitions; runtime-owned
  transient slots keep gesture state across model rebuilds; derive encoded length
  from the write sequence (byte-length vs decode-check mismatches bit three times);
  `on_tap(fixed_message)` evaluates eagerly — per-tap payloads need
  `on_tap_with_frame`.
- Remaining recommendations became plans: native text-provider completion, GPU
  partial repaint, in-process hot reload (RFC).

## 2026-08-05 — cross-platform ownership

See `platform-readiness.md`. Durable rule: similarity thresholds/allowlists are not
architecture tools; shared behaviour moves to its owner immediately.

## 2026-10-03 — MoUI Studio blocks canvas

See `text-and-editors.md`. Studio work is a submodule; budget counters for the shell
live in the studio repo, not this one.
