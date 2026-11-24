///|
/// Lossless decimal parser for `UInt64` wire identifiers. JSON numbers lose
/// precision above 2^53, so ids travel as decimal strings.
fn decimal_u64(text : String) -> UInt64? {
  if text == "" {
    return None
  }
  let mut parsed = 0UL
  for character in text {
    let code = character.to_int()
    if code < '0' || code > '9' {
      return None
    }
    let digit = (code - ('0' : Int32)).to_uint64()
    if parsed > (18446744073709551615UL - digit) / 10UL {
      return None
    }
    parsed = parsed * 10UL + digit
  }
  Some(parsed)
}

///|
fn semantics_node_id_json(id : @core.SemanticsNodeId) -> Json {
  Json::string(id.to_wire())
}

///|
fn optional_semantics_node_id_json(id : @core.SemanticsNodeId?) -> Json {
  match id {
    Some(id) => semantics_node_id_json(id)
    None => Json::null()
  }
}

///|
fn semantics_node_id_from_json(value : Json?) -> @core.SemanticsNodeId? {
  match wire_string(value) {
    Some(text) =>
      match decimal_u64(text) {
        Some(id) => Some(@core.SemanticsNodeId::new(id))
        None => None
      }
    None => None
  }
}

///|
fn optional_semantics_node_id_from_json(
  value : Json?,
) -> @core.SemanticsNodeId? {
  match value {
    Some(Json::Null) | None => None
    _ => semantics_node_id_from_json(value)
  }
}

///|
fn semantics_generation_from_json(value : Json?) -> @core.SemanticsGeneration? {
  match wire_string(value) {
    Some(text) =>
      match decimal_u64(text) {
        Some(id) => Some(@core.SemanticsGeneration::new(id))
        None => None
      }
    None => None
  }
}

///|
fn semantics_role_name(role : @core.SemanticsRole) -> String {
  match role {
    @core.SemanticsRole::None => "None"
    @core.SemanticsRole::Text => "Text"
    @core.SemanticsRole::Link => "Link"
    @core.SemanticsRole::Heading => "Heading"
    @core.SemanticsRole::Navigation => "Navigation"
    @core.SemanticsRole::Main => "Main"
    @core.SemanticsRole::Button => "Button"
    @core.SemanticsRole::Checkbox => "Checkbox"
    @core.SemanticsRole::TextField => "TextField"
    @core.SemanticsRole::List => "List"
    @core.SemanticsRole::ListItem => "ListItem"
    @core.SemanticsRole::Grid => "Grid"
    @core.SemanticsRole::ScrollView => "ScrollView"
    @core.SemanticsRole::Switch => "Switch"
    @core.SemanticsRole::Radio => "Radio"
    @core.SemanticsRole::Slider => "Slider"
    @core.SemanticsRole::Progress => "Progress"
    @core.SemanticsRole::Tab => "Tab"
    @core.SemanticsRole::Dialog => "Dialog"
    @core.SemanticsRole::Tooltip => "Tooltip"
    @core.SemanticsRole::Menu => "Menu"
    @core.SemanticsRole::ButtonGroup => "ButtonGroup"
    @core.SemanticsRole::Form => "Form"
    @core.SemanticsRole::FormField => "FormField"
    @core.SemanticsRole::Tree => "Tree"
    @core.SemanticsRole::TreeItem => "TreeItem"
    @core.SemanticsRole::Group => "Group"
    @core.SemanticsRole::WebView => "WebView"
    @core.SemanticsRole::Image => "Image"
    @core.SemanticsRole::Alert => "Alert"
    @core.SemanticsRole::Status => "Status"
    @core.SemanticsRole::ComboBox => "ComboBox"
    @core.SemanticsRole::Option => "Option"
    @core.SemanticsRole::Table => "Table"
    @core.SemanticsRole::Row => "Row"
    @core.SemanticsRole::Cell => "Cell"
    @core.SemanticsRole::Separator => "Separator"
    @core.SemanticsRole::TabList => "TabList"
    @core.SemanticsRole::Toolbar => "Toolbar"
    @core.SemanticsRole::MenuItem => "MenuItem"
  }
}

