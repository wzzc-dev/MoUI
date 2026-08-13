///|
priv struct WindowsAccessibilityBinding {
  window_id : @host.WindowId
  mut cursor : @core.SemanticsGeneration?
  mut attached : Bool
}

///|
priv struct WindowsAccessibilityState {
  mut bindings : Array[WindowsAccessibilityBinding]
}

///|
fn WindowsAccessibilityState::new() -> WindowsAccessibilityState {
  { bindings: [] }
}

///|
fn WindowsAccessibilityState::binding(
  self : WindowsAccessibilityState,
  window_id : @host.WindowId,
) -> WindowsAccessibilityBinding {
  for binding in self.bindings {
    if binding.window_id == window_id {
      return binding
    }
  }
  let binding = { window_id, cursor: None, attached: false }
  self.bindings.push(binding)
  binding
}

///|
fn WindowsAccessibilityState::remove(
  self : WindowsAccessibilityState,
  window_id : @host.WindowId,
) -> Unit {
  self.bindings = self.bindings.filter(binding => binding.window_id != window_id)
}

///|
extern "C" fn windows_accessibility_attach_native(hwnd : UInt64) -> Int = "moui_windows_accessibility_attach"

///|
extern "C" fn windows_accessibility_begin_native(
  hwnd : UInt64,
  full : Int,
  generation : UInt64,
  root : UInt64,
  focused : UInt64,
  semantic_focused : UInt64,
) -> Int = "moui_windows_accessibility_begin"

///|
extern "C" fn windows_accessibility_remove_native(
  hwnd : UInt64,
  node_id : UInt64,
) -> Unit = "moui_windows_accessibility_remove"

///|
#borrow(semantic_id, role, label, value, description, children, labelled_by, described_by, controls, error_message, active_descendant)
extern "C" fn windows_accessibility_upsert_native(
  hwnd : UInt64,
  node_id : UInt64,
  generation : UInt64,
  semantic_id : Bytes,
  role : Bytes,
  label : Bytes,
  value : Bytes,
  description : Bytes,
  state_flags : UInt64,
  checked : Int,
  numeric_flags : Int,
  numeric_current : Double,
  numeric_min : Double,
  numeric_max : Double,
  numeric_step : Double,
  text_flags : Int,
  selection_start : Int,
  selection_end : Int,
  caret : Int,
  row_index : Int,
  row_count : Int,
  row_span : Int,
  column_index : Int,
  column_count : Int,
  column_span : Int,
  set_size : Int,
  set_position : Int,
  action_flags : UInt64,
  live : Int,
  live_atomic : Int,
  frame_x : Double,
  frame_y : Double,
  frame_width : Double,
  frame_height : Double,
  children : Bytes,
  labelled_by : Bytes,
  described_by : Bytes,
  controls : Bytes,
  error_message : Bytes,
  active_descendant : Bytes,
) -> Unit = "moui_windows_accessibility_upsert"

///|
extern "C" fn windows_accessibility_end_native(hwnd : UInt64) -> Unit = "moui_windows_accessibility_end"

///|
#borrow(text)
extern "C" fn windows_accessibility_announce_native(
  hwnd : UInt64,
  node_id : UInt64,
  live : Int,
  is_atomic : Int,
  text : Bytes,
) -> Unit = "moui_windows_accessibility_announce"

///|
extern "C" fn windows_accessibility_take_action_native(hwnd : UInt64) -> Bytes = "moui_windows_accessibility_take_action"

///|
extern "C" fn windows_accessibility_dispose_native(hwnd : UInt64) -> Unit = "moui_windows_accessibility_dispose"

///|
fn windows_semantics_role_code(role : @core.SemanticsRole) -> String {
  match role {
    @core.SemanticsRole::None => "none"
    @core.SemanticsRole::Text => "text"
    @core.SemanticsRole::Link => "link"
    @core.SemanticsRole::Heading => "heading"
    @core.SemanticsRole::Navigation => "navigation"
    @core.SemanticsRole::Main => "main"
    @core.SemanticsRole::Button => "button"
    @core.SemanticsRole::Checkbox => "checkbox"
    @core.SemanticsRole::TextField => "text_field"
    @core.SemanticsRole::List => "list"
    @core.SemanticsRole::ListItem => "list_item"
    @core.SemanticsRole::Grid => "grid"
    @core.SemanticsRole::ScrollView => "scroll_view"
    @core.SemanticsRole::Switch => "switch"
    @core.SemanticsRole::Radio => "radio"
    @core.SemanticsRole::Slider => "slider"
    @core.SemanticsRole::Progress => "progress"
    @core.SemanticsRole::Tab => "tab"
    @core.SemanticsRole::Dialog => "dialog"
    @core.SemanticsRole::Tooltip => "tooltip"
    @core.SemanticsRole::Menu => "menu"
    @core.SemanticsRole::ButtonGroup => "button_group"
    @core.SemanticsRole::Form => "form"
    @core.SemanticsRole::FormField => "form_field"
    @core.SemanticsRole::Tree => "tree"
    @core.SemanticsRole::TreeItem => "tree_item"
    @core.SemanticsRole::Group => "group"
    @core.SemanticsRole::WebView => "web_view"
    @core.SemanticsRole::Image => "image"
    @core.SemanticsRole::Alert => "alert"
    @core.SemanticsRole::Status => "status"
    @core.SemanticsRole::ComboBox => "combo_box"
    @core.SemanticsRole::Option => "option"
    @core.SemanticsRole::Table => "table"
    @core.SemanticsRole::Row => "row"
    @core.SemanticsRole::Cell => "cell"
    @core.SemanticsRole::Separator => "separator"
  }
}

