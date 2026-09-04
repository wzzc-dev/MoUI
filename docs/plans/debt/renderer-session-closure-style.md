# Plan: RendererSession trait style vs closure record

- **Status**: debt
- **Goal**: Decide once whether `RendererSession` (`moui/render/
  renderer_session.mbt`) should stay a struct of private `*_fn` closures or
  move to a trait/object protocol, and migrate in one deliberate step.
- **Non-goals**: adding capabilities (P11 forbids provider/session surface
  growth without an RFC allowlist entry); changing `RendererProvider`,
  `RenderFrameSubmission`, or host-contract shapes.

## Context

`RendererSession` is a 342-line record: lifecycle operations (`resize_fn`,
`render_frame_fn`, `drain_events_fn`, `recover_fn`, `dispose_fn`, …) and
capabilities (`platform_view`, `gpu_recovery`) are stored as closures that
concrete renderers wire up at construction. The closure style exists because
MoonBit cannot hold a `dyn` renderer object without enum dispatch or type
erasure, and it gives provider code a single construction point with defaults
for optional capabilities.

Costs: every renderer repeats closure-assembly boilerplate; the compiler
cannot check capability completeness the way a trait would; new optional
capabilities require hand-wiring on every provider.

## Why deferred

- P11's shrink-or-stay budget
  (`validate-renderer-provider-open-extension.mjs` +
  `validate-renderer-provider-manifests.mjs`, ADR 0027) already caps the
  damage: the session cannot silently accrete capability closures, which was
  the realistic failure mode of the closure style.
- A trait migration is a cross-package protocol change touching
  `moui/render`, `moui/backend`, and every concrete renderer — exactly the
  class of change that requires an RFC per AGENTS.md — while the current
  style has no known correctness bug.

## Re-evaluate when

- A third concrete renderer stack lands and closure-assembly duplication
  measurably slows renderer work, or
- Optional capabilities multiply (platform-view/GPU-recovery-like) and
  completeness mistakes appear in review, or
- MoonBit gains trait objects / blanket impls that make an object-safe
  session trait cheap.

## Acceptance
- [ ] RFC/ADR recording the final style with the migration cost for existing
  renderers.
- [ ] Migration keeps P11 budgets flat (no capability surface growth).

## Decision log
| Date | Decision |
|------|----------|
| 2026-09-04 | Recorded as debt from the implementation audit (view-framework-remediation); closure record kept under the P11 ratchet. |

## Progress
| Date | Note |
|------|------|
| 2026-09-04 | Debt note created; session shape read from `moui/render/renderer_session.mbt`. |