///|
fn semantics_role_from_name(name : String) -> @core.SemanticsRole? {
  match name {
    "None" => Some(@core.SemanticsRole::None)
    "Text" => Some(@core.SemanticsRole::Text)
    "Link" => Some(@core.SemanticsRole::Link)
    "Heading" => Some(@core.SemanticsRole::Heading)
    "Navigation" => Some(@core.SemanticsRole::Navigation)
    "Main" => Some(@core.SemanticsRole::Main)
    "Button" => Some(@core.SemanticsRole::Button)
    "Checkbox" => Some(@core.SemanticsRole::Checkbox)
    "TextField" => Some(@core.SemanticsRole::TextField)
    "List" => Some(@core.SemanticsRole::List)
    "ListItem" => Some(@core.SemanticsRole::ListItem)
    "Grid" => Some(@core.SemanticsRole::Grid)
    "ScrollView" => Some(@core.SemanticsRole::ScrollView)
    "Switch" => Some(@core.SemanticsRole::Switch)
    "Radio" => Some(@core.SemanticsRole::Radio)
    "Slider" => Some(@core.SemanticsRole::Slider)
    "Progress" => Some(@core.SemanticsRole::Progress)
    "Tab" => Some(@core.SemanticsRole::Tab)
    "Dialog" => Some(@core.SemanticsRole::Dialog)
    "Tooltip" => Some(@core.SemanticsRole::Tooltip)
    "Menu" => Some(@core.SemanticsRole::Menu)
    "ButtonGroup" => Some(@core.SemanticsRole::ButtonGroup)
    "Form" => Some(@core.SemanticsRole::Form)
    "FormField" => Some(@core.SemanticsRole::FormField)
    "Tree" => Some(@core.SemanticsRole::Tree)
    "TreeItem" => Some(@core.SemanticsRole::TreeItem)
    "Group" => Some(@core.SemanticsRole::Group)
    "WebView" => Some(@core.SemanticsRole::WebView)
    "Image" => Some(@core.SemanticsRole::Image)
    "Alert" => Some(@core.SemanticsRole::Alert)
    "Status" => Some(@core.SemanticsRole::Status)
    "ComboBox" => Some(@core.SemanticsRole::ComboBox)
    "Option" => Some(@core.SemanticsRole::Option)
    "Table" => Some(@core.SemanticsRole::Table)
    "Row" => Some(@core.SemanticsRole::Row)
    "Cell" => Some(@core.SemanticsRole::Cell)
    "Separator" => Some(@core.SemanticsRole::Separator)
    "TabList" => Some(@core.SemanticsRole::TabList)
    "Toolbar" => Some(@core.SemanticsRole::Toolbar)
    "MenuItem" => Some(@core.SemanticsRole::MenuItem)
    _ => None
  }
}

///|
fn semantics_checked_name(state : @core.SemanticsCheckedState) -> String {
  match state {
    @core.SemanticsCheckedState::Unchecked => "Unchecked"
    @core.SemanticsCheckedState::Checked => "Checked"
    @core.SemanticsCheckedState::Mixed => "Mixed"
  }
}

///|
fn semantics_checked_from_name(name : String) -> @core.SemanticsCheckedState? {
  match name {
    "Unchecked" => Some(@core.SemanticsCheckedState::Unchecked)
    "Checked" => Some(@core.SemanticsCheckedState::Checked)
    "Mixed" => Some(@core.SemanticsCheckedState::Mixed)
    _ => None
  }
}

///|
fn semantics_live_name(live : @core.SemanticsLive) -> String {
  match live {
    @core.SemanticsLive::Off => "Off"
    @core.SemanticsLive::Polite => "Polite"
    @core.SemanticsLive::Assertive => "Assertive"
  }
}

///|
fn semantics_live_from_name(name : String) -> @core.SemanticsLive? {
  match name {
    "Off" => Some(@core.SemanticsLive::Off)
    "Polite" => Some(@core.SemanticsLive::Polite)
    "Assertive" => Some(@core.SemanticsLive::Assertive)
    _ => None
  }
}

///|
fn semantics_action_kind_name(kind : @core.SemanticsActionKind) -> String {
  match kind {
    @core.SemanticsActionKind::Activate => "Activate"
    @core.SemanticsActionKind::Focus => "Focus"
    @core.SemanticsActionKind::SetText => "SetText"
    @core.SemanticsActionKind::Submit => "Submit"
    @core.SemanticsActionKind::Scroll => "Scroll"
    @core.SemanticsActionKind::Select => "Select"
    @core.SemanticsActionKind::Expand => "Expand"
    @core.SemanticsActionKind::Collapse => "Collapse"
    @core.SemanticsActionKind::Dismiss => "Dismiss"
    @core.SemanticsActionKind::Increment => "Increment"
    @core.SemanticsActionKind::Decrement => "Decrement"
    @core.SemanticsActionKind::SetNumericValue => "SetNumericValue"
    @core.SemanticsActionKind::SetSelection => "SetSelection"
    @core.SemanticsActionKind::ShowMenu => "ShowMenu"
  }
}