///|
fn windows_state_flags(state : @core.SemanticsState) -> UInt64 {
  let mut flags = 0UL
  if state.focused {
    flags = flags | 1UL
  }
  if state.disabled {
    flags = flags | 2UL
  }
  if state.selected {
    flags = flags | 4UL
  }
  if state.pressed {
    flags = flags | 8UL
  }
  if state.expanded {
    flags = flags | 16UL
  }
  if state.invalid {
    flags = flags | 32UL
  }
  if state.required {
    flags = flags | 64UL
  }
  if state.read_only {
    flags = flags | 128UL
  }
  if state.busy {
    flags = flags | 256UL
  }
  if state.multiline {
    flags = flags | 512UL
  }
  if state.password {
    flags = flags | 1024UL
  }
  if state.modal {
    flags = flags | 2048UL
  }
  flags
}

///|
fn windows_checked_code(value : @core.SemanticsCheckedState?) -> Int {
  match value {
    Some(@core.SemanticsCheckedState::Unchecked) => 0
    Some(@core.SemanticsCheckedState::Checked) => 1
    Some(@core.SemanticsCheckedState::Mixed) => 2
    None => -1
  }
}

///|
fn windows_action_flag(kind : @core.SemanticsActionKind) -> UInt64 {
  match kind {
    @core.SemanticsActionKind::Activate => 1UL
    @core.SemanticsActionKind::Focus => 2UL
    @core.SemanticsActionKind::SetText => 4UL
    @core.SemanticsActionKind::Submit => 8UL
    @core.SemanticsActionKind::Scroll => 16UL
    @core.SemanticsActionKind::Select => 32UL
    @core.SemanticsActionKind::Expand => 64UL
    @core.SemanticsActionKind::Collapse => 128UL
    @core.SemanticsActionKind::Dismiss => 256UL
    @core.SemanticsActionKind::Increment => 512UL
    @core.SemanticsActionKind::Decrement => 1024UL
    @core.SemanticsActionKind::SetNumericValue => 2048UL
    @core.SemanticsActionKind::SetSelection => 4096UL
    @core.SemanticsActionKind::ShowMenu => 8192UL
  }
}

///|
fn windows_action_flags(actions : Array[@core.SemanticsActionKind]) -> UInt64 {
  actions.fold(init=0UL, (flags, action) => flags | windows_action_flag(action))
}

///|
fn windows_live_code(value : @core.SemanticsLive) -> Int {
  match value {
    @core.SemanticsLive::Off => 0
    @core.SemanticsLive::Polite => 1
    @core.SemanticsLive::Assertive => 2
  }
}

///|
fn windows_node_ids_bytes(ids : Array[@core.SemanticsNodeId]) -> Bytes {
  @utf8.encode(ids.map(id => id.to_wire()).join(","), bom=false)
}

///|
fn windows_optional_int(value : Int?) -> Int {
  value.unwrap_or(-1)
}

