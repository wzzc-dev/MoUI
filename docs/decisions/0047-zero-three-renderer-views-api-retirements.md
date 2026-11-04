# 0047: The 0.3.0 base release retires the lowering/mailbox and button-only helper surfaces

- **Date**: 2026-11-04
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted release preparation)
- **Related**: plan `hot-path-invalidation-boilerplate-convergence` (E1/E2, A3/A4/B1), ADR 0019, ADR 0043, ADR 0045, commits `ee0c9681c`, `73b8615cc`, `1e500a41d`, `04b6c730c`

## Context

`docs/compatibility-policy.md` allows a `0.x` minor to break provided the same
release ships an upgrade note and a migration example. The `0.3.0` family release
carries two removal batches landed between `0.2.6` and `0.3.0`:

1. Hot-path convergence deleted the per-frame `PlanOp` lowering DTO and the
   zero-caller `RenderFrameMailbox` queue from the published
   `wzzc-dev/moui/render/common` surface. Renderers now interpret the
   `@core.DrawCommand` stream directly (ADR 0045's "retire the lowering" step).
2. The views-helper dedupe turned the button-only pressed-transition facility
   into the shared `pressable_*` facility and dropped duplicated fallback
   helpers from `wzzc-dev/moui/views/common` and `wzzc-dev/moui/views/container`.

Both batches are internal to the monorepo today — the concrete renderers live in
`moui_*_renderer` modules and control authors import `moui/views/common` — but
both surfaces are published, so external renderer/backlog consumers need an
explicit mapping. No compatibility alias was left behind, following the ADR 0015
and ADR 0034 precedents ("breaking change ... no migration shim"): an alias
would keep the under-distinguishing DTO copy alive, which is the cost being
removed.

## Decision

Ship `wzzc-dev/moui` and the whole public family (bindings, renderers, addons,
entrypoints) as `0.3.0` with these removals, documented by the tables below.
This section is the release's upgrade note; the migration example lives in
`docs/view-catalog.md` ("Declaration-key encoders" neighbor section, "Pressable
transitions (2026-11-04 migration)").

### `moui/render/common` removals

| removed | use |
|---|---|
| `lower_draw_commands` | match the `@core.DrawCommand` stream directly in the renderer's frame path; keep the per-variant match exhaustive (no catch-all) so a new core variant is a compile error, per ADR 0019/0045 |
| `DrawPlan` / `DrawPlanDiagnostic` | none — its diagnostics had no production consumer; scope-balance and capability degradation come from `plan_renderer_command_fallbacks` (single validator home) and the renderer's own frame report |
| `PlanOp` (26 variants) | the `@core.DrawCommand` variants themselves; the plan stage was an equal-payload mirror of the 26-variant command stream |
| `RenderFrameMailbox` / `RenderFramePacket` / `RenderFrameMailboxDiagnostics` | `GpuRenderWorker`, which already owned sequence/pending/in-flight/control semantics; its `submit` no longer copies the command array |

Additive in the same release: `ImageResourceLifecycle::generation()` and the
optional `image_records_generation?` argument on `RendererSession::new` (image
lifecycle generation diff so sessions can skip redundant record rebuilds).

### `moui/views/common` and `moui/views/container` removals

| removed | use |
|---|---|
| `ButtonTransitionState` | `PressableTransition` (`Idle` / `Active(PressableState, Double)`) |
| `button_transition_slot()` | `pressable_transition_slot(control~)`, keyed `"moui.views.<control>.transition"`; `button` keeps its exact previous key and the wire encoding is byte-compatible |
| `button_transition(ctx)` | `pressable_transition(ctx, control="button")` |
| `button_state_with_transition(ctx, prev, next, ms)` | `pressable_state_with_transition(ctx, prev, next, ms, control="button")` |
| `view_button_next_state` | `pressable_next_state` (state machine logic unchanged) |
| `min_view_double` / `max_view_double` | the surviving `view_min_double` / `view_max_double` (views/common/view_control_helpers.mbt) |
| `resolve_control_color(fallback, value)` | `value.unwrap_or(fallback)` from the stdlib `Option` |

Additive (non-breaking, grouped ergonomics): `ViewSemanticsInfo::container /
leaf / text_field / hidden / transparent` constructors, `effective_theme` on the
event/layout/paint contexts, `is_copy/cut/paste_shortcut`, and
`HostRuntimeDriver::keyboard_command_intent`.

## Options Considered

### Option A: keep deprecated aliases for one release

- Pros: zero consumer breakage.
- Cons: preserves the exact per-frame DTO copy and the duplicated helper pair
  the plan removed as cost; the repo precedent (ADR 0015, ADR 0034) is
  alias-free removals inside `0.x`.

### Option B: split into a base-only patch plus a later minor

- Pros: smaller blast radius.
- Cons: impossible — `checks/release-modules.json` stages plus
  `validate_release_module_closures` require workspace pins to equal current
  module versions, and the HEAD renderers do not compile against `moui@0.2.6`
  (they consume the new direct-command path and the `image_records_generation`
  session hook). The family must move together, as in the 0.2.6 release.

### Option C (chosen): one `0.3.0` family release with an ADR upgrade note + a docs migration example

- Pros: matches the compatibility policy and the 0.2.6 unified-version
  precedent; removal is real, documentation is normative.
- Cons: renderer/control authors must migrate at upgrade time.

## Rationale

The removals delete per-frame work (a 27-variant mirror array copy, a full
command-array mailbox copy) and dead code (zero production callers), which is
exactly what the hot-path plan set out to converge. `0.x` minor is the policy
channel for this; the cost is one migration note, which this ADR is.

## Consequences

- Apps that use only `wzzc-dev/moui` + domain facades + `moui/views` public
  control constructors see no required change: every removal is in the
  advanced `views/common` helper layer or the `render/*` contract layer, and
  the added session/constructor arguments are optional.
- Renderer authors replace the `lower_draw_commands` step with a direct
  `@core.DrawCommand` match and take queue semantics from `GpuRenderWorker`
  instead of `RenderFrameMailbox`.
- Control authors rename the button-transition helpers to the `pressable_*`
  family (persisted `ViewState` slots decode unchanged — byte-compatible
  encoding, same key for `"button"`).
- The capability report and proof matrices describe the queue under
  `GpuRenderWorker`; the gpu-promotion manifest field `mailboxOk` keeps its
  name as the latest-wins queue-health gate (it was always a property of the
  worker), and `docs/gpu-promotion-runbook.md` is authoritative for it.

## Validation

- `node scripts/validate-release-module-closures.mjs` (stage topology + pin
  equality across the workspace).
- `node scripts/validate-api-surface.mjs` + regenerated
  `checks/api-surface-report.json` (core +11 declarations, render/common −27).
- `sh scripts/check.sh --profile daily` green except the two
  `moui_studio/services/compile_native` tests, which require a reachable
  mooncakes.io registry index (`moon update` step of the exported bundle);
  recorded here as environment-blocked, not code regressions.

## References

- `docs/plans/done/hot-path-invalidation-boilerplate-convergence.md`
- `docs/decisions/0045-direct-host-gpu-renderer-experimental.md`
- `docs/decisions/0034-viewnode-declaration-coverage-gate.md` (alias-free removal precedent)
- `docs/view-catalog.md` ("Pressable transitions (2026-11-04 migration)")