///|
fn semantics_action_kind_from_name(name : String) -> @core.SemanticsActionKind? {
  match name {
    "Activate" => Some(@core.SemanticsActionKind::Activate)
    "Focus" => Some(@core.SemanticsActionKind::Focus)
    "SetText" => Some(@core.SemanticsActionKind::SetText)
    "Submit" => Some(@core.SemanticsActionKind::Submit)
    "Scroll" => Some(@core.SemanticsActionKind::Scroll)
    "Select" => Some(@core.SemanticsActionKind::Select)
    "Expand" => Some(@core.SemanticsActionKind::Expand)
    "Collapse" => Some(@core.SemanticsActionKind::Collapse)
    "Dismiss" => Some(@core.SemanticsActionKind::Dismiss)
    "Increment" => Some(@core.SemanticsActionKind::Increment)
    "Decrement" => Some(@core.SemanticsActionKind::Decrement)
    "SetNumericValue" => Some(@core.SemanticsActionKind::SetNumericValue)
    "SetSelection" => Some(@core.SemanticsActionKind::SetSelection)
    "ShowMenu" => Some(@core.SemanticsActionKind::ShowMenu)
    _ => None
  }
}

///|
fn optional_number_json(value : Double?) -> Json {
  match value {
    Some(value) => number_json(value)
    None => Json::null()
  }
}

///|
fn optional_string_json(value : String?) -> Json {
  match value {
    Some(value) => string_json(value)
    None => Json::null()
  }
}

///|
fn optional_int_text(value : Int32?) -> Json {
  match value {
    Some(value) => int_json(value)
    None => Json::null()
  }
}

///|
fn optional_int_from_json(value : Json?) -> Int32?? {
  match value {
    Some(Json::Null) | None => Some(None)
    _ =>
      match int_from_json(value) {
        Some(value) => Some(Some(value))
        None => None
      }
  }
}

///|
fn optional_number_from_json(value : Json?) -> Double?? {
  match value {
    Some(Json::Null) | None => Some(None)
    _ =>
      match wire_number(value) {
        Some(value) => Some(Some(value))
        None => None
      }
  }
}

///|
fn optional_string_from_json(value : Json?) -> String?? {
  match value {
    Some(Json::Null) | None => Some(None)
    _ =>
      match wire_string(value) {
        Some(value) => Some(Some(value))
        None => None
      }
  }
}

///|
fn semantics_state_json(state : @core.SemanticsState) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["focused"] = bool_json(state.focused)
  fields["disabled"] = bool_json(state.disabled)
  fields["selected"] = bool_json(state.selected)
  fields["pressed"] = bool_json(state.pressed)
  fields["checked"] = match state.checked {
    Some(checked) => string_json(semantics_checked_name(checked))
    None => Json::null()
  }
  fields["expanded"] = bool_json(state.expanded)
  fields["invalid"] = bool_json(state.invalid)
  fields["required"] = bool_json(state.required)
  fields["read_only"] = bool_json(state.read_only)
  fields["busy"] = bool_json(state.busy)
  fields["multiline"] = bool_json(state.multiline)
  fields["password"] = bool_json(state.password)
  fields["modal"] = bool_json(state.modal)
  Json::object(fields)
}

///|
fn semantics_state_from_json(value : Json?) -> @core.SemanticsState? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let focused = wire_bool(fields.get("focused")).unwrap_or(false)
  let disabled = wire_bool(fields.get("disabled")).unwrap_or(false)
  let selected = wire_bool(fields.get("selected")).unwrap_or(false)
  let pressed = wire_bool(fields.get("pressed")).unwrap_or(false)
  let checked = match fields.get("checked") {
    Some(Json::Null) | None => None
    Some(value) =>
      match wire_string(Some(value)) {
        Some(name) =>
          match semantics_checked_from_name(name) {
            Some(checked) => Some(checked)
            None => return None
          }
        None => return None
      }
  }
  Some(@core.SemanticsState::{
    focused,
    disabled,
    selected,
    pressed,
    checked,
    expanded: wire_bool(fields.get("expanded")).unwrap_or(false),
    invalid: wire_bool(fields.get("invalid")).unwrap_or(false),
    required: wire_bool(fields.get("required")).unwrap_or(false),
    read_only: wire_bool(fields.get("read_only")).unwrap_or(false),
    busy: wire_bool(fields.get("busy")).unwrap_or(false),
    multiline: wire_bool(fields.get("multiline")).unwrap_or(false),
    password: wire_bool(fields.get("password")).unwrap_or(false),
    modal: wire_bool(fields.get("modal")).unwrap_or(false),
  })
}

