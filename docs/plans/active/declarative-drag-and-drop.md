# Plan: Declarative in-app drag and drop

- **Status**: active (slice landed on the `wzzc-dev/drag-drop` branch
  2026-11-24; retire to `done/INDEX.md` once the PR merges)
- **Created**: 2026-11-24
- **Goal**: let an app describe in-app drag sources and drop targets as ordinary
  view declarations; the runtime owns the pointer session and translates it
  into TEA messages, so app model/update code never handles raw pointer state.
- **Non-goals**: OS file drop (stays on `DragDropEvent`/`View::on_file_drop`),
  native drag previews or cross-window drags, renderer/backend/platform edits,
  new core view enum variants, and a public `Cancelled` phase.

Related: `docs/views-api-guide.md` (usage), `docs/view-catalog.md` (catalog row),
`docs/plans/active/pointer-input-parity.md` (gesture arena underneath),
ADR 0054 (transient runtime gesture state).

## Design

- **Core value types** (`moui/core/drag_drop.mbt`): `DragPayload {key, text}`,
  `DragSource {payload, min_distance=4.0}` (clamped at zero),
  `DropTarget {key, accepts(payload)}` (accept-all by default),
  `DragDeclaration {source?, target?}`, `DragPhase`
  (`Started|Moved|Entered|Left|Dropped|Ended`),
  `ViewDragContext {phase, payload, position, frame, target_key?}`,
  `ViewDragResult[Msg] {changed, messages}`, and `DragEnd {payload, position,
  target_key?}`.
- **Declaration channel** (`view_node.mbt`, `view_protocol.mbt`,
  `any_modifier.mbt`): `ViewNode::drag_declaration` defaults to none;
  `View::from_node` accepts a `drag` translator; `View::drag_declaration` and
  `View::dispatch_drag` expose the snapshot. Modifier layers report their own
  declaration verbatim — never merged with the child — because every layer is
  its own element and the runtime resolves each role from the deepest element
  that declares one.
- **Modifiers** (`moui/core/modifier_drag.mbt`): `View::draggable` and
  `View::drop_target` turn callbacks into messages (`on_start`/`on_move`/
  `on_end(DragEnd)`, `on_enter`/`on_move`/`on_drop`/`on_leave`). Handlers are
  observers: they produce messages; the runtime owns the session.
- **Runtime recognizer** (`moui/runtime/input_view_drag.mbt`): a primary-pointer
  press arms the deepest source; `Started` fires only once travel reaches
  `min_distance`. The session then owns the primary stream (pointer capture in
  behavior) until release, host `Cancel`, or Escape. Target hover resolves the
  deepest accepting target on every sample and emits `Entered`/`Moved`/
  `Left`/`Dropped`; a rejecting target never hovers. The source observes
  `Started`, each `Moved`, and exactly one `Ended` whose `target_key` names the
  dropped target or is `None` when released outside every accepting target,
  cancelled by Escape, or cancelled by the host stream.
- **Delivery**: each phase dispatches only to its declaring element, with that
  element's own screen frame and the screen pointer position; messages and
  `changed` flow through the same terminal batch as the pointer event's own
  outcome (drag deliveries first, one rebuild after the batch).
- **Coexistence**: `View::on_drag` keeps its own recognizer and 3.0 pt default
  (deliberately not unified); `.on_drag` and `.draggable` on one view both run.
  Disabled ancestors suppress drag roles exactly like other pointer modifiers.

## Acceptance

- [x] Source starts only at the declared distance; movement outside the source
      still arrives while the session is active.
- [x] Target enter/move/leave/drop, innermost accepting target wins, rejecting
      target never hovers.
- [x] Exactly one terminal `Ended`; release outside a target, Escape and host
      cancel all report `None`.
- [x] Messages and `changed` reach the runtime like view events; disabled
      source/target stay inert.
- [x] `.on_drag` + `.draggable` stacking and the existing `DragDropEvent` file
      path behave as before.
- [x] Core tests (`core/drag_drop_test.mbt`) and runtime tests
      (`runtime/view_drag_test.mbt`) cover the slice; `moui/core`,
      `moui/runtime`, `moui/views` suites and workspace `moon check` pass.

## Decision log

- 2026-11-24: The recognizer runs beside the normal pointer pipeline rather than
  replacing hit dispatch; controls, hover and the gesture arena keep their
  existing behavior, and the session simply owns the primary stream from start
  to terminal phase.
- 2026-11-24: Drag messages are delivered after the pointer event's dispatch,
  ahead of its own messages, so a mid-sequence rebuild cannot invalidate the
  element ids the phase walk needs.
- 2026-11-24: Escape is consumed only while a session is active; otherwise it
  keeps its dismissal-layer routing.

## Progress

- 2026-11-24: landed core protocol + modifiers, runtime recognizer/session,
  core/runtime tests, public API budget re-accounting, and docs. No renderer,
  backend, platform, or example changes.
