///|
priv struct MacosAccessibilityBinding {
  window_id : @host.WindowId
  mut cursor : @core.SemanticsGeneration?
}

///|
priv struct MacosAccessibilityState {
  mut bindings : Array[MacosAccessibilityBinding]
}

///|
fn MacosAccessibilityState::new() -> MacosAccessibilityState {
  { bindings: [], }
}

///|
fn MacosAccessibilityState::binding(
  self : MacosAccessibilityState,
  window_id : @host.WindowId,
) -> MacosAccessibilityBinding {
  for binding in self.bindings {
    if binding.window_id == window_id {
      return binding
    }
  }
  let binding = { window_id, cursor: None, }
  self.bindings.push(binding)
  binding
}

///|
fn MacosAccessibilityState::remove(
  self : MacosAccessibilityState,
  window_id : @host.WindowId,
) -> Unit {
  self.bindings = self.bindings.filter(binding => binding.window_id != window_id)
}

///|
#borrow(payload)
extern "C" fn macos_accessibility_sync_native(
  raw_view : UInt64,
  payload : Bytes,
) -> Int = "moui_macos_accessibility_sync"

///|
extern "C" fn macos_accessibility_dispose_native(raw_view : UInt64) -> Unit = "moui_macos_accessibility_dispose"

///|
extern "C" fn macos_accessibility_take_action_native(
  raw_view : UInt64,
) -> Bytes = "moui_macos_accessibility_take_action"

///|
#borrow(message)
extern "C" fn macos_accessibility_record_evidence_native(
  message : Bytes,
) -> Unit = "moui_macos_accessibility_record_evidence"

///|
fn macos_record_accessibility_evidence(message : String) -> Unit {
  macos_accessibility_record_evidence_native(@utf8.encode(message, bom=false))
}

///|
fn macos_semantics_role_code(role : @core.SemanticsRole) -> String {
  match role {
    None => "none"
    Text => "text"
    Link => "link"
    Heading => "heading"
    Navigation => "navigation"
    Main => "main"
    Button => "button"
    Checkbox => "checkbox"
    TextField => "text_field"
    List => "list"
    ListItem => "list_item"
    Grid => "grid"
    ScrollView => "scroll_view"
    Switch => "switch"
    Radio => "radio"
    Slider => "slider"
    Progress => "progress"
    Tab => "tab"
    Dialog => "dialog"
    Tooltip => "tooltip"
    Menu => "menu"
    ButtonGroup => "button_group"
    Form => "form"
    FormField => "form_field"
    Tree => "tree"
    TreeItem => "tree_item"
    Group => "group"
    WebView => "web_view"
    Image => "image"
    Alert => "alert"
    Status => "status"
    ComboBox => "combo_box"
    Option => "option"
    Table => "table"
    Row => "row"
    Cell => "cell"
    Separator => "separator"
  }
}

///|
fn macos_semantics_action_code(kind : @core.SemanticsActionKind) -> String {
  match kind {
    Activate => "activate"
    Focus => "focus"
    SetText => "set_text"
    Submit => "submit"
    Scroll => "scroll"
    Select => "select"
    Expand => "expand"
    Collapse => "collapse"
    Dismiss => "dismiss"
    Increment => "increment"
    Decrement => "decrement"
    SetNumericValue => "set_numeric_value"
    SetSelection => "set_selection"
    ShowMenu => "show_menu"
  }
}

///|
fn macos_semantics_live_code(live : @core.SemanticsLive) -> String {
  match live {
    Off => "off"
    Polite => "polite"
    Assertive => "assertive"
  }
}

///|
fn macos_checked_json(value : @core.SemanticsCheckedState?) -> Json {
  match value {
    Some(Unchecked) => "unchecked".to_json()
    Some(Checked) => "checked".to_json()
    Some(Mixed) => "mixed".to_json()
    None => (None : String?).to_json()
  }
}