///|
fn semantics_numeric_json(value : @core.SemanticsNumericValue) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["current"] = optional_number_json(value.current)
  fields["min"] = optional_number_json(value.min)
  fields["max"] = optional_number_json(value.max)
  fields["step"] = optional_number_json(value.step)
  fields["value_text"] = optional_string_json(value.value_text)
  Json::object(fields)
}

///|
fn semantics_numeric_from_json(value : Json?) -> @core.SemanticsNumericValue? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let current = match optional_number_from_json(fields.get("current")) {
    Some(value) => value
    None => return None
  }
  let min = match optional_number_from_json(fields.get("min")) {
    Some(value) => value
    None => return None
  }
  let max = match optional_number_from_json(fields.get("max")) {
    Some(value) => value
    None => return None
  }
  let step = match optional_number_from_json(fields.get("step")) {
    Some(value) => value
    None => return None
  }
  let value_text = match optional_string_from_json(fields.get("value_text")) {
    Some(value) => value
    None => return None
  }
  Some(@core.SemanticsNumericValue::{ current, min, max, step, value_text, })
}

///|
fn semantics_text_json(value : @core.SemanticsTextValue) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["selection"] = optional_text_range_json(value.selection)
  fields["caret"] = optional_int_text(value.caret)
  fields["editable"] = bool_json(value.editable)
  Json::object(fields)
}

///|
fn semantics_text_from_json(value : Json?) -> @core.SemanticsTextValue? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let selection = match fields.get("selection") {
    Some(Json::Null) | None => None
    Some(value) =>
      match text_range_from_json(Some(value)) {
        Some(range) => Some(range)
        None => return None
      }
  }
  let caret = match optional_int_from_json(fields.get("caret")) {
    Some(value) => value
    None => return None
  }
  Some(@core.SemanticsTextValue::{
    selection,
    caret,
    editable: wire_bool(fields.get("editable")).unwrap_or(false),
  })
}

///|
fn semantics_collection_json(value : @core.SemanticsCollectionInfo) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["row_index"] = optional_int_text(value.row_index)
  fields["row_count"] = optional_int_text(value.row_count)
  fields["row_span"] = optional_int_text(value.row_span)
  fields["column_index"] = optional_int_text(value.column_index)
  fields["column_count"] = optional_int_text(value.column_count)
  fields["column_span"] = optional_int_text(value.column_span)
  fields["set_size"] = optional_int_text(value.set_size)
  fields["set_position"] = optional_int_text(value.set_position)
  Json::object(fields)
}

///|
fn semantics_collection_from_json(
  value : Json?,
) -> @core.SemanticsCollectionInfo? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let row_index = match optional_int_from_json(fields.get("row_index")) {
    Some(value) => value
    None => return None
  }
  let row_count = match optional_int_from_json(fields.get("row_count")) {
    Some(value) => value
    None => return None
  }
  let row_span = match optional_int_from_json(fields.get("row_span")) {
    Some(value) => value
    None => return None
  }
  let column_index = match optional_int_from_json(fields.get("column_index")) {
    Some(value) => value
    None => return None
  }
  let column_count = match optional_int_from_json(fields.get("column_count")) {
    Some(value) => value
    None => return None
  }
  let column_span = match optional_int_from_json(fields.get("column_span")) {
    Some(value) => value
    None => return None
  }
  let set_size = match optional_int_from_json(fields.get("set_size")) {
    Some(value) => value
    None => return None
  }
  let set_position = match optional_int_from_json(fields.get("set_position")) {
    Some(value) => value
    None => return None
  }
  Some(@core.SemanticsCollectionInfo::{
    row_index,
    row_count,
    row_span,
    column_index,
    column_count,
    column_span,
    set_size,
    set_position,
  })
}

///|
fn semantics_node_ids_json(ids : Array[@core.SemanticsNodeId]) -> Json {
  let items : Array[Json] = []
  for id in ids {
    items.push(semantics_node_id_json(id))
  }
  Json::array(items)
}

