# Event dispatch geometry in the runtime

- **Plan**: `docs/plans/active/pointer-input-parity.md`.

## Standing facts

- Every `ViewNode::event` call must arrive with the **placed** frame. The
  pointer path resolves it by hit-test; `dispatch_keyboard` and
  `dispatch_text_input` take `layout~ : PlacedNode` and use
  `PlacedNode::event_render_node_for(id)`. Anything that used to pass
  `RenderNode::empty()` silently made geometry-dependent handling (vertical
  caret move in a multiline field, a field's own viewport follow, a reveal
  request) compute against a zero rect.
- `ElementNode::place_with_text_system` re-descends only when the node reports
  its own dirtiness (`needs_layout || descendant_layout`) and its placement
  cache is keyed by frame. So a state change in a deep node is invisible unless
  **every ancestor on the path** is marked `descendant_layout` and has
  `layout_cache` / `render_cache` cleared. `dispatch_pointer` does that while
  unwinding (`input_pointer.mbt`); any *other* dispatch that commits view state
  must do the same. `dispatch_event_to_target` (used by `scroll_to_key` and text
  reveal) now mirrors it.
- Symptom when it is missing: the control's own state reports the change (e.g. a
  scroll offset), the event-time child frames look right, and the placed/painted
  tree keeps the previous frame's geometry. Nothing errors.

## Why

Both are silent-failure classes: a zero rect still measures, a stale cache still
paints, and the view-side math is correct, so the defect only shows up as "the
widget did not move".

## How to apply

When adding a dispatch entry point or an event-injected request, ask "who marks
the ancestors dirty?" before adding view-side logic. Reproduce with a nested
tree (root -> column -> scroll view -> field): a single-level test can pass on
the ordering luck that some other dirty bit flushed the caches. Related:
`docs/tea-program-model.md`, `memories/repo/source-file-policy-ratchets.md`.
