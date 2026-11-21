///|
fn modifiers_json(modifiers : @core.KeyModifiers) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["shift"] = bool_json(modifiers.shift)
  fields["control"] = bool_json(modifiers.control)
  fields["alt"] = bool_json(modifiers.alt)
  fields["meta"] = bool_json(modifiers.meta)
  Json::object(fields)
}

///|
fn modifiers_from_json(value : Json?) -> @core.KeyModifiers? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  Some(
    @core.KeyModifiers::new(
      shift=wire_bool(fields.get("shift")).unwrap_or(false),
      control=wire_bool(fields.get("control")).unwrap_or(false),
      alt=wire_bool(fields.get("alt")).unwrap_or(false),
      meta=wire_bool(fields.get("meta")).unwrap_or(false),
    ),
  )
}

///|
fn pointer_phase_name(phase : @core.PointerPhase) -> String {
  match phase {
    @core.PointerPhase::Move => "Move"
    @core.PointerPhase::Down => "Down"
    @core.PointerPhase::Up => "Up"
    @core.PointerPhase::Cancel => "Cancel"
    @core.PointerPhase::Exit => "Exit"
  }
}

///|
fn pointer_phase_from_name(name : String) -> @core.PointerPhase? {
  match name {
    "Move" => Some(@core.PointerPhase::Move)
    "Down" => Some(@core.PointerPhase::Down)
    "Up" => Some(@core.PointerPhase::Up)
    "Cancel" => Some(@core.PointerPhase::Cancel)
    "Exit" => Some(@core.PointerPhase::Exit)
    _ => None
  }
}

///|
/// Encode the host event stream as UTF-8 JSON. Only events the bridge can
/// faithfully hand to the plugin are encoded; the rest return `None` so the
/// host can leave them to the restart path instead of inventing a mapping.
pub fn encode_event(event : @core.AppEvent) -> String? {
  match event {
    @core.AppEvent::Pointer(pointer) => {
      let fields : Map[String, Json] = Map([])
      fields["kind"] = string_json("pointer")
      fields["phase"] = string_json(pointer_phase_name(pointer.phase))
      fields["x"] = number_json(pointer.position.x)
      fields["y"] = number_json(pointer.position.y)
      fields["button"] = Json::number(
        pointer.button.to_double(),
        repr=pointer.button.to_string(),
      )
      fields["wheel_x"] = number_json(pointer.wheel_delta.x)
      fields["wheel_y"] = number_json(pointer.wheel_delta.y)
      fields["modifiers"] = modifiers_json(pointer.modifiers)
      fields["id"] = Json::number(
        pointer.id.to_double(),
        repr=pointer.id.to_string(),
      )
      fields["pressure"] = number_json(pointer.pressure)
      Some(Json::object(fields).stringify())
    }
    @core.AppEvent::Keyboard(keyboard) => {
      let fields : Map[String, Json] = Map([])
      fields["kind"] = string_json("keyboard")
      fields["key"] = string_json(keyboard.key)
      fields["code"] = string_json(keyboard.code)
      fields["text"] = match keyboard.text {
        Some(text) => string_json(text)
        None => Json::null()
      }
      fields["pressed"] = bool_json(keyboard.pressed)
      fields["repeat"] = bool_json(keyboard.repeat)
      fields["modifiers"] = modifiers_json(keyboard.modifiers)
      Some(Json::object(fields).stringify())
    }
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(text)) => {
      let fields : Map[String, Json] = Map([])
      fields["kind"] = string_json("insert_text")
      fields["text"] = string_json(text)
      Some(Json::object(fields).stringify())
    }
    @core.AppEvent::Resize(size) => {
      let fields : Map[String, Json] = Map([])
      fields["kind"] = string_json("resize")
      fields["width"] = number_json(size.width)
      fields["height"] = number_json(size.height)
      Some(Json::object(fields).stringify())
    }
    @core.AppEvent::Redraw(@core.RedrawReason::Explicit) => {
      let fields : Map[String, Json] = Map([])
      fields["kind"] = string_json("redraw")
      Some(Json::object(fields).stringify())
    }
    @core.AppEvent::CloseRequested => {
      let fields : Map[String, Json] = Map([])
      fields["kind"] = string_json("close")
      Some(Json::object(fields).stringify())
    }
    _ => None
  }
}

///|
/// Decode a host event into a core `AppEvent`. A malformed payload returns
/// `None`; the plugin keeps its previous model instead of dispatching a
/// half-decoded event.
pub fn decode_event(text : String) -> @core.AppEvent? {
  let parsed = @json.parse(text) catch { _ => return None }
  let fields = match wire_object(Some(parsed)) {
    Some(fields) => fields
    None => return None
  }
  let kind = match wire_string(fields.get("kind")) {
    Some(kind) => kind
    None => return None
  }
  match kind {
    "pointer" => {
      let phase = match pointer_phase_from_name(
        wire_string(fields.get("phase")).unwrap_or(""),
      ) {
        Some(phase) => phase
        None => return None
      }
      let position = @core.Point::new(
        x=wire_number(fields.get("x")).unwrap_or(0.0),
        y=wire_number(fields.get("y")).unwrap_or(0.0),
      )
      let wheel_delta = @core.Point::new(
        x=wire_number(fields.get("wheel_x")).unwrap_or(0.0),
        y=wire_number(fields.get("wheel_y")).unwrap_or(0.0),
      )
      let modifiers = modifiers_from_json(fields.get("modifiers")).unwrap_or(
        @core.KeyModifiers::none(),
      )
      Some(
        @core.AppEvent::Pointer(
          @core.PointerEvent::new(
            position~,
            phase~,
            button=wire_int(fields.get("button")).unwrap_or(0),
            wheel_delta~,
            modifiers~,
            id=wire_int(fields.get("id")).unwrap_or(0),
            pressure=wire_number(fields.get("pressure")).unwrap_or(1.0),
          ),
        ),
      )
    }
    "keyboard" => {
      let key = match wire_string(fields.get("key")) {
        Some(key) => key
        None => return None
      }
      let code = wire_string(fields.get("code")).unwrap_or("")
      let text = match fields.get("text") {
        Some(Json::Null) | None => None
        Some(value) => wire_string(Some(value))
      }
      Some(
        @core.AppEvent::Keyboard(
          @core.KeyboardEvent::new(
            key~,
            code~,
            text=text,
            pressed=wire_bool(fields.get("pressed")).unwrap_or(true),
            repeat=wire_bool(fields.get("repeat")).unwrap_or(false),
            modifiers=modifiers_from_json(fields.get("modifiers")).unwrap_or(
              @core.KeyModifiers::none(),
            ),
          ),
        ),
      )
    }
    "insert_text" => {
      let text = match wire_string(fields.get("text")) {
        Some(text) => text
        None => return None
      }
      Some(@core.AppEvent::TextInput(@core.TextInputEvent::InsertText(text)))
    }
    "resize" => {
      let width = wire_number(fields.get("width")).unwrap_or(0.0)
      let height = wire_number(fields.get("height")).unwrap_or(0.0)
      Some(@core.AppEvent::Resize(@core.Size::new(width~, height~)))
    }
    "redraw" => Some(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
    "close" => Some(@core.AppEvent::CloseRequested)
    _ => None
  }
}