///|
fn semantics_node_ids_from_json(value : Json?) -> Array[@core.SemanticsNodeId]? {
  let items = match wire_array(value) {
    Some(items) => items
    None => return None
  }
  let ids : Array[@core.SemanticsNodeId] = []
  for item in items {
    match semantics_node_id_from_json(Some(item)) {
      Some(id) => ids.push(id)
      None => return None
    }
  }
  Some(ids)
}

///|
fn semantics_relations_json(relations : @core.SemanticsRelations) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["labelled_by"] = semantics_node_ids_json(relations.labelled_by)
  fields["described_by"] = semantics_node_ids_json(relations.described_by)
  fields["controls"] = semantics_node_ids_json(relations.controls)
  fields["error_message"] = semantics_node_ids_json(relations.error_message)
  fields["active_descendant"] = semantics_node_ids_json(
    relations.active_descendant,
  )
  Json::object(fields)
}

///|
fn semantics_relations_from_json(value : Json?) -> @core.SemanticsRelations? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let labelled_by = match
    semantics_node_ids_from_json(fields.get("labelled_by")) {
    Some(ids) => ids
    None => return None
  }
  let described_by = match
    semantics_node_ids_from_json(fields.get("described_by")) {
    Some(ids) => ids
    None => return None
  }
  let controls = match semantics_node_ids_from_json(fields.get("controls")) {
    Some(ids) => ids
    None => return None
  }
  let error_message = match
    semantics_node_ids_from_json(fields.get("error_message")) {
    Some(ids) => ids
    None => return None
  }
  let active_descendant = match
    semantics_node_ids_from_json(fields.get("active_descendant")) {
    Some(ids) => ids
    None => return None
  }
  Some(@core.SemanticsRelations::{
    labelled_by,
    described_by,
    controls,
    error_message,
    active_descendant,
  })
}

///|
fn semantics_actions_json(actions : Array[@core.SemanticsActionKind]) -> Json {
  let items : Array[Json] = []
  for action in actions {
    items.push(string_json(semantics_action_kind_name(action)))
  }
  Json::array(items)
}

///|
fn semantics_actions_from_json(
  value : Json?,
) -> Array[@core.SemanticsActionKind]? {
  let items = match wire_array(value) {
    Some(items) => items
    None => return None
  }
  let actions : Array[@core.SemanticsActionKind] = []
  for item in items {
    let name = match wire_string(Some(item)) {
      Some(name) => name
      None => return None
    }
    match semantics_action_kind_from_name(name) {
      Some(action) => actions.push(action)
      None => return None
    }
  }
  Some(actions)
}

///|
fn semantics_node_json(node : @core.SemanticsNode) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["node_id"] = semantics_node_id_json(node.node_id)
  fields["semantic_id"] = match node.semantic_id {
    Some(id) => string_json(id.value())
    None => Json::null()
  }
  fields["role"] = string_json(semantics_role_name(node.role))
  fields["level"] = optional_int_text(node.level)
  fields["url"] = string_json(node.url)
  fields["label"] = string_json(node.label)
  fields["value"] = string_json(node.value)
  fields["description"] = string_json(node.description)
  fields["state"] = semantics_state_json(node.state)
  fields["numeric"] = match node.numeric {
    Some(value) => semantics_numeric_json(value)
    None => Json::null()
  }
  fields["text"] = match node.text {
    Some(value) => semantics_text_json(value)
    None => Json::null()
  }
  fields["collection"] = match node.collection {
    Some(value) => semantics_collection_json(value)
    None => Json::null()
  }
  fields["relations"] = semantics_relations_json(node.relations)
  fields["live"] = string_json(semantics_live_name(node.live))
  fields["live_atomic"] = bool_json(node.live_atomic)
  fields["actions"] = semantics_actions_json(node.actions)
  fields["focus_order"] = optional_int_text(node.focus_order)
  fields["frame"] = rect_json(node.frame)
  fields["children"] = semantics_node_ids_json(node.children)
  Json::object(fields)
}

