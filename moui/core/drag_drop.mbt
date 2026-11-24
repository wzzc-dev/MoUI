///|
/// What one drag carries. `key` is the payload identity the drop targets
/// match on (for example `"tab/42"`); `text` is an optional human-readable
/// companion an app can use for display or for a text drop.
///
/// `DragPayload` is data only: the runtime owns the in-flight session, and a
/// `.draggable` declaration snapshots the payload at build time.
#derive(Eq, Debug)
pub(all) struct DragPayload {
  key : String
  text : String
}

///|
pub fn DragPayload::new(key~ : String, text~ : String = "") -> DragPayload {
  { key, text, }
}

///|
/// The drag source half of a `DragDeclaration`: what the drag carries and how
/// far the pointer must travel before the press becomes a drag.
///
/// The default `min_distance` is 4.0 pt. `.on_drag`'s recognizer still uses
/// its own 3.0 pt default; the two are deliberately not unified, so a view
/// that stacks both should pass `min_distance=3.0` to `.draggable` to make the
/// two recognizers start on the same sample.
#derive(Eq, Debug)
pub(all) struct DragSource {
  payload : DragPayload
  min_distance : Double
}

///|
pub fn DragSource::new(
  payload~ : DragPayload,
  min_distance~ : Double = 4.0,
) -> DragSource {
  { payload, min_distance: max_double(0.0, min_distance), }
}

///|
/// The drop target half of a `DragDeclaration`: an identity key the drop is
/// reported with, and an acceptance predicate over the payload. `accepts=None`
/// on the modifier means "accept every payload".
pub(all) struct DropTarget {
  key : String
  accepts : (DragPayload) -> Bool
}

///|
pub fn DropTarget::new(
  key~ : String,
  accepts~ : (DragPayload) -> Bool = _payload => true,
) -> DropTarget {
  { key, accepts, }
}

///|
pub fn DropTarget::accepts(self : DropTarget, payload : DragPayload) -> Bool {
  (self.accepts)(payload)
}

///|
/// The drag channels a view declares. Source and target are independent, so a
/// single view can be both (a list row that can be dragged onto another row).
/// `DragDeclaration::none()` declares nothing and is the `ViewNode` default.
pub(all) struct DragDeclaration {
  source : DragSource?
  target : DropTarget?
}

///|
pub fn DragDeclaration::none() -> DragDeclaration {
  { source: None, target: None, }
}

///|
pub fn DragDeclaration::new(
  source~ : DragSource? = None,
  target~ : DropTarget? = None,
) -> DragDeclaration {
  { source, target, }
}

///|
pub fn DragDeclaration::is_empty(self : DragDeclaration) -> Bool {
  match (self.source, self.target) {
    (None, None) => true
    _ => false
  }
}

///|
/// One phase of the runtime-owned drag session.
///
/// The source side observes `Started`/`Moved`/`Ended`; the hovered target
/// observes `Entered`/`Moved`/`Left`/`Dropped`. There is no separate
/// `Cancelled` phase: a cancelled drag is `Ended` with `target_key=None`, so a
/// source callback has exactly one terminal case to handle (Esc, a pointer
/// stream cancel, or a release outside every accepting target all land there).
#derive(Eq, Debug)
pub(all) enum DragPhase {
  Started
  Moved
  Entered
  Left
  Dropped
  Ended
}

///|
/// The context handed to one view's drag channel. `frame` is the view's own
/// screen frame. `target_key` is the hovered target's key for the source-side
/// phases, and the view's own key for the target-side phases (its own key when
/// it is a `Left` that has just stopped hovering).
#derive(Eq, Debug)
pub(all) struct ViewDragContext {
  phase : DragPhase
  payload : DragPayload
  position : Point
  frame : Rect
  target_key : String?
}

///|
pub fn ViewDragContext::new(
  phase~ : DragPhase,
  payload~ : DragPayload,
  position~ : Point,
  frame~ : Rect,
  target_key~ : String? = None,
) -> ViewDragContext {
  { phase, payload, position, frame, target_key, }
}

///|
/// The result of dispatching one drag phase to one view. Mirrors
/// `ViewEventResult` without the pointer-specific fields: a drag phase either
/// asks for a repaint/rebuild (`changed`) and/or emits messages.
pub(all) struct ViewDragResult[Msg] {
  changed : Bool
  messages : Array[Msg]
}

///|
pub fn[Msg] ViewDragResult::none() -> ViewDragResult[Msg] {
  { changed: false, messages: [], }
}

///|
pub fn[Msg] ViewDragResult::message(message : Msg) -> ViewDragResult[Msg] {
  { changed: true, messages: [message], }
}

///|
/// The outcome of a completed drag, handed to a source's `on_end`. A `None`
/// `target_key` means the drag ended without a drop: released outside every
/// accepting target, cancelled with Escape, or cancelled by the host.
#derive(Eq, Debug)
pub(all) struct DragEnd {
  payload : DragPayload
  position : Point
  target_key : String?
}

///|
pub fn DragEnd::new(
  payload~ : DragPayload,
  position~ : Point,
  target_key~ : String? = None,
) -> DragEnd {
  { payload, position, target_key, }
}
