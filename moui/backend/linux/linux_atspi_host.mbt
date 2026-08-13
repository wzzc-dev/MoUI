///|
priv struct LinuxAtspiWindowBinding {
  window_id : @host.WindowId
  mut cursor : @core.SemanticsGeneration?
  mut attached : Bool
}

///|
priv struct LinuxAtspiHostState {
  mut bindings : Array[LinuxAtspiWindowBinding]
}

///|
fn LinuxAtspiHostState::new() -> LinuxAtspiHostState {
  { bindings: [] }
}

///|
fn LinuxAtspiHostState::binding(
  self : LinuxAtspiHostState,
  window_id : @host.WindowId,
) -> LinuxAtspiWindowBinding {
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
fn LinuxAtspiHostState::remove(
  self : LinuxAtspiHostState,
  window_id : @host.WindowId,
) -> Unit {
  self.bindings = self.bindings.filter(binding => binding.window_id != window_id)
}

///|
extern "C" fn linux_atspi_attach_native() -> Int = "moui_linux_atspi_attach"

///|
extern "C" fn linux_atspi_begin_native(
  window_id : UInt64,
  full : Int,
  generation : UInt64,
  root : UInt64,
  focused : UInt64,
  semantic_focused : UInt64,
) -> Int = "moui_linux_atspi_begin"

///|
#borrow(semantic_id, role, name, value, description, children, labelled_by, described_by, controls, error_message, active_descendant)
extern "C" fn linux_atspi_upsert_native(
  window_id : UInt64,
  node_id : UInt64,
  generation : UInt64,
  semantic_id : Bytes,
  role : Bytes,
  name : Bytes,
  value : Bytes,
  description : Bytes,
  state : UInt,
  checked : Int,
  numeric_flags : Int,
  current : Double,
  minimum : Double,
  maximum : Double,
  increment : Double,
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
  actions : UInt,
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
) -> Unit = "moui_linux_atspi_upsert"

///|
extern "C" fn linux_atspi_remove_native(
  window_id : UInt64,
  node_id : UInt64,
) -> Unit = "moui_linux_atspi_remove"

///|
extern "C" fn linux_atspi_end_native(window_id : UInt64) -> Unit = "moui_linux_atspi_end"

///|
#borrow(text)
extern "C" fn linux_atspi_announce_native(
  window_id : UInt64,
  node_id : UInt64,
  live : Int,
  is_atomic : Int,
  text : Bytes,
) -> Unit = "moui_linux_atspi_announce"

///|
extern "C" fn linux_atspi_take_action_native(window_id : UInt64) -> Bytes = "moui_linux_atspi_take_action"

///|
extern "C" fn linux_atspi_dispose_native(window_id : UInt64) -> Unit = "moui_linux_atspi_dispose"

///|
fn linux_atspi_state_flags(
  state : @core.SemanticsState,
  text : @core.SemanticsTextValue?,
) -> UInt {
  let mut flags = 0U
  if state.disabled {
    flags = flags | 1U
  }
  if state.focused {
    flags = flags | 2U
  }
  if state.selected {
    flags = flags | 4U
  }
  if state.pressed {
    flags = flags | 8U
  }
  if state.expanded {
    flags = flags | 16U
  }
  if state.read_only {
    flags = flags | 32U
  }
  if text.map(value => value.editable).unwrap_or(false) {
    flags = flags | 64U
  }
  if state.multiline {
    flags = flags | 128U
  }
  if state.password {
    flags = flags | 256U
  }
  if state.invalid {
    flags = flags | 512U
  }
  if state.required {
    flags = flags | 1024U
  }
  if state.busy {
    flags = flags | 2048U
  }
  if state.modal {
    flags = flags | 4096U
  }
  flags
}

///|
fn linux_atspi_action_flag(action : @core.SemanticsActionKind) -> UInt {
  match action {
    @core.SemanticsActionKind::Activate => 1U
    @core.SemanticsActionKind::Focus => 2U
    @core.SemanticsActionKind::SetText => 4U
    @core.SemanticsActionKind::Submit => 8U
    @core.SemanticsActionKind::Scroll => 16U
    @core.SemanticsActionKind::Select => 32U
    @core.SemanticsActionKind::Expand => 64U
    @core.SemanticsActionKind::Collapse => 128U
    @core.SemanticsActionKind::Dismiss => 256U
    @core.SemanticsActionKind::Increment => 512U
    @core.SemanticsActionKind::Decrement => 1024U
    @core.SemanticsActionKind::SetNumericValue => 2048U
    @core.SemanticsActionKind::SetSelection => 4096U
    @core.SemanticsActionKind::ShowMenu => 8192U
  }
}

///|
fn linux_atspi_action_flags(actions : Array[@core.SemanticsActionKind]) -> UInt {
  actions.fold(init=0U, (flags, action) => {
    flags | linux_atspi_action_flag(action)
  })
}

///|
fn linux_atspi_role_code(role : @core.SemanticsRole) -> String {
  match role {
    @core.SemanticsRole::Button => "push button"
    @core.SemanticsRole::Checkbox => "check box"
    @core.SemanticsRole::Switch => "check box"
    @core.SemanticsRole::Radio => "radio button"
    @core.SemanticsRole::Slider => "slider"
    @core.SemanticsRole::Progress => "progress bar"
    @core.SemanticsRole::TextField => "entry"
    @core.SemanticsRole::List => "list"
    @core.SemanticsRole::ListItem => "list item"
    @core.SemanticsRole::Grid => "table"
    @core.SemanticsRole::Table => "table"
    @core.SemanticsRole::Row => "table row"
    @core.SemanticsRole::Cell => "table cell"
    @core.SemanticsRole::Tree => "tree"
    @core.SemanticsRole::TreeItem => "tree item"
    @core.SemanticsRole::Dialog => "dialog"
    @core.SemanticsRole::Image => "image"
    @core.SemanticsRole::Separator => "separator"
    @core.SemanticsRole::Link => "link"
    @core.SemanticsRole::Heading => "heading"
    @core.SemanticsRole::Alert => "alert"
    @core.SemanticsRole::Status => "status"
    _ => "panel"
  }
}

///|
fn linux_atspi_optional(value : Int?) -> Int {
  value.unwrap_or(-1)
}

///|
fn linux_atspi_ids(ids : Array[@core.SemanticsNodeId]) -> Bytes {
  @utf8.encode(ids.map(id => id.to_wire()).join(","), bom=false)
}

///|
fn linux_atspi_publish_node(
  window_id : @host.WindowId,
  node : @core.SemanticsNode,
  generation : @core.SemanticsGeneration,
) -> Unit {
  let numeric = node.numeric.unwrap_or(@core.SemanticsNumericValue::new())
  let text = node.text.unwrap_or(@core.SemanticsTextValue::new())
  let collection = node.collection.unwrap_or(
    @core.SemanticsCollectionInfo::new(),
  )
  let numeric_flags = match node.numeric {
    Some(value) =>
      (if value.current is Some(_) { 1 } else { 0 }) |
      (if value.min is Some(_) { 2 } else { 0 }) |
      (if value.max is Some(_) { 4 } else { 0 }) |
      (if value.step is Some(_) { 8 } else { 0 })
    None => 0
  }
  linux_atspi_upsert_native(
    window_id.value.to_uint64(),
    node.node_id.value(),
    generation.value(),
    @utf8.encode(
      node.semantic_id.map(id => id.value()).unwrap_or(""),
      bom=false,
    ),
    @utf8.encode(linux_atspi_role_code(node.role), bom=false),
    @utf8.encode(node.label, bom=false),
    @utf8.encode(node.value, bom=false),
    @utf8.encode(node.description, bom=false),
    linux_atspi_state_flags(node.state, node.text),
    match node.state.checked {
      Some(@core.SemanticsCheckedState::Unchecked) => 0
      Some(@core.SemanticsCheckedState::Checked) => 1
      Some(@core.SemanticsCheckedState::Mixed) => 2
      None => -1
    },
    numeric_flags,
    numeric.current.unwrap_or(0.0),
    numeric.min.unwrap_or(0.0),
    numeric.max.unwrap_or(0.0),
    numeric.step.unwrap_or(0.0),
    linux_atspi_optional(text.selection.map(range => range.start)),
    linux_atspi_optional(text.selection.map(range => range.end)),
    linux_atspi_optional(text.caret),
    linux_atspi_optional(collection.row_index),
    linux_atspi_optional(collection.row_count),
    linux_atspi_optional(collection.row_span),
    linux_atspi_optional(collection.column_index),
    linux_atspi_optional(collection.column_count),
    linux_atspi_optional(collection.column_span),
    linux_atspi_optional(collection.set_size),
    linux_atspi_optional(collection.set_position),
    linux_atspi_action_flags(node.actions),
    match node.live {
      @core.SemanticsLive::Off => 0
      @core.SemanticsLive::Polite => 1
      @core.SemanticsLive::Assertive => 2
    },
    if node.live_atomic {
      1
    } else {
      0
    },
    node.frame.origin.x,
    node.frame.origin.y,
    node.frame.size.width,
    node.frame.size.height,
    linux_atspi_ids(node.children),
    linux_atspi_ids(node.relations.labelled_by),
    linux_atspi_ids(node.relations.described_by),
    linux_atspi_ids(node.relations.controls),
    linux_atspi_ids(node.relations.error_message),
    linux_atspi_ids(node.relations.active_descendant),
  )
}

///|
fn linux_atspi_parse_decimal_u64(value : String) -> UInt64? {
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
fn linux_atspi_json_string_field(
  fields : Map[String, Json],
  name : String,
) -> String? {
  match fields.get(name) {
    Some(Json::String(value)) => Some(value)
    _ => None
  }
}

///|
fn linux_atspi_native_semantics_action(
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
              linux_atspi_parse_decimal_u64(start_text.to_owned()),
              linux_atspi_parse_decimal_u64(end_text.to_owned()),
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
fn linux_atspi_decode_action(
  bytes : Bytes,
) -> @runtime.PerformSemanticsActionRequest? {
  if bytes.length() == 0 {
    return None
  }
  let parsed = @json.parse(@utf8.decode_lossy(bytes[:], ignore_bom=false)) catch {
    _ => return None
  }
  guard parsed is Json::Object(fields) &&
    linux_atspi_json_string_field(fields, "node_id") is Some(node_text) &&
    linux_atspi_json_string_field(fields, "generation") is Some(generation_text) &&
    linux_atspi_json_string_field(fields, "kind") is Some(kind) &&
    linux_atspi_parse_decimal_u64(node_text) is Some(node_id) &&
    linux_atspi_parse_decimal_u64(generation_text) is Some(generation) else {
    return None
  }
  let value = linux_atspi_json_string_field(fields, "value").unwrap_or("")
  guard linux_atspi_native_semantics_action(kind, value) is Some(action) else {
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
fn LinuxNativeHostBackend::dispatch_atspi_actions(
  _self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
  driver : @runtime.HostRuntimeDriver,
) -> Unit {
  for ;; {
    let bytes = linux_atspi_take_action_native(window_id.value.to_uint64())
    if bytes.length() == 0 {
      return
    }
    match linux_atspi_decode_action(bytes) {
      Some(request) => ignore(driver.perform_semantics_action(request))
      None => ()
    }
  }
}

///|
fn LinuxNativeHostBackend::sync_atspi_window(
  self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  guard self.lifecycle.runtime_slots().lookup(window_id) is Some(runtime_slot) else {
    return
  }
  let binding = self.atspi_state.binding(window_id)
  if !binding.attached {
    binding.attached = linux_atspi_attach_native() != 0
  }
  if !binding.attached {
    return
  }
  self.dispatch_atspi_actions(window_id, runtime_slot.driver)
  let read = match binding.cursor {
    Some(generation) => runtime_slot.driver.read_semantics(since=generation)
    None => runtime_slot.driver.read_semantics()
  }
  match read {
    Ok(@runtime.SemanticsRead::Full(snapshot)) => {
      if linux_atspi_begin_native(
          window_id.value.to_uint64(),
          1,
          snapshot.generation().value(),
          snapshot.root().map(id => id.value()).unwrap_or(0UL),
          snapshot.focused().map(id => id.value()).unwrap_or(0UL),
          snapshot.semantic_focused().map(id => id.value()).unwrap_or(0UL),
        ) ==
        0 {
        return
      }
      for node in snapshot.nodes() {
        linux_atspi_publish_node(window_id, node, snapshot.generation())
      }
      linux_atspi_end_native(window_id.value.to_uint64())
      binding.cursor = Some(snapshot.generation())
    }
    Ok(@runtime.SemanticsRead::Delta(delta)) => {
      if linux_atspi_begin_native(
          window_id.value.to_uint64(),
          0,
          delta.to().value(),
          delta.root().map(id => id.value()).unwrap_or(0UL),
          delta.focused().map(id => id.value()).unwrap_or(0UL),
          delta.semantic_focused().map(id => id.value()).unwrap_or(0UL),
        ) ==
        0 {
        return
      }
      for node_id in delta.removed() {
        linux_atspi_remove_native(window_id.value.to_uint64(), node_id.value())
      }
      for node in delta.upserted() {
        linux_atspi_publish_node(window_id, node, delta.to())
      }
      for announcement in delta.announcements() {
        linux_atspi_announce_native(
          window_id.value.to_uint64(),
          announcement.node_id.value(),
          match announcement.live {
            @core.SemanticsLive::Off => 0
            @core.SemanticsLive::Polite => 1
            @core.SemanticsLive::Assertive => 2
          },
          if announcement.is_atomic {
            1
          } else {
            0
          },
          @utf8.encode(announcement.text, bom=false),
        )
      }
      linux_atspi_end_native(window_id.value.to_uint64())
      binding.cursor = Some(delta.to())
    }
    Ok(@runtime.SemanticsRead::Unchanged(generation)) =>
      binding.cursor = Some(generation)
    Err(_) => ()
  }
}

///|
fn LinuxNativeHostBackend::dispose_atspi_window(
  self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  linux_atspi_dispose_native(window_id.value.to_uint64())
  self.atspi_state.remove(window_id)
}