///|
fn semantics_node_from_json(value : Json) -> @core.SemanticsNode? {
  let fields = match wire_object(Some(value)) {
    Some(fields) => fields
    None => return None
  }
  let node_id = match semantics_node_id_from_json(fields.get("node_id")) {
    Some(id) => id
    None => return None
  }
  let semantic_id = match fields.get("semantic_id") {
    Some(Json::Null) | None => None
    Some(value) =>
      match wire_string(Some(value)) {
        Some(text) =>
          match @core.SemanticId::parse(text) {
            Some(id) => Some(id)
            None => return None
          }
        None => return None
      }
  }
  let role_name = match wire_string(fields.get("role")) {
    Some(name) => name
    None => return None
  }
  let role = match semantics_role_from_name(role_name) {
    Some(role) => role
    None => return None
  }
  let level = match optional_int_from_json(fields.get("level")) {
    Some(value) => value
    None => return None
  }
  let url = match wire_string(fields.get("url")) {
    Some(value) => value
    None => return None
  }
  let label = match wire_string(fields.get("label")) {
    Some(value) => value
    None => return None
  }
  let node_value = match wire_string(fields.get("value")) {
    Some(value) => value
    None => return None
  }
  let description = match wire_string(fields.get("description")) {
    Some(value) => value
    None => return None
  }
  let state = match semantics_state_from_json(fields.get("state")) {
    Some(value) => value
    None => return None
  }
  let numeric = match fields.get("numeric") {
    Some(Json::Null) | None => None
    Some(value) =>
      match semantics_numeric_from_json(Some(value)) {
        Some(numeric) => Some(numeric)
        None => return None
      }
  }
  let text = match fields.get("text") {
    Some(Json::Null) | None => None
    Some(value) =>
      match semantics_text_from_json(Some(value)) {
        Some(text) => Some(text)
        None => return None
      }
  }
  let collection = match fields.get("collection") {
    Some(Json::Null) | None => None
    Some(value) =>
      match semantics_collection_from_json(Some(value)) {
        Some(collection) => Some(collection)
        None => return None
      }
  }
  let relations = match semantics_relations_from_json(fields.get("relations")) {
    Some(value) => value
    None => return None
  }
  let live_name = match wire_string(fields.get("live")) {
    Some(name) => name
    None => return None
  }
  let live = match semantics_live_from_name(live_name) {
    Some(live) => live
    None => return None
  }
  let actions = match semantics_actions_from_json(fields.get("actions")) {
    Some(actions) => actions
    None => return None
  }
  let focus_order = match optional_int_from_json(fields.get("focus_order")) {
    Some(value) => value
    None => return None
  }
  let frame = match rect_from_json(fields.get("frame")) {
    Some(frame) => frame
    None => return None
  }
  let children = match semantics_node_ids_from_json(fields.get("children")) {
    Some(children) => children
    None => return None
  }
  Some(@core.SemanticsNode::{
    node_id,
    semantic_id,
    role,
    level,
    url,
    label,
    value: node_value,
    description,
    state,
    numeric,
    text,
    collection,
    relations,
    live,
    live_atomic: wire_bool(fields.get("live_atomic")).unwrap_or(false),
    actions,
    focus_order,
    frame,
    children,
  })
}

///|
fn semantics_payload_json(payload : @core.SemanticsFramePayload) -> Json {
  let nodes : Array[Json] = []
  let items = payload.nodes()
  for node in items {
    nodes.push(semantics_node_json(node))
  }
  let fields : Map[String, Json] = Map([])
  fields["generation"] = Json::string(payload.generation().to_wire())
  fields["root"] = optional_semantics_node_id_json(payload.root())
  fields["focused"] = optional_semantics_node_id_json(payload.focused())
  fields["nodes"] = Json::array(nodes)
  Json::object(fields)
}

///|
fn semantics_payload_from_json(value : Json?) -> @core.SemanticsFramePayload? {
  let fields = match wire_object(value) {
    Some(fields) => fields
    None => return None
  }
  let generation = match
    semantics_generation_from_json(fields.get("generation")) {
    Some(generation) => generation
    None => return None
  }
  let root = match fields.get("root") {
    Some(Json::Null) | None => None
    Some(_) =>
      match optional_semantics_node_id_from_json(fields.get("root")) {
        Some(id) => Some(id)
        None => return None
      }
  }
  let focused = match fields.get("focused") {
    Some(Json::Null) | None => None
    Some(_) =>
      match optional_semantics_node_id_from_json(fields.get("focused")) {
        Some(id) => Some(id)
        None => return None
      }
  }
  let nodes : Array[@core.SemanticsNode] = []
  let items = match wire_array(fields.get("nodes")) {
    Some(items) => items
    None => return None
  }
  for item in items {
    match semantics_node_from_json(item) {
      Some(node) => nodes.push(node)
      None => return None
    }
  }
  Some(@core.SemanticsFramePayload::new(generation~, nodes~, root~, focused~))
}
