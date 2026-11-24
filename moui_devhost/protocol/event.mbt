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
fn redraw_reason_name(reason : @core.RedrawReason) -> String {
  match reason {
    @core.RedrawReason::Initial => "Initial"
    @core.RedrawReason::Input => "Input"
    @core.RedrawReason::Resize => "Resize"
    @core.RedrawReason::Explicit => "Explicit"
  }
}

///|
fn redraw_reason_from_name(name : String) -> @core.RedrawReason? {
  match name {
    "Initial" => Some(@core.RedrawReason::Initial)
    "Input" => Some(@core.RedrawReason::Input)
    "Resize" => Some(@core.RedrawReason::Resize)
    "Explicit" => Some(@core.RedrawReason::Explicit)
    _ => None
  }
}

///|
fn drag_drop_phase_name(phase : @core.DragDropPhase) -> String {
  match phase {
    @core.DragDropPhase::Entered => "Entered"
    @core.DragDropPhase::Moved => "Moved"
    @core.DragDropPhase::Dropped => "Dropped"
    @core.DragDropPhase::Left => "Left"
  }
}

///|
fn drag_drop_phase_from_name(name : String) -> @core.DragDropPhase? {
  match name {
    "Entered" => Some(@core.DragDropPhase::Entered)
    "Moved" => Some(@core.DragDropPhase::Moved)
    "Dropped" => Some(@core.DragDropPhase::Dropped)
    "Left" => Some(@core.DragDropPhase::Left)
    _ => None
  }
}

///|
fn gesture_kind_name(kind : @core.GestureKind) -> String {
  match kind {
    @core.GestureKind::Pinch => "Pinch"
    @core.GestureKind::Rotate => "Rotate"
    @core.GestureKind::Pan => "Pan"
    @core.GestureKind::DoubleTap => "DoubleTap"
    @core.GestureKind::Pressure => "Pressure"
  }
}

///|
fn gesture_kind_from_name(name : String) -> @core.GestureKind? {
  match name {
    "Pinch" => Some(@core.GestureKind::Pinch)
    "Rotate" => Some(@core.GestureKind::Rotate)
    "Pan" => Some(@core.GestureKind::Pan)
    "DoubleTap" => Some(@core.GestureKind::DoubleTap)
    "Pressure" => Some(@core.GestureKind::Pressure)
    _ => None
  }
}

///|
fn gesture_phase_name(phase : @core.GesturePhase) -> String {
  match phase {
    @core.GesturePhase::Started => "Started"
    @core.GesturePhase::Moved => "Moved"
    @core.GesturePhase::Ended => "Ended"
  }
}

///|
fn gesture_phase_from_name(name : String) -> @core.GesturePhase? {
  match name {
    "Started" => Some(@core.GesturePhase::Started)
    "Moved" => Some(@core.GesturePhase::Moved)
    "Ended" => Some(@core.GesturePhase::Ended)
    _ => None
  }
}

///|
fn range_json(range : @core.TextRange) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["start"] = int_json(range.start)
  fields["end"] = int_json(range.end)
  Json::object(fields)
}

///|
fn range_from_json(value : Json?) -> @core.TextRange? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let start = match wire_int(fields.get("start")) {
    Some(value) => value
    None => return None
  }
  let end = match wire_int(fields.get("end")) {
    Some(value) => value
    None => return None
  }
  Some(@core.TextRange::new(start~, end~))
}

///|
fn optional_range_json(range : @core.TextRange?) -> Json {
  match range {
    Some(range) => range_json(range)
    None => Json::null()
  }
}

///|
fn optional_range_from_json(value : Json?) -> @core.TextRange? {
  match value {
    Some(Json::Null) | None => None
    Some(inner) => range_from_json(Some(inner))
  }
}

///|
fn optional_point_json(point : @core.Point?) -> Json {
  match point {
    Some(point) => point_json(point)
    None => Json::null()
  }
}

