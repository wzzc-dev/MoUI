///|
/// `.draggable`: declares this view as a drag source. The runtime owns the
/// recognizer (primary pointer, primary button, `min_distance` in points), so
/// the modifier itself carries no per-element gesture state; it contributes a
/// `DragSource` and turns the runtime's source phases into messages.
priv struct DraggableModifier[Msg] {
  payload : DragPayload
  min_distance : Double
  on_start : ((DragPayload, Point) -> Msg)?
  on_move : ((DragPayload, Point) -> Msg)?
  on_end : ((DragEnd) -> Msg)?
}

///|
fn[Msg] DraggableModifier::to_any_modifier(
  self : DraggableModifier[Msg],
) -> AnyModifier[Msg] {
  let payload = self.payload
  let on_start = self.on_start
  let on_move = self.on_move
  let on_end = self.on_end
  {
    ..noop_modifier(),
    identity_kind: "Draggable",
    drag_declaration: DragDeclaration::new(
      source=Some(DragSource::new(payload~, min_distance=self.min_distance)),
    ),
    drag: fn(context) {
      let messages : Array[Msg] = match context.phase {
        Started =>
          match on_start {
            Some(handler) => [handler(payload, context.position)]
            None => []
          }
        Moved =>
          match on_move {
            Some(handler) => [handler(payload, context.position)]
            None => []
          }
        Ended =>
          match on_end {
            Some(handler) =>
              [
                handler(
                  DragEnd::new(
                    payload~,
                    position=context.position,
                    target_key=context.target_key,
                  ),
                ),
              ]
            None => []
          }
        Entered | Left | Dropped => []
      }
      { changed: messages.length() > 0, messages, }
    },
  }
}

///|
pub fn[Msg] View::draggable(
  self : View[Msg],
  payload~ : DragPayload,
  on_start~ : ((DragPayload, Point) -> Msg)? = None,
  on_move~ : ((DragPayload, Point) -> Msg)? = None,
  on_end~ : ((DragEnd) -> Msg)? = None,
  min_distance~ : Double = 4.0,
) -> View[Msg] {
  self.apply_modifier(
    DraggableModifier::{ payload, min_distance, on_start, on_move, on_end, }.to_any_modifier(),
  )
}

///|
/// `.drop_target`: declares this view as a drop target. The runtime hover is
/// driven by the hit path (deepest target first), so nested targets resolve to
/// the innermost one; the modifier only translates phases into messages.
priv struct DropTargetModifier[Msg] {
  key : String
  accepts : (DragPayload) -> Bool
  on_drop : ((DragPayload, Point) -> Msg)?
  on_enter : ((DragPayload, Point) -> Msg)?
  on_leave : (() -> Msg)?
  on_move : ((DragPayload, Point) -> Msg)?
}

///|
fn[Msg] DropTargetModifier::to_any_modifier(
  self : DropTargetModifier[Msg],
) -> AnyModifier[Msg] {
  let accepts = self.accepts
  let on_drop = self.on_drop
  let on_enter = self.on_enter
  let on_leave = self.on_leave
  let on_move = self.on_move
  {
    ..noop_modifier(),
    identity_kind: "DropTarget",
    drag_declaration: DragDeclaration::new(
      target=Some(DropTarget::new(key=self.key, accepts~)),
    ),
    drag: fn(context) {
      let messages : Array[Msg] = match context.phase {
        Entered =>
          match on_enter {
            Some(handler) => [handler(context.payload, context.position)]
            None => []
          }
        Moved =>
          match on_move {
            Some(handler) => [handler(context.payload, context.position)]
            None => []
          }
        Dropped =>
          match on_drop {
            Some(handler) => [handler(context.payload, context.position)]
            None => []
          }
        Left =>
          match on_leave {
            Some(handler) => [handler()]
            None => []
          }
        Started | Ended => []
      }
      { changed: messages.length() > 0, messages, }
    },
  }
}

///|
pub fn[Msg] View::drop_target(
  self : View[Msg],
  key~ : String,
  on_drop~ : ((DragPayload, Point) -> Msg)? = None,
  on_enter~ : ((DragPayload, Point) -> Msg)? = None,
  on_leave~ : (() -> Msg)? = None,
  on_move~ : ((DragPayload, Point) -> Msg)? = None,
  accepts~ : ((DragPayload) -> Bool)? = None,
) -> View[Msg] {
  let predicate = match accepts {
    Some(predicate) => predicate
    None => _payload => true
  }
  self.apply_modifier(
    DropTargetModifier::{
      key,
      accepts: predicate,
      on_drop,
      on_enter,
      on_leave,
      on_move,
    }.to_any_modifier(),
  )
}
