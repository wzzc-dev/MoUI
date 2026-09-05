///|
fn decode_command_argument(
  arguments : Map[String, Json],
) -> @core.CommandIntent? {
  guard json_string_field(arguments, "intent") is Some(intent) else {
    return None
  }
  match intent {
    "Activate" => Some(@core.CommandIntent::Activate)
    "Submit" => Some(@core.CommandIntent::Submit)
    "Cancel" => Some(@core.CommandIntent::Cancel)
    "Copy" => Some(@core.CommandIntent::Copy)
    "Cut" => Some(@core.CommandIntent::Cut)
    "Paste" => Some(@core.CommandIntent::Paste)
    "Undo" => Some(@core.CommandIntent::Undo)
    "Redo" => Some(@core.CommandIntent::Redo)
    "SelectAll" => Some(@core.CommandIntent::SelectAll)
    "OpenContextMenu" => Some(@core.CommandIntent::OpenContextMenu)
    _ => None
  }
}

///|
fn decode_event_argument(arguments : Map[String, Json]) -> @core.AppEvent? {
  guard arguments.get("event") is Some(Json::Object(fields)) else {
    return None
  }
  guard json_string_field(fields, "kind") is Some("Pointer") else {
    return None
  }
  guard fields.get("position") is Some(Json::Object(position)) else {
    return None
  }
  guard position.get("x") is Some(Json::Number(x, repr=_)) else { return None }
  guard position.get("y") is Some(Json::Number(y, repr=_)) else { return None }
  guard json_string_field(fields, "phase") is Some(phase) else { return None }
  let pointer_phase = match phase {
    "Down" => @core.PointerPhase::Down
    "Up" => @core.PointerPhase::Up
    "Move" => @core.PointerPhase::Move
    "Cancel" => @core.PointerPhase::Cancel
    "Exit" => @core.PointerPhase::Exit
    _ => return None
  }
  Some(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x~, y~),
        phase=pointer_phase,
      ),
    ),
  )
}