///|
fn windows_sync_native_node(
  hwnd : UInt64,
  generation : @core.SemanticsGeneration,
  node : @core.SemanticsNode,
) -> Unit {
  let numeric_flags = match node.numeric {
    Some(numeric) =>
      (if numeric.current is Some(_) { 1 } else { 0 }) |
      (if numeric.min is Some(_) { 2 } else { 0 }) |
      (if numeric.max is Some(_) { 4 } else { 0 }) |
      (if numeric.step is Some(_) { 8 } else { 0 })
    None => 0
  }
  let numeric = node.numeric.unwrap_or(@core.SemanticsNumericValue::new())
  let text_flags = match node.text {
    Some(text) => if text.editable { 1 } else { 0 }
    None => 0
  }
  let text = node.text.unwrap_or(@core.SemanticsTextValue::new())
  let collection = node.collection.unwrap_or(
    @core.SemanticsCollectionInfo::new(),
  )
  windows_accessibility_upsert_native(
    hwnd,
    node.node_id.value(),
    generation.value(),
    @utf8.encode(
      node.semantic_id.map(id => id.value()).unwrap_or(""),
      bom=false,
    ),
    @utf8.encode(windows_semantics_role_code(node.role), bom=false),
    @utf8.encode(node.label, bom=false),
    @utf8.encode(node.value, bom=false),
    @utf8.encode(node.description, bom=false),
    windows_state_flags(node.state),
    windows_checked_code(node.state.checked),
    numeric_flags,
    numeric.current.unwrap_or(0.0),
    numeric.min.unwrap_or(0.0),
    numeric.max.unwrap_or(0.0),
    numeric.step.unwrap_or(0.0),
    text_flags,
    windows_optional_int(text.selection.map(range => range.start)),
    windows_optional_int(text.selection.map(range => range.end)),
    windows_optional_int(text.caret),
    windows_optional_int(collection.row_index),
    windows_optional_int(collection.row_count),
    windows_optional_int(collection.row_span),
    windows_optional_int(collection.column_index),
    windows_optional_int(collection.column_count),
    windows_optional_int(collection.column_span),
    windows_optional_int(collection.set_size),
    windows_optional_int(collection.set_position),
    windows_action_flags(node.actions),
    windows_live_code(node.live),
    if node.live_atomic {
      1
    } else {
      0
    },
    node.frame.origin.x,
    node.frame.origin.y,
    node.frame.size.width,
    node.frame.size.height,
    windows_node_ids_bytes(node.children),
    windows_node_ids_bytes(node.relations.labelled_by),
    windows_node_ids_bytes(node.relations.described_by),
    windows_node_ids_bytes(node.relations.controls),
    windows_node_ids_bytes(node.relations.error_message),
    windows_node_ids_bytes(node.relations.active_descendant),
  )
}

///|
fn windows_optional_node_value(value : @core.SemanticsNodeId?) -> UInt64 {
  value.map(id => id.value()).unwrap_or(0UL)
}

///|
fn WindowsNativeHostBackend::publish_windows_accessibility_read(
  _self : WindowsNativeHostBackend,
  hwnd : UInt64,
  read : @runtime.SemanticsRead,
) -> Unit {
  match read {
    @runtime.SemanticsRead::Full(snapshot) => {
      if windows_accessibility_begin_native(
          hwnd,
          1,
          snapshot.generation().value(),
          windows_optional_node_value(snapshot.root()),
          windows_optional_node_value(snapshot.focused()),
          windows_optional_node_value(snapshot.semantic_focused()),
        ) ==
        0 {
        return
      }
      for node in snapshot.nodes() {
        windows_sync_native_node(hwnd, snapshot.generation(), node)
      }
    }
    @runtime.SemanticsRead::Delta(delta) => {
      if windows_accessibility_begin_native(
          hwnd,
          0,
          delta.to().value(),
          windows_optional_node_value(delta.root()),
          windows_optional_node_value(delta.focused()),
          windows_optional_node_value(delta.semantic_focused()),
        ) ==
        0 {
        return
      }
      for node_id in delta.removed() {
        windows_accessibility_remove_native(hwnd, node_id.value())
      }
      for node in delta.upserted() {
        windows_sync_native_node(hwnd, delta.to(), node)
      }
      for announcement in delta.announcements() {
        windows_accessibility_announce_native(
          hwnd,
          announcement.node_id.value(),
          windows_live_code(announcement.live),
          if announcement.is_atomic {
            1
          } else {
            0
          },
          @utf8.encode(announcement.text, bom=false),
        )
      }
    }
    @runtime.SemanticsRead::Unchanged(_) => return
  }
  windows_accessibility_end_native(hwnd)
}

