# 0033: Overlay placement pass, portal, and layer stack

- **Date**: 2026-09-03
- **Status**: Accepted
- **Deciders**: Agent-assisted
- **Related**: [ADR 0030](0030-overlay-presentation-host.md), [plan overlay-placement-portal-unification](../plans/active/overlay-placement-portal-unification.md)

## Context

ADR 0030 unified app-level presentations behind `overlay_host` +
`PresentationSpec`, but three problems remain verified in code:

1. **Anchoring lives inside the layout fixpoint.** `layout_current_tree`
   re-enters full-tree layout whenever the anchor registry changes (bounded at
   64 passes with `abort()`), and every element's measure/place cache keys on
   the whole `anchor_frames` array, so any keyed frame change invalidates the
   entire tree. First-frame placement falls back to the viewport center.
2. **Control popups cannot reach the root layer.** Views are pure; only the
   composition root can call `overlay_host`. Built-in controls therefore use
   three weaker escape hatches: local stacks (clipped by scroll containers),
   hand-drawn `overlay_commands` popups (invisible to semantics, no Escape, no
   flip/clamp), and paint-level hit heuristics (`paint_plan_child_clip`).
3. **Dismissal and native modal are incomplete.** Escape routing sniffs
   `identity().kind == "OverlayHost"` strings; `PresentationHostPolicy` and
   `HostModalSession` are never evaluated in production code.

## Decision

1. **Post-layout placement pass.** Anchor placement moves out of the layout
   fixpoint. Layout runs once; a placement pass after base layout (and after
   anchor-registry collection) computes presentation/popup frames and patches
   the placed spine before render, hit-testing, semantics, and platform-tree
   consumption. `anchor_frames` leave all measure/place cache keys. The core
   `ViewNode` protocol gains a neutral `place_overlays` hook (default: none);
   the placement engine stays in `moui/views`.
2. **Portal via overlay-host sizing mode.** `OverlayHostNode` gains a
   `Base` sizing mode (`popup_host`) so a control declares popups next to its
   anchor: it sizes to its base child, measures popup children with
   root-viewport constraints (viewport carried in the layout environment), and
   positions them through the same placement pass, barrier, semantics, and
   focus-trap machinery as app presentations.
3. **Layer stack.** The runtime records active overlay layers back-to-front
   during the placement pass; Escape/Back/outside-tap dismiss top-most-first
   through a typed `keyboard_policy()` capability instead of kind-string
   matching. Nested hosts get unambiguous ordering.
4. **Hit regions from layout + clip.** Hit-testing intersects placed frames
   with an accumulated clip carried on `PlacedNode`; the render-command
   `paint_plan_child_clip` heuristic is deleted. `paint_bounds` remains a
   damage concept only.
5. **Exit retention.** Removed presentations/popups are retained by the
   runtime until their transition completes, sampled from the frame clock;
   reduced-motion completes immediately.
6. **`overlay_commands` become decoration-only** (shadows, native-composition
   markers such as `overlay_marker`). Interactive popups never use them.

## Options Considered

### Option A: Patch the placed spine in a placement pass (chosen)

- Pros: all five frame consumers (paint, hit, semantics, platform tree,
  damage) already pair element children with placed/render arrays by index, so
  patched spines flow everywhere without new plumbing; kills the fixpoint,
  the array cache keys, and the first-frame flash at once.
- Cons: ancestor caches embed descendant geometry, so invalidation must walk
  to the root; damage must enqueue both old and new bounds.

### Option B: Parallel overlay-frame map consumed by render/hit

- Pros: placed tree untouched.
- Cons: requires special cases in `render_with_environment`,
  `dispatch_pointer_to_children`, focus pickup, semantics, and the platform
  tree — far more invasive and error-prone.

### Option C: Keep placement in layout, narrow the cache keys

- Pros: smallest diff.
- Cons: keeps the two-pass fixpoint and the first-frame flash; does not give
  controls root reachability.

## Rationale

Option A is the only variant that removes the structural defect (anchoring as
a layout input) rather than its symptoms, and it is the prerequisite for the
portal, the layer stack, and exit retention. The core hook keeps `moui/core`
vocabulary-neutral (ADR 0017) while geometry stays in `moui/views`.

## Consequences

- Layout becomes single-pass for anchored trees; `layout_pass_count` and
  cache hit rates become testable invariants.
- Popup content subtrees are real element trees: semantically visible,
  Escape-dismissable, focusable, and clip-free — this is a behavior change for
  picker/date-picker (their popups gain semantics).
- ADR 0030's "compose only through overlay_host" claim becomes true for
  control popups via `popup_host`; its deferred native-presenter work is taken
  up in the plan's macOS slice.
- `PresentationPlacement.anchor` is removed (anchor single-sourced on
  `PresentationSpec`); the few call sites are updated in the same change.

## Agent Notes

- **Session context**: Overlay-system analysis and unification plan.
- **Agent model**: ZCode (GLM-5.3-Flash)
- **Key prompt or instruction**: "根据以上分析制定一个计划" — full roadmap,
  macOS reference implementation in scope, picker/date-picker fully migrated.
- **Validation**: per-slice `moon test` on touched packages, api-surface and
  maintenance-baseline validators, `check.sh --profile pr` at slice closure.

## References

- Plan: `docs/plans/active/overlay-placement-portal-unification.md`
- ADR 0030: `docs/decisions/0030-overlay-presentation-host.md`
- Runtime evidence: `moui/runtime/runtime_render_pipeline.mbt`,
  `moui/runtime/layout.mbt`, `moui/views/presentation.mbt`