///|
fn macos_semantics_node_json(node : @core.SemanticsNode) -> Json {
  (
    {
      "node_id": node.node_id,
      "semantic_id": node.semantic_id,
      "role": macos_semantics_role_code(node.role),
      "level": node.level,
      "url": node.url,
      "label": node.label,
      "value": node.value,
      "description": node.description,
      "state": {
        "focused": node.state.focused,
        "disabled": node.state.disabled,
        "selected": node.state.selected,
        "pressed": node.state.pressed,
        "checked": macos_checked_json(node.state.checked),
        "expanded": node.state.expanded,
        "invalid": node.state.invalid,
        "required": node.state.required,
        "read_only": node.state.read_only,
        "busy": node.state.busy,
        "multiline": node.state.multiline,
        "password": node.state.password,
        "modal": node.state.modal,
      },
      "numeric": node.numeric,
      "text": node.text,
      "collection": node.collection,
      "relations": node.relations,
      "live": macos_semantics_live_code(node.live),
      "atomic": node.live_atomic,
      "actions": node.actions.map(macos_semantics_action_code),
      "focus_order": node.focus_order,
      "frame": node.frame,
      "children": node.children,
    } : Json)
}

///|
fn macos_announcement_json(
  announcement : @runtime.AccessibilityAnnouncement,
) -> Json {
  (
    {
      "node_id": announcement.node_id,
      "generation": announcement.generation,
      "live": macos_semantics_live_code(announcement.live),
      "atomic": announcement.is_atomic,
      "text": announcement.text,
    } : Json)
}

///|
fn macos_optional_node_id_json(value : @core.SemanticsNodeId?) -> Json {
  match value {
    Some(id) => id.to_json()
    None => (None : String?).to_json()
  }
}

///|
fn macos_semantics_read_json(read : @runtime.SemanticsRead) -> Json? {
  match read {
    Full(snapshot) =>
      Some(
        (
          {
            "kind": "full",
            "generation": snapshot.generation(),
            "root": macos_optional_node_id_json(snapshot.root()),
            "focused": macos_optional_node_id_json(snapshot.focused()),
            "semantic_focused": macos_optional_node_id_json(
              snapshot.semantic_focused(),
            ),
            "nodes": snapshot.nodes().map(macos_semantics_node_json),
            "removed": ([] : Array[String]),
            "announcements": ([] : Array[Json]),
          } : Json),
      )
    Delta(delta) =>
      Some(
        (
          {
            "kind": "delta",
            "generation": delta.to(),
            "root": macos_optional_node_id_json(delta.root()),
            "focused": macos_optional_node_id_json(delta.focused()),
            "semantic_focused": macos_optional_node_id_json(
              delta.semantic_focused(),
            ),
            "nodes": delta.upserted().map(macos_semantics_node_json),
            "removed": delta.removed(),
            "announcements": delta.announcements().map(macos_announcement_json),
          } : Json),
      )
    Unchanged(_) => None
  }
}

///|
fn macos_parse_decimal_u64(value : String) -> UInt64? {
  if value == "" {
    return None
  }
  let mut parsed = 0UL
  for character in value {
    let code = character.to_int()
    if code < '0' || code > '9' {
      return None
    }
    let digit = (code - ('0' : Int)).to_uint64()
    if parsed > (18446744073709551615UL - digit) / 10UL {
      return None
    }
    parsed = parsed * 10UL + digit
  }
  Some(parsed)
}