///|
fn windows_parse_decimal_u64(value : String) -> UInt64? {
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
fn windows_json_string_field(
  fields : Map[String, Json],
  name : String,
) -> String? {
  match fields.get(name) {
    Some(Json::String(value)) => Some(value)
    _ => None
  }
}

///|
fn windows_native_semantics_action(
  kind : String,
  value : String,
) -> @core.SemanticsAction? {
  match kind {
    "activate" => Some(@core.SemanticsAction::Activate)
    "focus" => Some(@core.SemanticsAction::Focus)
    "set_text" => Some(@core.SemanticsAction::SetText(value))
    "submit" => Some(@core.SemanticsAction::Submit)
    "scroll_forward" => Some(@core.SemanticsAction::Scroll(Forward))
    "scroll_backward" => Some(@core.SemanticsAction::Scroll(Backward))
    "scroll_up" => Some(@core.SemanticsAction::Scroll(Up))
    "scroll_down" => Some(@core.SemanticsAction::Scroll(Down))
    "scroll_left" => Some(@core.SemanticsAction::Scroll(Left))
    "scroll_right" => Some(@core.SemanticsAction::Scroll(Right))
    "select" => Some(@core.SemanticsAction::Select)
    "expand" => Some(@core.SemanticsAction::Expand)
    "collapse" => Some(@core.SemanticsAction::Collapse)
    "dismiss" => Some(@core.SemanticsAction::Dismiss)
    "increment" => Some(@core.SemanticsAction::Increment)
    "decrement" => Some(@core.SemanticsAction::Decrement)
    "set_numeric_value" =>
      Some(@core.SemanticsAction::SetNumericValue(@string.parse_double(value))) catch {
        _ => None
      }
    "set_selection" =>
      match value.split(",").to_array() {
        [start_text, end_text] =>
          match
            (
              windows_parse_decimal_u64(start_text.to_owned()),
              windows_parse_decimal_u64(end_text.to_owned()),
            ) {
            (Some(start), Some(end)) if start <= 2147483647UL &&
              end <= 2147483647UL =>
              Some(
                @core.SemanticsAction::SetSelection(
                  @core.TextRange::new(start=start.to_int(), end=end.to_int()),
                ),
              )
            _ => None
          }
        _ => None
      }
    "show_menu" => Some(@core.SemanticsAction::ShowMenu)
    _ => None
  }
}

///|
fn windows_decode_accessibility_action(
  bytes : Bytes,
) -> @runtime.PerformSemanticsActionRequest? {
  if bytes.length() == 0 {
    return None
  }
  let parsed = @json.parse(@utf8.decode_lossy(bytes[:], ignore_bom=false)) catch {
    _ => return None
  }
  guard parsed is Json::Object(fields) &&
    windows_json_string_field(fields, "node_id") is Some(node_text) &&
    windows_json_string_field(fields, "generation") is Some(generation_text) &&
    windows_json_string_field(fields, "kind") is Some(kind) &&
    windows_parse_decimal_u64(node_text) is Some(node_id) &&
    windows_parse_decimal_u64(generation_text) is Some(generation) else {
    return None
  }
  let value = windows_json_string_field(fields, "value").unwrap_or("")
  guard windows_native_semantics_action(kind, value) is Some(action) else {
    return None
  }
  Some({
    target: @core.SemanticsTarget::ByNodeId(@core.SemanticsNodeId::new(node_id)),
    action,
    precondition: @runtime.SemanticsGenerationPrecondition::Exact(
      @core.SemanticsGeneration::new(generation),
    ),
  })
}

///|
fn WindowsNativeHostBackend::dispatch_windows_accessibility_actions(
  _self : WindowsNativeHostBackend,
  hwnd : UInt64,
  driver : @runtime.HostRuntimeDriver,
) -> Unit {
  for ;; {
    let bytes = windows_accessibility_take_action_native(hwnd)
    if bytes.length() == 0 {
      return
    }
    match windows_decode_accessibility_action(bytes) {
      Some(request) => ignore(driver.perform_semantics_action(request))
      None => ()
    }
  }
}

///|
fn WindowsNativeHostBackend::sync_accessibility_window(
  self : WindowsNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  guard self.platform_slots.lookup_host(window_id) is Some(platform_slot) &&
    self.lifecycle.runtime_slots().lookup(window_id) is Some(runtime_slot) else {
    return
  }
  let hwnd = platform_slot.window.native_window_handle()
  let binding = self.accessibility_state.binding(window_id)
  if !binding.attached {
    binding.attached = windows_accessibility_attach_native(hwnd) != 0
  }
  if !binding.attached {
    return
  }
  self.dispatch_windows_accessibility_actions(hwnd, runtime_slot.driver)
  let read = match binding.cursor {
    Some(generation) => runtime_slot.driver.read_semantics(since=generation)
    None => runtime_slot.driver.read_semantics()
  }
  match read {
    Ok(value) => {
      self.publish_windows_accessibility_read(hwnd, value)
      binding.cursor = match value {
        @runtime.SemanticsRead::Full(snapshot) => Some(snapshot.generation())
        @runtime.SemanticsRead::Delta(delta) => Some(delta.to())
        @runtime.SemanticsRead::Unchanged(generation) => Some(generation)
      }
    }
    Err(_) => ()
  }
}

///|
fn WindowsNativeHostBackend::sync_accessibility_windows(
  self : WindowsNativeHostBackend,
) -> Unit {
  for slot in self.lifecycle.runtime_slots().open_slots() {
    self.sync_accessibility_window(slot.id)
  }
}

///|
fn WindowsNativeHostBackend::dispose_accessibility_window(
  self : WindowsNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) =>
      windows_accessibility_dispose_native(slot.window.native_window_handle())
    None => ()
  }
  self.accessibility_state.remove(window_id)
}
