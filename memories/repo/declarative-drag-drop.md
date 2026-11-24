# Declarative in-app drag and drop

- Rule: `ViewNode::drag_declaration` describes source/target roles; the runtime
  owns the primary-pointer session (`moui/runtime/input_view_drag.mbt`) and
  views only translate phases to messages (`View::draggable`/`drop_target`).
  OS file drop stays on `DragDropEvent`/`on_file_drop`.
- Every modifier layer is its own element: `.draggable().drop_target()` is a
  target wrapper over a source child. `ModifierViewNode::drag_declaration`
  reports its own modifier verbatim — never merge with the child.
- The recognizer runs beside normal pointer dispatch: controls, hover,
  `on_drag` (3.0 pt) and the gesture arena keep working. Do not unify
  `on_drag` with `draggable`.
- Drag deliveries are deferred to the pointer event's terminal batch (drag
  first) so a phase cannot rebuild the tree mid-sequence.
- Role resolution mirrors `dispatch_pointer_to_children` (overlay prepass, clip
  intersections, disabled child environment); check `environment.enabled` or
  `.disabled()` wrappers stay draggable.
- Escape is consumed only while a session is active; host `Cancel` and a fresh
  `Down` both end it with `Ended(None)`.
- Tests: `moui/core/drag_drop_test.mbt`, `moui/runtime/view_drag_test.mbt`.