///|
fn macos_json_string_field(
  fields : Map[String, Json],
  name : String,
) -> String? {
  match fields.get(name) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn macos_native_semantics_action(
  kind : String,
  value : String,
) -> @core.SemanticsAction? {
  match kind {
    "activate" => Some(Activate)
    "focus" => Some(Focus)
    "set_text" => Some(SetText(value))
    "submit" => Some(Submit)
    "scroll" =>
      match value {
        "forward" => Some(Scroll(Forward))
        "backward" => Some(Scroll(Backward))
        "up" => Some(Scroll(Up))
        "down" => Some(Scroll(Down))
        "left" => Some(Scroll(Left))
        "right" => Some(Scroll(Right))
        _ => None
      }
    "select" => Some(Select)
    "expand" => Some(Expand)
    "collapse" => Some(Collapse)
    "dismiss" => Some(Dismiss)
    "increment" => Some(Increment)
    "decrement" => Some(Decrement)
    "set_numeric_value" =>
      Some(SetNumericValue(@string.parse_double(value))) catch {
        _ => None
      }
    "set_selection" =>
      match value.split(",").to_array() {
        [start_text, end_text] =>
          match
            (
              macos_parse_decimal_u64(start_text.to_owned()),
              macos_parse_decimal_u64(end_text.to_owned()),
            ) {
            (Some(start), Some(end)) if start <= 2147483647UL &&
              end <= 2147483647UL =>
              Some(
                SetSelection(
                  @core.TextRange::new(start=start.to_int(), end=end.to_int()),
                ),
              )
            _ => None
          }
        _ => None
      }
    "show_menu" => Some(ShowMenu)
    _ => None
  }
}

///|
fn MacosNativeHostBackend::dispatch_accessibility_actions(
  _self : MacosNativeHostBackend,
  raw_view : UInt64,
  driver : @runtime.HostRuntimeDriver,
) -> Unit {
  for ;; {
    let bytes = macos_accessibility_take_action_native(raw_view)
    if bytes.length() == 0 {
      return
    }
    let source = @utf8.decode_lossy(bytes[:], ignore_bom=false)
    let parsed = @json.parse(source) catch {
      error => {
        println("macOS accessibility action decode failed: \{error}")
        continue
      }
    }
    guard parsed is Object(fields) else {
      println("macOS accessibility action decode failed: expected object")
      continue
    }
    guard macos_json_string_field(fields, "node_id") is Some(node_text) &&
      macos_json_string_field(fields, "generation") is Some(generation_text) &&
      macos_json_string_field(fields, "kind") is Some(kind) &&
      macos_parse_decimal_u64(node_text) is Some(node_id) &&
      macos_parse_decimal_u64(generation_text) is Some(generation) else {
      println("macOS accessibility action decode failed: invalid identity")
      continue
    }
    let value = macos_json_string_field(fields, "value").unwrap_or("")
    guard macos_native_semantics_action(kind, value) is Some(action) else {
      println(
        "macOS accessibility action decode failed: unsupported kind=\{kind}",
      )
      continue
    }
    let request : @runtime.PerformSemanticsActionRequest = {
      target: ByNodeId(@core.SemanticsNodeId::new(node_id)),
      action,
      precondition: Exact(@core.SemanticsGeneration::new(generation)),
    }
    match driver.perform_semantics_action(request) {
      Ok(receipt) => {
        let message = "action-receipt node=\{node_text} kind=\{kind} before=\{receipt.before.to_wire()} after=\{receipt.after.to_wire()} pending=\{receipt.pending_work}"
        macos_record_accessibility_evidence(message)
        println("macOS accessibility \{message}")
      }
      Err(error) => {
        let message = "action-rejected node=\{node_text} kind=\{kind} generation=\{generation_text} error=\{Repr(error)}"
        macos_record_accessibility_evidence(message)
        println("macOS accessibility \{message}")
      }
    }
  }
}

///|
fn MacosNativeHostBackend::sync_accessibility_window(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  guard self.platform_slots.lookup_host(window_id) is Some(platform_slot) &&
    self.lifecycle.runtime_slots().lookup(window_id) is Some(runtime_slot) &&
    macos_native_view_handle(platform_slot.window) is Some(raw_view) else {
    return
  }
  self.dispatch_accessibility_actions(raw_view, runtime_slot.driver)
  let binding = self.accessibility_state.binding(window_id)
  let read_result = match binding.cursor {
    Some(generation) => runtime_slot.driver.read_semantics(since=generation)
    None => runtime_slot.driver.read_semantics()
  }
  match read_result {
    Ok(read) =>
      match macos_semantics_read_json(read) {
        Some(payload) => {
          let encoded = @utf8.encode(payload.stringify(), bom=false)
          if macos_accessibility_sync_native(raw_view, encoded) == 0 {
            binding.cursor = match read {
              Full(snapshot) => Some(snapshot.generation())
              Delta(delta) => Some(delta.to())
              Unchanged(generation) => Some(generation)
            }
          }
        }
        None => ()
      }
    Err(_) => ()
  }
}

///|
fn MacosNativeHostBackend::sync_accessibility_windows(
  self : MacosNativeHostBackend,
) -> Unit {
  for slot in self.lifecycle.runtime_slots().open_slots() {
    self.sync_accessibility_window(slot.id)
  }
}

///|
fn MacosNativeHostBackend::dispose_accessibility_window(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  match self.platform_slots.lookup_host(window_id) {
    Some(platform_slot) =>
      match macos_native_view_handle(platform_slot.window) {
        Some(raw_view) => macos_accessibility_dispose_native(raw_view)
        None => ()
      }
    None => ()
  }
  self.accessibility_state.remove(window_id)
}