///|
fn optional_point_from_json(value : Json?) -> @core.Point? {
  match value {
    Some(Json::Null) | None => None
    Some(inner) => point_from_json(Some(inner))
  }
}

///|
fn text_input_json(event : @core.TextInputEvent) -> (String, Map[String, Json]) {
  let fields : Map[String, Json] = Map([])
  let op = match event {
    @core.TextInputEvent::InsertText(text) => {
      fields["text"] = string_json(text)
      "insert_text"
    }
    @core.TextInputEvent::ReplaceText(range, text) => {
      fields["range"] = range_json(range)
      fields["text"] = string_json(text)
      "replace_text"
    }
    @core.TextInputEvent::SetSelection(range) => {
      fields["range"] = range_json(range)
      "set_selection"
    }
    @core.TextInputEvent::CompositionStart => "composition_start"
    @core.TextInputEvent::CompositionUpdate(update) => {
      fields["text"] = string_json(update.text())
      fields["cursor"] = optional_range_json(update.cursor())
      "composition_update"
    }
    @core.TextInputEvent::CompositionEnd(text) => {
      fields["text"] = string_json(text)
      "composition_end"
    }
    @core.TextInputEvent::DeleteRange(range) => {
      fields["range"] = range_json(range)
      "delete_range"
    }
    @core.TextInputEvent::DeleteSurrounding(before, after) => {
      fields["before"] = int_json(before)
      fields["after"] = int_json(after)
      "delete_surrounding"
    }
  }
  (op, fields)
}

///|
fn text_input_fields(event : @core.TextInputEvent) -> Json {
  // `insert_text` keeps the original v1 kind so an older reader still handles
  // plain typing; every newer op nests under `text_input` with an `op` tag.
  let (op, fields) = text_input_json(event)
  if op == "insert_text" {
    fields["kind"] = string_json("insert_text")
  } else {
    fields["kind"] = string_json("text_input")
    fields["op"] = string_json(op)
  }
  Json::object(fields)
}

///|
fn text_input_from_json(fields : Map[String, Json]) -> @core.TextInputEvent? {
  let op = match wire_string(fields.get("op")) {
    Some(op) => op
    None => return None
  }
  match op {
    "insert_text" =>
      match wire_string(fields.get("text")) {
        Some(text) => Some(@core.TextInputEvent::InsertText(text))
        None => None
      }
    "replace_text" => {
      let range = match range_from_json(fields.get("range")) {
        Some(range) => range
        None => return None
      }
      let text = match wire_string(fields.get("text")) {
        Some(text) => text
        None => return None
      }
      Some(@core.TextInputEvent::ReplaceText(range, text))
    }
    "set_selection" =>
      match range_from_json(fields.get("range")) {
        Some(range) => Some(@core.TextInputEvent::SetSelection(range))
        None => None
      }
    "composition_start" => Some(@core.TextInputEvent::CompositionStart)
    "composition_update" => {
      let text = match wire_string(fields.get("text")) {
        Some(text) => text
        None => return None
      }
      let cursor = optional_range_from_json(fields.get("cursor"))
      Some(
        @core.TextInputEvent::CompositionUpdate(
          @core.CompositionUpdate::new(text~, cursor~),
        ),
      )
    }
    "composition_end" =>
      match wire_string(fields.get("text")) {
        Some(text) => Some(@core.TextInputEvent::CompositionEnd(text))
        None => None
      }
    "delete_range" =>
      match range_from_json(fields.get("range")) {
        Some(range) => Some(@core.TextInputEvent::DeleteRange(range))
        None => None
      }
    "delete_surrounding" => {
      let before = match wire_int(fields.get("before")) {
        Some(value) => value
        None => return None
      }
      let after = match wire_int(fields.get("after")) {
        Some(value) => value
        None => return None
      }
      Some(@core.TextInputEvent::DeleteSurrounding(before, after))
    }
    _ => None
  }
}

