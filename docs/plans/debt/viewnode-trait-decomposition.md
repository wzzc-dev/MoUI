# Plan: ViewNode trait decomposition

- **Status**: debt
- **Goal**: Split the 14-method `ViewNode` trait into finer-grained traits
  (`LayoutNode`, `PaintNode`, `SemanticsViewNode`, `FocusNode`, …) so new
  controls implement only the surface they actually participate in, and
  capability-shaped dispatch replaces "every node answers every question".
- **Non-goals**: any runtime behaviour change; any change to
  `View::from_node`/`ViewAdapter` snapshot ownership; adding new capability
  channels beyond the existing four declaration channels.

## Context

`moui/core/view_node.mbt` carries the signpost comment ("Future: when MoonBit
supports blanket trait impls, decompose ViewNode into finer-grained traits").
Today every control gets sane defaults for all 14 methods, which is the
ergonomic reason the fat trait survives: the decomposition only pays off if
the language can derive the aggregate trait from the sub-traits (blanket
impls) so existing controls keep compiling without hand-writing forwarding
impls for each node.

## Why deferred

- MoonBit has no blanket trait implementations, so a `LayoutNode`/`PaintNode`
  split would force either (a) hand-written aggregate impls for every one of
  the 34+ `ViewNode` structs, or (b) a runtime capability query (trait object
  probing), which changes the vtable shape `ViewAdapter` snapshots.
- The practical harm is currently bounded: the P17 declaration-coverage gate
  (ADR 0034) already catches the realistic fat-trait failure (a node
  overriding one channel while forgetting a dependent field), and unused
  defaults are cheap no-ops.

## Re-evaluate when

- MoonBit ships blanket/default trait impls or first-class trait objects.
- A new control family (e.g. synthetic test nodes, headless controls) makes
  implementing paint/semantics stubs an actual tax at authoring time.
- Declaration channels grow past four and the fat trait blocks channel-local
  evolution.

## Acceptance
- [ ] Decomposition plan merged as an RFC/ADR with a compile-compatibility
  story for existing nodes.
- [ ] All 34+ `ViewNode` implementations migrate without behaviour drift
  (layout/paint/semantics golden tests green).

## Decision log
| Date | Decision |
|------|----------|
| 2026-09-04 | Recorded as debt from the implementation audit (view-framework-remediation); blocked on MoonBit blanket impls, P17 gate accepted as interim mitigation. |

## Progress
| Date | Note |
|------|------|
| 2026-09-04 | Debt note created; signpost comment already in `moui/core/view_node.mbt`. |
