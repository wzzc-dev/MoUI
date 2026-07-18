///|
pub(all) struct AriaNode {
  element_id : @core.ElementId
  role : String
  level : Int?
  url : String
  label : String
  value : String
  description : String
  checked : Bool?
  selected : Bool
  expanded : Bool
  invalid : Bool
  required : Bool
  focused : Bool
  disabled : Bool
  actions : Array[String]
  frame : @core.Rect
  children : Array[AriaNode]
} derive(Eq, Debug, ToJson)

///|
pub fn semantics_to_aria(node : @core.SemanticsNode) -> AriaNode {
  {
    element_id: node.element_id,
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
    actions: node.actions.map(action => aria_action(action)),
    frame: node.frame,
    children: node.children.map(child => semantics_to_aria(child)),
  }
}

///|
priv struct WebSemanticsRuntimeBinding {
  raw_id : Int
  runtime : @runtime.AppRuntime
}

///|
priv struct WebSemanticsSnapshot {
  raw_id : Int
  json : String
}

///|
let web_semantics_runtime_bindings : Array[WebSemanticsRuntimeBinding] = []

///|
let web_semantics_snapshots : Array[WebSemanticsSnapshot] = []

///|
fn register_web_semantics_runtime(
  raw_id : Int,
  runtime : @runtime.AppRuntime,
) -> Unit {
  unregister_web_semantics_runtime(raw_id)
  web_semantics_runtime_bindings.push({ raw_id, runtime })
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
  let retained_snapshots : Array[WebSemanticsSnapshot] = []
  for snapshot in web_semantics_snapshots {
    if snapshot.raw_id != raw_id {
      retained_snapshots.push(snapshot)
    }
  }
  web_semantics_snapshots.clear()
  web_semantics_snapshots.append(retained_snapshots)
  web_remove_semantics_host(raw_id)
}

///|
fn web_semantics_snapshot_matches(raw_id : Int, json : String) -> Bool {
  for snapshot in web_semantics_snapshots {
    if snapshot.raw_id == raw_id {
      return snapshot.json == json
    }
  }
  false
}

///|
fn web_cache_semantics_snapshot(raw_id : Int, json : String) -> Unit {
  let next : Array[WebSemanticsSnapshot] = []
  let mut replaced = false
  for snapshot in web_semantics_snapshots {
    if snapshot.raw_id == raw_id {
      next.push({ raw_id, json })
      replaced = true
    } else {
      next.push(snapshot)
    }
  }
  if !replaced {
    next.push({ raw_id, json })
  }
  web_semantics_snapshots.clear()
  web_semantics_snapshots.append(next)
}

///|
fn sync_web_semantics(
  raw_id : Int,
  canvas_id : String,
  semantics : @core.SemanticsNode,
) -> Unit {
  let json = (semantics_to_aria(semantics).to_json() : Json).stringify()
  if !web_semantics_snapshot_matches(raw_id, json) {
    web_sync_semantics_host(
      raw_id,
      web_host_string(canvas_id),
      web_host_string(json),
    )
    web_cache_semantics_snapshot(raw_id, json)
  }
}

///|
pub fn web_dispatch_semantics_action(
  raw_id : Int,
  element_id : Int,
  action_code : Int,
  value_id : Int,
) -> Unit {
  match web_semantics_action(action_code) {
    Some(action) =>
      for binding in web_semantics_runtime_bindings {
        if binding.raw_id == raw_id {
          let value = if value_id > 0 {
            Some(web_host_string_from_id(value_id))
          } else {
            None
          }
          if binding.runtime.dispatch_semantics_action(
              @core.ElementId::new(element_id),
              action,
              value~,
            ) {
            ()
          }
          return ()
        }
      }
    None => ()
  }
}

///|
fn web_semantics_action(code : Int) -> @core.SemanticsAction? {
  match code {
    0 => Some(@core.SemanticsAction::Activate)
    1 => Some(@core.SemanticsAction::Focus)
    2 => Some(@core.SemanticsAction::SetText)
    3 => Some(@core.SemanticsAction::Submit)
    4 => Some(@core.SemanticsAction::Scroll)
    5 => Some(@core.SemanticsAction::Select)
    6 => Some(@core.SemanticsAction::Expand)
    7 => Some(@core.SemanticsAction::Collapse)
    8 => Some(@core.SemanticsAction::Dismiss)
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
fn aria_role(role : @core.SemanticsRole) -> String {
  match role {
    @core.SemanticsRole::None => "presentation"
    @core.SemanticsRole::Text => "text"
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
  }
}

///|
fn aria_checked(node : @core.SemanticsNode) -> Bool? {
  if node.role == @core.SemanticsRole::Checkbox ||
    node.role == @core.SemanticsRole::Switch ||
    node.role == @core.SemanticsRole::Radio {
    Some(node.state.checked)
  } else {
    None
  }
}

///|
fn aria_action(action : @core.SemanticsAction) -> String {
  match action {
    @core.SemanticsAction::Activate => "activate"
    @core.SemanticsAction::Focus => "focus"
    @core.SemanticsAction::SetText => "set-text"
    @core.SemanticsAction::Submit => "submit"
    @core.SemanticsAction::Scroll => "scroll"
    @core.SemanticsAction::Select => "select"
    @core.SemanticsAction::Expand => "expand"
    @core.SemanticsAction::Collapse => "collapse"
    @core.SemanticsAction::Dismiss => "dismiss"
  }
}
