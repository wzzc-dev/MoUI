///|
fn int_from_json(value : Json?) -> Int32? {
  wire_int(value)
}

///|
fn text_range_json(range : @core.TextRange) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["start"] = int_json(range.start)
  fields["end"] = int_json(range.end)
  Json::object(fields)
}

///|
fn text_range_from_json(value : Json?) -> @core.TextRange? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let start = match int_from_json(fields.get("start")) {
    Some(value) => value
    None => return None
  }
  let end = match int_from_json(fields.get("end")) {
    Some(value) => value
    None => return None
  }
  Some(@core.TextRange::new(start~, end~))
}

///|
fn optional_text_range_json(value : @core.TextRange?) -> Json {
  match value {
    Some(range) => text_range_json(range)
    None => Json::null()
  }
}

///|
fn optional_text_range_from_json(value : Json?) -> @core.TextRange? {
  match value {
    Some(Json::Null) | None => None
    _ => text_range_from_json(value)
  }
}

///|
/// The plugin's focused text-editing state. It mirrors the runtime's
/// `TextInputState` so the host IME session can place the caret, selection and
/// preedit without owning an app tree.
pub fn encode_text_input_state(state : @core.TextInputState) -> String {
  let fields : Map[String, Json] = Map([])
  fields["focused"] = bool_json(state.focused)
  fields["text"] = string_json(state.text)
  fields["caret"] = int_json(state.caret)
  fields["selection"] = optional_text_range_json(state.selection)
  fields["composition"] = match state.composition {
    Some(text) => string_json(text)
    None => Json::null()
  }
  fields["composition_cursor"] = optional_text_range_json(
    state.composition_cursor,
  )
  fields["frame"] = rect_json(state.frame)
  fields["caret_rect"] = rect_json(state.caret_rect)
  Json::object(fields).stringify()
}

///|
fn text_input_state_json(state : @core.TextInputState) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["focused"] = bool_json(state.focused)
  fields["text"] = string_json(state.text)
  fields["caret"] = int_json(state.caret)
  fields["selection"] = optional_text_range_json(state.selection)
  fields["composition"] = match state.composition {
    Some(text) => string_json(text)
    None => Json::null()
  }
  fields["composition_cursor"] = optional_text_range_json(
    state.composition_cursor,
  )
  fields["frame"] = rect_json(state.frame)
  fields["caret_rect"] = rect_json(state.caret_rect)
  Json::object(fields)
}

///|
fn text_input_state_from_json(value : Json?) -> @core.TextInputState? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let focused = match wire_bool(fields.get("focused")) {
    Some(value) => value
    None => return None
  }
  let text = match wire_string(fields.get("text")) {
    Some(value) => value
    None => return None
  }
  let caret = match int_from_json(fields.get("caret")) {
    Some(value) => value
    None => return None
  }
  let frame = match rect_from_json(fields.get("frame")) {
    Some(value) => value
    None => return None
  }
  let caret_rect = match rect_from_json(fields.get("caret_rect")) {
    Some(value) => value
    None => return None
  }
  let composition = match fields.get("composition") {
    Some(Json::Null) | None => None
    Some(value) =>
      match wire_string(Some(value)) {
        Some(text) => Some(text)
        None => return None
      }
  }
  Some(@core.TextInputState::{
    focused,
    text,
    caret,
    selection: optional_text_range_from_json(fields.get("selection")),
    composition,
    composition_cursor: optional_text_range_from_json(
      fields.get("composition_cursor"),
    ),
    frame,
    caret_rect,
  })
}

///|
/// Decode a standalone text-input state payload (used by the host's
/// `text_input` frame field and by tests).
pub fn decode_text_input_state(text : String) -> @core.TextInputState? {
  let parsed = @json.parse(text) catch { _ => return None }
  text_input_state_from_json(Some(parsed))
}
