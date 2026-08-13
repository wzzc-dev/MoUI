///|
pub(all) struct AriaNode {
  node_id : @core.SemanticsNodeId
  semantic_id : String?
  role : String
  level : Int?
  url : String
  label : String
  value : String
  description : String
  checked : String?
  selected : Bool
  expanded : Bool
  invalid : Bool
  required : Bool
  focused : Bool
  disabled : Bool
  read_only : Bool
  busy : Bool
  multiline : Bool
  password : Bool
  modal : Bool
  numeric : @core.SemanticsNumericValue?
  text : @core.SemanticsTextValue?
  collection : @core.SemanticsCollectionInfo?
  labelled_by : Array[@core.SemanticsNodeId]
  described_by : Array[@core.SemanticsNodeId]
  controls : Array[@core.SemanticsNodeId]
  error_message : Array[@core.SemanticsNodeId]
  active_descendant : Array[@core.SemanticsNodeId]
  live : @core.SemanticsLive
  live_atomic : Bool
  actions : Array[String]
  frame : @core.Rect
  children : Array[@core.SemanticsNodeId]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AriaSemanticsUpdate {
  kind : String
  generation : @core.SemanticsGeneration
  root : @core.SemanticsNodeId?
  focused : @core.SemanticsNodeId?
  semantic_focused : @core.SemanticsNodeId?
  nodes : Array[AriaNode]
  removed : Array[@core.SemanticsNodeId]
} derive(Eq, Debug, ToJson)

///|
pub fn semantics_to_aria(node : @core.SemanticsNode) -> AriaNode {
  {
    node_id: node.node_id,
    semantic_id: match node.semantic_id {
      Some(id) => Some(id.value())
      None => None
    },
    role: aria_role(node.role),
    level: node.level,
    url: node.url,
    label: node.label,
    value: node.value,
    description: node.description,
    checked: aria_checked(node),
    selected: node.state.selected,
    expanded: node.state.expanded,
    invalid: node.state.invalid,
    required: node.state.required,
    focused: node.state.focused,
    disabled: node.state.disabled,
    read_only: node.state.read_only,
    busy: node.state.busy,
    multiline: node.state.multiline,
    password: node.state.password,
    modal: node.state.modal,
    numeric: node.numeric,
    text: node.text,
    collection: node.collection,
    labelled_by: node.relations.labelled_by.copy(),
    described_by: node.relations.described_by.copy(),
    controls: node.relations.controls.copy(),
    error_message: node.relations.error_message.copy(),
    active_descendant: node.relations.active_descendant.copy(),
    live: node.live,
    live_atomic: node.live_atomic,
    actions: node.actions.map(aria_action),
    frame: node.frame,
    children: node.children.copy(),
  }
}

///|
pub fn aria_update_from_semantics_read(
  read : @runtime.SemanticsRead,
) -> AriaSemanticsUpdate? {
  match read {
    @runtime.SemanticsRead::Full(snapshot) =>
      Some({
        kind: "full",
        generation: snapshot.generation(),
        root: snapshot.root(),
        focused: snapshot.focused(),
        semantic_focused: snapshot.semantic_focused(),
        nodes: snapshot.nodes().map(semantics_to_aria),
        removed: [],
      })
    @runtime.SemanticsRead::Delta(delta) =>
      Some({
        kind: "delta",
        generation: delta.to(),
        root: delta.root(),
        focused: delta.focused(),
        semantic_focused: delta.semantic_focused(),
        nodes: delta.upserted().map(semantics_to_aria),
        removed: delta.removed(),
      })
    @runtime.SemanticsRead::Unchanged(_) => None
  }
}

///|
priv struct WebSemanticsRuntimeBinding {
  raw_id : Int
  canvas_id : String
  driver : @runtime.HostRuntimeDriver
  mut cursor : @core.SemanticsGeneration?
}

///|
let web_semantics_runtime_bindings : Array[WebSemanticsRuntimeBinding] = []

///|
fn register_web_semantics_runtime(
  raw_id : Int,
  canvas_id : String,
  driver : @runtime.HostRuntimeDriver,
) -> Unit {
  unregister_web_semantics_runtime(raw_id)
  web_semantics_runtime_bindings.push({
    raw_id,
    canvas_id,
    driver,
    cursor: None,
  })
}

///|
fn unregister_web_semantics_runtime(raw_id : Int) -> Unit {
  let retained : Array[WebSemanticsRuntimeBinding] = []
  for binding in web_semantics_runtime_bindings {
    if binding.raw_id != raw_id {
      retained.push(binding)
    }
  }
  web_semantics_runtime_bindings.clear()
  web_semantics_runtime_bindings.append(retained)
  web_remove_semantics_host(raw_id)
}

///|
fn sync_web_semantics_binding(binding : WebSemanticsRuntimeBinding) -> Unit {
  let read = match binding.cursor {
    Some(cursor) => binding.driver.read_semantics(since=cursor)
    None => binding.driver.read_semantics()
  }
  match read {
    Ok(read) =>
      match aria_update_from_semantics_read(read) {
        Some(update) => {
          web_sync_semantics_host(
            binding.raw_id,
            web_host_string(binding.canvas_id),
            web_host_string((ToJson::to_json(update) : Json).stringify()),
          )
          binding.cursor = Some(update.generation)
        }
        None => ()
      }
    Err(_) => ()
  }
}

///|
fn sync_all_web_semantics() -> Unit {
  for binding in web_semantics_runtime_bindings {
    sync_web_semantics_binding(binding)
  }
}

///|
priv struct WebSemanticsActionEvidence {
  raw_id : Int
  node_id : String
  request_generation : String
  action : String
  status : String
  before : String
  after : String
  pending_work : Bool
  error : String
} derive(ToJson)

///|
fn record_web_semantics_action_evidence(
  evidence : WebSemanticsActionEvidence,
) -> Unit {
  web_record_semantics_action_host(
    evidence.raw_id,
    web_host_string((ToJson::to_json(evidence) : Json).stringify()),
  )
}

///|
pub fn web_dispatch_semantics_action(
  raw_id : Int,
  node_id_text_id : Int,
  generation_text_id : Int,
  action_code : Int,
  value_id : Int,
  direction_code : Int,
) -> Unit {
  if node_id_text_id <= 0 || generation_text_id <= 0 {
    return ()
  }
  guard parse_decimal_u64(web_host_string_from_id(node_id_text_id))
    is Some(node_id) else {
    return ()
  }
  guard parse_decimal_u64(web_host_string_from_id(generation_text_id))
    is Some(generation) else {
    return ()
  }
  let value = if value_id > 0 { web_host_string_from_id(value_id) } else { "" }
  guard web_semantics_action(action_code, value, direction_code) is Some(action) else {
    return ()
  }
  for binding in web_semantics_runtime_bindings {
    if binding.raw_id == raw_id {
      let request_generation = @core.SemanticsGeneration::new(generation)
      let kind = action.kind()
      match
        binding.driver.perform_semantics_action({
          target: @core.SemanticsTarget::ByNodeId(
            @core.SemanticsNodeId::new(node_id),
          ),
          action,
          precondition: @runtime.SemanticsGenerationPrecondition::Exact(
            request_generation,
          ),
        }) {
        Ok(receipt) =>
          record_web_semantics_action_evidence({
            raw_id,
            node_id: node_id.to_string(radix=10),
            request_generation: request_generation.to_wire(),
            action: aria_action(kind),
            status: "passed",
            before: receipt.before.to_wire(),
            after: receipt.after.to_wire(),
            pending_work: receipt.pending_work,
            error: "",
          })
        Err(error) =>
          record_web_semantics_action_evidence({
            raw_id,
            node_id: node_id.to_string(radix=10),
            request_generation: request_generation.to_wire(),
            action: aria_action(kind),
            status: "rejected",
            before: "",
            after: "",
            pending_work: false,
            error: "\{Repr(error)}",
          })
      }
      sync_web_semantics_binding(binding)
      return ()
    }
  }
}

///|
fn parse_decimal_u64(value : String) -> UInt64? {
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
fn web_semantics_action(
  code : Int,
  value : String,
  direction_code : Int,
) -> @core.SemanticsAction? {
  match code {
    0 => Some(@core.SemanticsAction::Activate)
    1 => Some(@core.SemanticsAction::Focus)
    2 => Some(@core.SemanticsAction::SetText(value))
    3 => Some(@core.SemanticsAction::Submit)
    4 =>
      match web_semantics_scroll_direction(direction_code) {
        Some(direction) => Some(@core.SemanticsAction::Scroll(direction))
        None => None
      }
    5 => Some(@core.SemanticsAction::Select)
    6 => Some(@core.SemanticsAction::Expand)
    7 => Some(@core.SemanticsAction::Collapse)
    8 => Some(@core.SemanticsAction::Dismiss)
    9 => Some(@core.SemanticsAction::Increment)
    10 => Some(@core.SemanticsAction::Decrement)
    11 =>
      Some(@core.SemanticsAction::SetNumericValue(@string.parse_double(value))) catch {
        _ => None
      }
    12 => Some(@core.SemanticsAction::ShowMenu)
    13 =>
      match value.split(",").to_array() {
        [start_text, end_text] =>
          match
            (
              parse_decimal_u64(start_text.to_owned()),
              parse_decimal_u64(end_text.to_owned()),
            ) {
            (Some(start), Some(end)) =>
              Some(
                @core.SemanticsAction::SetSelection(
                  @core.TextRange::new(start=start.to_int(), end=end.to_int()),
                ),
              )
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn web_semantics_scroll_direction(
  code : Int,
) -> @core.SemanticsScrollDirection? {
  match code {
    0 => Some(@core.SemanticsScrollDirection::Forward)
    1 => Some(@core.SemanticsScrollDirection::Backward)
    2 => Some(@core.SemanticsScrollDirection::Up)
    3 => Some(@core.SemanticsScrollDirection::Down)
    4 => Some(@core.SemanticsScrollDirection::Left)
    5 => Some(@core.SemanticsScrollDirection::Right)
    _ => None
  }
}

///|
fn web_sync_semantics_host(
  raw_id : Int,
  canvas_id : WebHostString,
  json : WebHostString,
) -> Unit = "window_web" "sync_semantics"

///|
fn web_remove_semantics_host(raw_id : Int) -> Unit = "window_web" "remove_semantics"

///|
fn web_record_semantics_action_host(raw_id : Int, json : WebHostString) -> Unit = "window_web" "record_semantics_action"

///|
fn aria_role(role : @core.SemanticsRole) -> String {
  match role {
    @core.SemanticsRole::None => "presentation"
    @core.SemanticsRole::Text => ""
    @core.SemanticsRole::Link => "link"
    @core.SemanticsRole::Heading => "heading"
    @core.SemanticsRole::Navigation => "navigation"
    @core.SemanticsRole::Main => "main"
    @core.SemanticsRole::Button => "button"
    @core.SemanticsRole::Checkbox => "checkbox"
    @core.SemanticsRole::TextField => "textbox"
    @core.SemanticsRole::List => "list"
    @core.SemanticsRole::ListItem => "listitem"
    @core.SemanticsRole::Grid => "grid"
    @core.SemanticsRole::ScrollView => "region"
    @core.SemanticsRole::Switch => "switch"
    @core.SemanticsRole::Radio => "radio"
    @core.SemanticsRole::Slider => "slider"
    @core.SemanticsRole::Progress => "progressbar"
    @core.SemanticsRole::Tab => "tab"
    @core.SemanticsRole::Dialog => "dialog"
    @core.SemanticsRole::Tooltip => "tooltip"
    @core.SemanticsRole::Menu => "menu"
    @core.SemanticsRole::WebView => "document"
    @core.SemanticsRole::ButtonGroup => "group"
    @core.SemanticsRole::Form => "form"
    @core.SemanticsRole::FormField => "group"
    @core.SemanticsRole::Tree => "tree"
    @core.SemanticsRole::TreeItem => "treeitem"
    @core.SemanticsRole::Group => "group"
    @core.SemanticsRole::Image => "img"
    @core.SemanticsRole::Alert => "alert"
    @core.SemanticsRole::Status => "status"
    @core.SemanticsRole::ComboBox => "combobox"
    @core.SemanticsRole::Option => "option"
    @core.SemanticsRole::Table => "table"
    @core.SemanticsRole::Row => "row"
    @core.SemanticsRole::Cell => "cell"
    @core.SemanticsRole::Separator => "separator"
  }
}

///|
fn aria_checked(node : @core.SemanticsNode) -> String? {
  if node.role == @core.SemanticsRole::Checkbox ||
    node.role == @core.SemanticsRole::Switch ||
    node.role == @core.SemanticsRole::Radio {
    match node.state.checked {
      Some(@core.SemanticsCheckedState::Unchecked) => Some("false")
      Some(@core.SemanticsCheckedState::Checked) => Some("true")
      Some(@core.SemanticsCheckedState::Mixed) => Some("mixed")
      None => None
    }
  } else {
    None
  }
}

///|
fn aria_action(action : @core.SemanticsActionKind) -> String {
  match action {
    @core.SemanticsActionKind::Activate => "activate"
    @core.SemanticsActionKind::Focus => "focus"
    @core.SemanticsActionKind::SetText => "set-text"
    @core.SemanticsActionKind::Submit => "submit"
    @core.SemanticsActionKind::Scroll => "scroll"
    @core.SemanticsActionKind::Select => "select"
    @core.SemanticsActionKind::Expand => "expand"
    @core.SemanticsActionKind::Collapse => "collapse"
    @core.SemanticsActionKind::Dismiss => "dismiss"
    @core.SemanticsActionKind::Increment => "increment"
    @core.SemanticsActionKind::Decrement => "decrement"
    @core.SemanticsActionKind::SetNumericValue => "set-numeric-value"
    @core.SemanticsActionKind::SetSelection => "set-selection"
    @core.SemanticsActionKind::ShowMenu => "show-menu"
  }
}
