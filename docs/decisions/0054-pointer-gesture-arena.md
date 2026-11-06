# 0054: Pointer gesture arbitration stays in transient runtime state

- **Date**: 2026-11-05
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted architecture review)
- **Related**: plan `architecture-priority-execution` (W3.3), plan
  `pointer-input-parity` (section 10), ADR 0033

## Context

Pointer modifiers are view wrappers. Stacking `.on_long_press()` and
`.on_tap()` creates two independently stateful recognizers around the same
leaf, in either order. The existing captured-event unwind could cancel a child
tap after an ancestor drag or scroll recognized a movement, but it could not
cancel an outer tap when an inner long press completed. On release, the outer
tap still saw its stale `Pressed` state and emitted a second command.

Adding another public event field would expose recognizer internals to every
view implementation, and delaying every tap to prove that a long press did not
win would penalize the normal interaction path. The runtime already owns each
pointer's capture and pressed-position lifecycle, so arbitration belongs at
that boundary.

## Decision

The runtime keeps a transient gesture arena keyed by `PointerEvent.id`.

- `Down` records the elements that armed a pointer recognizer: an element that
  captured the pointer, changed a typed view-state slot, or changed its
  text-control state. A hover/pressed presentation change alone does not arm a
  gesture.
- `Move`/`Up`/`Cancel` observe the same child-first traversal while no winner
  exists. The first element to activate, or a scroll view whose `Move` produces
  an authoritative layout change, becomes the stream winner.
- The first winner is sticky for that pointer id. Other recorded candidates
  receive a direct synthetic `Cancel`, and all later stream events are delivered
  only to the winner's own event handler, not its children or ancestors.
- `Up` and `Cancel` end that pointer's arena stream. A rebuild prunes candidate
  and owner ids that no longer exist in the element tree.
- Other pointer ids are independent. A second finger has its own candidates,
  winner, pressed position, and capture.

The arena is not component state, does not enter the TEA model, and adds no
public API. It arbitrates only the lifetime of one already-dispatched pointer
stream. Semantic ownership remains unchanged: the winning modifier emits its
ordinary typed message through the existing delivery path.

## Options Considered

### Option A: add a cross-modifier public cancellation signal

- Pros: modifiers could resolve their own priority.
- Cons: expands every `ViewEventResult` and teaches leaf modifiers about global
  arbitration; nested stack order still needs a runtime owner to compare them.

### Option B: delay tap activation by the long-press duration

- Pros: avoids firing both recognizers.
- Cons: adds latency to every click and still cannot arbitrate drag, scroll, or
  multi-pointer competition.

### Option C: fixed modifier priority independent of stack order

- Pros: no new state structure.
- Cons: a static order cannot express whether a drag crossed its slop or a
  scroll view had an authoritative range; it changes semantics by declaration
  shape rather than observed intent.

### Option D: per-pointer transient runtime arena

- Pros: recognizes the first completed gesture, preserves child-first
  traversal, supports nested scroll and multiple pointers, and exposes no new
  component-state or event API.
- Cons: the runtime carries a small temporary map during an active press and
  must prune it after structural rebuilds.

## Consequences

- Tap and long press now behave identically under either modifier stack order:
  a quick release fires only tap, while a completed hold fires only the long
  press and later release cannot fall through to tap.
- Drag versus tap and nested-scroll selection use the same winner rule instead
  of separate ad hoc cancellation paths.
- The winner receives subsequent `Move`/`Up` events directly. A custom
  control that defers handling to a child after activation must therefore
  express that behavior as component composition rather than a competing
  recognizer.
- The arena can be recomputed after a rebuild only by id membership; it never
  serializes, persists, or restores gesture state.

## References

- `docs/plans/done/architecture-priority-execution.md`
- `docs/plans/active/pointer-input-parity.md`
- `moui/runtime/input_gesture_arena.mbt`
- `moui/runtime/input_pointer.mbt`
- `moui/runtime/runtime_events.mbt`
- `moui/runtime/input_gesture_arena_wbtest.mbt`
- `moui/runtime/long_press_wake_test.mbt`
- `moui/runtime/nested_scroll_release_test.mbt`
- `moui/runtime/multi_pointer_input_wbtest.mbt`