///|
/// Encode one host-side `AppEvent` as UTF-8 JSON. Every core `AppEvent` variant
/// and every `TextInputEvent` op crosses the ABI with its full payload; the
/// host keeps platform services that cannot be represented (menu bars, window
/// chrome, OS drag sessions) and only forwards the app-visible event.
pub fn encode_event(event : @core.AppEvent) -> String? {
  match event {
    @core.AppEvent::FrameTick(frame) => {
      let fields : Map[String, Json] = Map([])
      fields["kind"] = string_json("frame_tick")
      fields["time_ms"] = number_json(frame.time_ms)
      fields["delta_ms"] = number_json(frame.delta_ms)
      Some(Json::object(fields).stringify())
    }
    @core.AppEvent::Pointer(pointer) => {
      let fields : Map[String, Json] = Map([])
      fields["kind"] = string_json("pointer")
      fields["phase"] = string_json(pointer_phase_name(pointer.phase))
      fields["x"] = number_json(pointer.position.x)
      fields["y"] = number_json(pointer.position.y)
      fields["button"] = int_json(pointer.button)
      fields["wheel_x"] = number_json(pointer.wheel_delta.x)
      fields["wheel_y"] = number_json(pointer.wheel_delta.y)
      fields["modifiers"] = modifiers_json(pointer.modifiers)
      fields["id"] = int_json(pointer.id)
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
    @core.AppEvent::TextInput(text_input) =>
      Some(text_input_fields(text_input).stringify())
    @core.AppEvent::DragDrop(drag_drop) => {
      let fields : Map[String, Json] = Map([])
      fields["kind"] = string_json("drag_drop")
      fields["phase"] = string_json(drag_drop_phase_name(drag_drop.phase))
      fields["paths"] = Json::array(
        drag_drop.paths.map(path => string_json(path)),
      )
      fields["position"] = optional_point_json(drag_drop.position)
      Some(Json::object(fields).stringify())
    }
    @core.AppEvent::PlatformView(view, platform_event) => {
      match platform_event {
        @core.PlatformViewEvent::Named(name~, value~, detail~, flag~) => {
          let fields : Map[String, Json] = Map([])
          fields["kind"] = string_json("platform_view")
          fields["view"] = string_json(view)
          fields["name"] = string_json(name)
          fields["value"] = string_json(value)
          fields["detail"] = string_json(detail)
          fields["flag"] = bool_json(flag)
          Some(Json::object(fields).stringify())
        }
      }
    }
    @core.AppEvent::Resize(size) => {
      let fields : Map[String, Json] = Map([])
      fields["kind"] = string_json("resize")
      fields["width"] = number_json(size.width)
      fields["height"] = number_json(size.height)
      Some(Json::object(fields).stringify())
    }
    @core.AppEvent::Redraw(reason) => {
      let fields : Map[String, Json] = Map([])
      fields["kind"] = string_json("redraw")
      fields["reason"] = string_json(redraw_reason_name(reason))
      Some(Json::object(fields).stringify())
    }
    @core.AppEvent::Gesture(gesture) => {
      let fields : Map[String, Json] = Map([])
      fields["kind"] = string_json("gesture")
      fields["gesture_kind"] = string_json(gesture_kind_name(gesture.kind))
      fields["phase"] = string_json(gesture_phase_name(gesture.phase))
      fields["scale_delta"] = number_json(gesture.scale_delta)
      fields["rotation_delta"] = number_json(gesture.rotation_delta)
      fields["pan_x"] = number_json(gesture.pan_delta.x)
      fields["pan_y"] = number_json(gesture.pan_delta.y)
      fields["pressure"] = number_json(gesture.pressure)
      fields["pressure_stage"] = int_json(gesture.pressure_stage)
      Some(Json::object(fields).stringify())
    }
    @core.AppEvent::CloseRequested => {
      let fields : Map[String, Json] = Map([])
      fields["kind"] = string_json("close")
      Some(Json::object(fields).stringify())
    }
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
    "frame_tick" => {
      let time_ms = match wire_number(fields.get("time_ms")) {
        Some(value) => value
        None => return None
      }
      let delta_ms = wire_number(fields.get("delta_ms")).unwrap_or(0.0)
      Some(@core.AppEvent::FrameTick(@core.Frame::new(time_ms~, delta_ms~)))
    }
    "pointer" => {
      let phase = match
        pointer_phase_from_name(wire_string(fields.get("phase")).unwrap_or("")) {
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
            text~,
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
    "text_input" =>
      match text_input_from_json(fields) {
        Some(event) => Some(@core.AppEvent::TextInput(event))
        None => None
      }
    "drag_drop" => {
      let phase = match
        drag_drop_phase_from_name(
          wire_string(fields.get("phase")).unwrap_or(""),
        ) {
        Some(phase) => phase
        None => return None
      }
      let items = match wire_array(fields.get("paths")) {
        Some(items) => items
        None => []
      }
      let paths : Array[String] = []
      for item in items {
        match wire_string(Some(item)) {
          Some(path) => paths.push(path)
          None => return None
        }
      }
      let position = optional_point_from_json(fields.get("position"))
      Some(
        @core.AppEvent::DragDrop(
          @core.DragDropEvent::new(phase~, paths~, position~),
        ),
      )
    }
    "platform_view" => {
      let view = match wire_string(fields.get("view")) {
        Some(view) => view
        None => return None
      }
      let name = match wire_string(fields.get("name")) {
        Some(name) => name
        None => return None
      }
      let value = wire_string(fields.get("value")).unwrap_or("")
      let detail = wire_string(fields.get("detail")).unwrap_or("")
      let flag = wire_bool(fields.get("flag")).unwrap_or(false)
      Some(
        @core.AppEvent::PlatformView(
          view,
          @core.PlatformViewEvent::Named(name~, value~, detail~, flag~),
        ),
      )
    }
    "resize" => {
      let width = wire_number(fields.get("width")).unwrap_or(0.0)
      let height = wire_number(fields.get("height")).unwrap_or(0.0)
      Some(@core.AppEvent::Resize(@core.Size::new(width~, height~)))
    }
    "redraw" => {
      let reason = match wire_string(fields.get("reason")) {
        Some(name) =>
          match redraw_reason_from_name(name) {
            Some(reason) => reason
            None => return None
          }
        // The first v1 shape carried no reason and always meant an explicit
        // repaint request.
        None => @core.RedrawReason::Explicit
      }
      Some(@core.AppEvent::Redraw(reason))
    }
    "gesture" => {
      let gesture_kind = match
        gesture_kind_from_name(
          wire_string(fields.get("gesture_kind")).unwrap_or(""),
        ) {
        Some(kind) => kind
        None => return None
      }
      let phase = match
        gesture_phase_from_name(wire_string(fields.get("phase")).unwrap_or("")) {
        Some(phase) => phase
        None => return None
      }
      let pan_delta = @core.Point::new(
        x=wire_number(fields.get("pan_x")).unwrap_or(0.0),
        y=wire_number(fields.get("pan_y")).unwrap_or(0.0),
      )
      Some(
        @core.AppEvent::Gesture(
          @core.GestureEvent::new(
            kind=gesture_kind,
            phase~,
            scale_delta=wire_number(fields.get("scale_delta")).unwrap_or(0.0),
            rotation_delta=wire_number(fields.get("rotation_delta")).unwrap_or(
              0.0,
            ),
            pan_delta~,
            pressure=wire_number(fields.get("pressure")).unwrap_or(0.0),
            pressure_stage=wire_int(fields.get("pressure_stage")).unwrap_or(0),
          ),
        ),
      )
    }
    "close" => Some(@core.AppEvent::CloseRequested)
    _ => None
  }
}
