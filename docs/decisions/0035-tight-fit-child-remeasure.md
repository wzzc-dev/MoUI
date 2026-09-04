# 0035: Tight-fit child frames and place-time re-measure

- **Date**: 2026-09-04
- **Status**: Accepted
- **Deciders**: Agent-assisted (ZCode, gpt-5.5)
- **Related**: [Plan: view-framework-remediation](../plans/done/view-framework-remediation.md),
  [ADR 0015](0015-core-protocols.md)

## Context

The layout pipeline is strictly two-phase: `measure` walks children with the
parent's `child_constraints` (default `loosen()`) and each node's `layout()`
returns its own size plus final `child_frames`; `place` only positions subtrees
into those frames and never re-measures. `moui/views` flex distributes main-axis
slack by `flex_weight` at `layout()` time, so a weighted child is measured with
the full loose main-axis extent but placed into its narrower weighted share.
The mainline Skia renderer clips `TextRun` to the draw-time frame rather than
re-wrapping it, so `expanded`/weighted text children keep their measure-time
(line) layout and get clipped instead of wrapping to the width they actually
occupy. The same applies to any child whose internal layout depends on the
width it finally receives.

## Decision

Make final child frames authoritative for measurement without changing the
single-pass measure protocol for nodes that do not opt in:

- `moui/core` `ViewLayoutResult` gains `child_frames_tight : Bool`;
  `ViewLayoutResult::new` takes `child_frames_tight?` defaulting to `false`,
  so every existing construction site is source-compatible.
- `moui/runtime` `place_with_text_system`: when the parent's layout result
  marks its child frames tight and a child's final frame size differs from its
  measured size, re-run that child's measure under tight constraints derived
  from the final frame, then place. The measure memo is keyed on
  `(constraints, environment, style)`, so re-measure reuses the cache when the
  child already settled at that size, and the parent's frame stays the sizing
  authority (no upward size propagation from the re-measure).
- `moui/views` flex layout sets `child_frames_tight=true`; container nodes
  that already pass measured sizes through unchanged (`frame`, `padding`,
  `stack`) keep the default `false`.

## Options Considered

### Option A: Place-time tight re-measure via an opt-in flag (chosen)

- Pros: One-pass measure stays the default cost model for every existing node;
  correctness fix is scoped to the one vocabulary (tight final frames) that
  actually needs it; cache-safe by construction; renderer text path untouched.
- Cons: Adds one defaulted public field; a pathological tree can pay one extra
  measure of an oversized subtree.

### Option B: Per-child constraints in `child_constraints`

- Pros: Matches Flutter's per-child constraint protocol head-on.
- Cons: Breaks the existing `ViewNode` method shape for all controls; flex
  slack is not known before siblings are measured anyway, so the real fix still
  needs a second pass.

### Option C: Document the limitation and forbid text in weighted children

- Pros: Zero code.
- Cons: `expanded` text is a primary flex use case; leaving clipped text as
  framework behavior fails the product mainline.

## Rationale

The framework already centralizes placement in one place
(`place_with_text_system`), so making final frames authoritative there is a
small, local protocol extension. The opt-in flag keeps the common case
(measured size == placed size) at exactly today's cost, and the constraint-keyed
measure memo prevents a re-measure storm on repeated frames.

## Consequences

- Weighted/flex children re-layout their internals to the width they actually
  occupy; clipped-text behavior is replaced by correct wrapping, which may
  change existing golden layouts that baked in the clipped rendering.
- `moon info` interface regen and an API-surface baseline ratchet for
  `moui/core`.
- Future layout vocabularies that stretch children (e.g. stretch cross-axis
  text sizing) can reuse the same flag rather than inventing a second pass.
- If a benchmark shows pathological re-measure cost, the fallback is to scope
  re-measure to text-bearing nodes only; the protocol flag does not change.

## Agent Notes

- **Session context**: source-level audit of MoUI implementation details; flex
  gap reproduced by reading `moui/views/common/flex_layout.mbt`,
  `moui/runtime/layout.mbt`, and the Skia `TextRun` clip path.
- **Agent model**: gpt-5.5 (ZCode)
- **Key prompt or instruction**: "制定计划消除不合理的点" (remediation plan for
  the audit findings).
- **Validation**: new `moui/runtime` wrapping tests; existing flex suites stay
  green; `moon test moui/core moui/runtime moui/views --target native`;
  `node scripts/validate-api-surface.mjs`.

## References

- `moui/core/view_protocol.mbt` (`ViewLayoutResult`)
- `moui/runtime/layout.mbt` (`measure_with_text_system`, `place_with_text_system`)
- `moui/views/common/flex_layout.mbt` (`flex_child_frames` slack logic)
- `moui_skia_renderer/renderer_text.mbt` (draw-time frame clip, no re-wrap)
