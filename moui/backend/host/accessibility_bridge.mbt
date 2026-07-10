///|
pub(all) enum NativeAccessibilityBridgeKind {
  AppKit
  UIAutomation
  ATSPI
  TestBridge
} derive(Eq, Debug, ToJson)

///|
pub(all) struct NativeAccessibilityNode {
  element_id : @core.ElementId
  role : @core.SemanticsRole
  native_role : String
  label : String
  value : String
  frame : @core.Rect
  focused : Bool
  disabled : Bool
  selected : Bool
  checked : Bool
  actions : Array[@core.SemanticsAction]
  children : Array[NativeAccessibilityNode]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct NativeAccessibilityActionRequest {
  element_id : @core.ElementId
  action : @core.SemanticsAction
  value : String?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum NativeAccessibilityActionResult {
  Handled
  Unsupported(String)
  ElementNotFound(@core.ElementId)
  BridgeUnavailable(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct NativeAccessibilityBridge {
  kind : NativeAccessibilityBridgeKind
  available : Bool
  snapshot : (@core.SemanticsNode) -> @accesskit.TreeUpdate
  perform : (NativeAccessibilityActionRequest) -> NativeAccessibilityActionResult
}

///|
pub fn NativeAccessibilityBridgeKind::label(
  self : NativeAccessibilityBridgeKind,
) -> String {
  match self {
    AppKit => "appkit"
    UIAutomation => "uiautomation"
    ATSPI => "at-spi"
    TestBridge => "test"
  }
}

///|
pub fn NativeAccessibilityNode::from_semantics(
  node : @core.SemanticsNode,
  native_role? : String = native_accessibility_role(node.role),
) -> NativeAccessibilityNode {
  {
    element_id: node.element_id,
    role: node.role,
    native_role,
    label: node.label,
    value: node.value,
    frame: node.frame,
    focused: node.state.focused,
    disabled: node.state.disabled,
    selected: node.state.selected,
    checked: node.state.checked,
    actions: node.actions,
    children: node.children.map(child => {
      NativeAccessibilityNode::from_semantics(child)
    }),
  }
}

///|
pub fn accesskit_node_id_for_element(
  element_id : @core.ElementId,
) -> @accesskit.NodeId {
  @accesskit.NodeId::from_u64(element_id.value().to_uint64())
}

///|
pub fn accesskit_rect_from_core(rect : @core.Rect) -> @accesskit.Rect {
  @accesskit.Rect(
    rect.origin.x,
    rect.origin.y,
    rect.origin.x + rect.size.width,
    rect.origin.y + rect.size.height,
  )
}

///|
pub fn accesskit_role_from_semantics(
  role : @core.SemanticsRole,
) -> @accesskit.Role {
  match role {
    @core.SemanticsRole::None => @accesskit.Role::GenericContainer
    @core.SemanticsRole::Text => @accesskit.Role::TextRun
    @core.SemanticsRole::Link => @accesskit.Role::Link
    @core.SemanticsRole::Heading => @accesskit.Role::Heading
    @core.SemanticsRole::Navigation => @accesskit.Role::Navigation
    @core.SemanticsRole::Main => @accesskit.Role::Main
    @core.SemanticsRole::Button => @accesskit.Role::Button
    @core.SemanticsRole::Checkbox => @accesskit.Role::CheckBox
    @core.SemanticsRole::TextField => @accesskit.Role::TextInput
    @core.SemanticsRole::List => @accesskit.Role::List
    @core.SemanticsRole::ListItem => @accesskit.Role::ListItem
    @core.SemanticsRole::Grid => @accesskit.Role::Grid
    @core.SemanticsRole::ScrollView => @accesskit.Role::ScrollView
    @core.SemanticsRole::Switch => @accesskit.Role::Switch
    @core.SemanticsRole::Radio => @accesskit.Role::RadioButton
    @core.SemanticsRole::Slider => @accesskit.Role::Slider
    @core.SemanticsRole::Progress => @accesskit.Role::ProgressIndicator
    @core.SemanticsRole::Tab => @accesskit.Role::Tab
    @core.SemanticsRole::Dialog => @accesskit.Role::Dialog
    @core.SemanticsRole::Tooltip => @accesskit.Role::Tooltip
    @core.SemanticsRole::Menu => @accesskit.Role::Menu
    @core.SemanticsRole::WebView => @accesskit.Role::GenericContainer
    @core.SemanticsRole::ButtonGroup => @accesskit.Role::Group
    @core.SemanticsRole::Form => @accesskit.Role::Form
    @core.SemanticsRole::FormField => @accesskit.Role::GenericContainer
    @core.SemanticsRole::Tree => @accesskit.Role::Tree
    @core.SemanticsRole::TreeItem => @accesskit.Role::TreeItem
    @core.SemanticsRole::Group => @accesskit.Role::Group
  }
}

///|
pub fn accesskit_action_from_semantics(
  action : @core.SemanticsAction,
) -> @accesskit.Action {
  match action {
    @core.SemanticsAction::Activate => @accesskit.Action::Click
    @core.SemanticsAction::Focus => @accesskit.Action::Focus
    @core.SemanticsAction::SetText => @accesskit.Action::SetValue
    @core.SemanticsAction::Submit => @accesskit.Action::Click
    @core.SemanticsAction::Scroll => @accesskit.Action::ScrollIntoView
    @core.SemanticsAction::Select => @accesskit.Action::Click
    @core.SemanticsAction::Expand => @accesskit.Action::Expand
    @core.SemanticsAction::Collapse => @accesskit.Action::Collapse
    @core.SemanticsAction::Dismiss => @accesskit.Action::HideTooltip
  }
}

///|
pub fn accesskit_node_from_semantics(
  node : @core.SemanticsNode,
) -> @accesskit.Node {
  let access_node = @accesskit.Node(accesskit_role_from_semantics(node.role))
  access_node.set_bounds(accesskit_rect_from_core(node.frame))
  if node.label != "" {
    access_node.set_label(node.label)
  }
  if node.value != "" {
    access_node.set_value(node.value)
  }
  if node.description != "" {
    access_node.set_description(node.description)
  }
  match node.level {
    Some(level) => if level > 0 { access_node.set_level(level) }
    None => ()
  }
  if node.url != "" {
    access_node.set_url(node.url)
  }
  if node.state.disabled {
    access_node.set_disabled()
  }
  if node.state.selected {
    access_node.set_selected(true)
  }
  if node.state.checked {
    access_node.set_toggled(@accesskit.Toggled::True)
  }
  if node.state.expanded {
    access_node.set_expanded(true)
  }
  if node.state.invalid {
    access_node.set_invalid(@accesskit.Invalid::True)
  }
  if node.state.required {
    access_node.set_required()
  }
  for action in node.actions {
    access_node.add_action(accesskit_action_from_semantics(action))
  }
  access_node.set_children(
    node.children.map(child => accesskit_node_id_for_element(child.element_id)),
  )
  access_node
}

///|
pub fn accesskit_tree_update_from_semantics(
  node : @core.SemanticsNode,
) -> @accesskit.TreeUpdate {
  let root_id = accesskit_node_id_for_element(node.element_id)
  let update = @accesskit.TreeUpdate(@accesskit.TreeId::root(), root_id)
  update.set_tree(@accesskit.Tree(root_id))
  push_accesskit_semantics_node(update, node)
  update
}

///|
fn push_accesskit_semantics_node(
  update : @accesskit.TreeUpdate,
  node : @core.SemanticsNode,
) -> Unit {
  update.push_node(
    accesskit_node_id_for_element(node.element_id),
    accesskit_node_from_semantics(node),
  )
  for child in node.children {
    push_accesskit_semantics_node(update, child)
  }
}

///|
pub fn NativeAccessibilityNode::from_accesskit(
  update : @accesskit.TreeUpdate,
  element_id : @core.ElementId,
  role : @core.SemanticsRole,
) -> NativeAccessibilityNode {
  let id = accesskit_node_id_for_element(element_id)
  for node_update in update.nodes() {
    if node_update.id() == id {
      let node = node_update.node()
      return {
        element_id,
        role,
        native_role: node.role().to_string(),
        label: node.label().unwrap_or(""),
        value: node.value().unwrap_or(""),
        frame: @core.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
        focused: false,
        disabled: node.is_disabled(),
        selected: node.is_selected().unwrap_or(false),
        checked: node.toggled() == Some(@accesskit.Toggled::True),
        actions: [],
        children: [],
      }
    }
  }
  NativeAccessibilityNode::from_semantics(@core.SemanticsNode::{
    element_id,
    role,
    level: None,
    url: "",
    label: "",
    value: "",
    description: "",
    state: @core.SemanticsState::default(),
    actions: [],
    focus_order: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    children: [],
  })
}

///|
pub fn NativeAccessibilityActionRequest::new(
  element_id~ : @core.ElementId,
  action~ : @core.SemanticsAction,
  value? : String? = None,
) -> NativeAccessibilityActionRequest {
  { element_id, action, value }
}

///|
pub fn NativeAccessibilityBridge::new(
  kind~ : NativeAccessibilityBridgeKind,
  available? : Bool = true,
  snapshot? : (@core.SemanticsNode) -> @accesskit.TreeUpdate = node => {
    accesskit_tree_update_from_semantics(node)
  },
  perform? : (NativeAccessibilityActionRequest) -> NativeAccessibilityActionResult = request => {
    NativeAccessibilityActionResult::Unsupported(
      "native accessibility action is not handled: " +
      semantics_action_label(request.action),
    )
  },
) -> NativeAccessibilityBridge {
  { kind, available, snapshot, perform }
}

///|
pub fn NativeAccessibilityBridge::unavailable(
  kind~ : NativeAccessibilityBridgeKind,
  reason? : String = "native accessibility bridge is unavailable",
) -> NativeAccessibilityBridge {
  NativeAccessibilityBridge::new(kind~, available=false, perform=_request => {
    NativeAccessibilityActionResult::BridgeUnavailable(reason)
  })
}

///|
pub fn NativeAccessibilityBridge::snapshot_semantics(
  self : NativeAccessibilityBridge,
  node : @core.SemanticsNode,
) -> @accesskit.TreeUpdate? {
  if self.available {
    Some((self.snapshot)(node))
  } else {
    None
  }
}

///|
pub fn NativeAccessibilityBridge::snapshot_legacy_node(
  self : NativeAccessibilityBridge,
  node : @core.SemanticsNode,
) -> NativeAccessibilityNode? {
  if self.available {
    Some(NativeAccessibilityNode::from_semantics(node))
  } else {
    None
  }
}

///|
pub fn NativeAccessibilityBridge::perform_action(
  self : NativeAccessibilityBridge,
  request : NativeAccessibilityActionRequest,
) -> NativeAccessibilityActionResult {
  if self.available {
    (self.perform)(request)
  } else {
    NativeAccessibilityActionResult::BridgeUnavailable(
      "native accessibility bridge is unavailable: " + self.kind.label(),
    )
  }
}

///|
pub fn NativeAccessibilityBridge::semantics_action_bridge(
  kind~ : NativeAccessibilityBridgeKind,
  root~ : @core.SemanticsNode,
  dispatch~ : (@core.ElementId, @core.SemanticsAction, String?) -> Bool,
) -> NativeAccessibilityBridge {
  NativeAccessibilityBridge::new(
    kind~,
    snapshot=node => accesskit_tree_update_from_semantics(node),
    perform=request => {
      match find_semantics_node(root, request.element_id) {
        Some(node) =>
          if node.actions.any(action => action == request.action) {
            if dispatch(request.element_id, request.action, request.value) {
              NativeAccessibilityActionResult::Handled
            } else {
              NativeAccessibilityActionResult::Unsupported(
                "native accessibility action dispatch returned false: " +
                semantics_action_label(request.action),
              )
            }
          } else {
            NativeAccessibilityActionResult::Unsupported(
              "semantics node does not expose action: " +
              semantics_action_label(request.action),
            )
          }
        None =>
          NativeAccessibilityActionResult::ElementNotFound(request.element_id)
      }
    },
  )
}

///|
pub fn semantics_action_label(action : @core.SemanticsAction) -> String {
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

///|
pub fn find_semantics_node(
  node : @core.SemanticsNode,
  element_id : @core.ElementId,
) -> @core.SemanticsNode? {
  if node.element_id == element_id {
    Some(node)
  } else {
    for child in node.children {
      match find_semantics_node(child, element_id) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
}

///|
fn native_accessibility_role(role : @core.SemanticsRole) -> String {
  match role {
    @core.SemanticsRole::None => "ignored"
    @core.SemanticsRole::Text => "staticText"
    @core.SemanticsRole::Link => "link"
    @core.SemanticsRole::Heading => "heading"
    @core.SemanticsRole::Navigation => "navigation"
    @core.SemanticsRole::Main => "main"
    @core.SemanticsRole::Button => "button"
    @core.SemanticsRole::Checkbox => "checkbox"
    @core.SemanticsRole::TextField => "textField"
    @core.SemanticsRole::List => "list"
    @core.SemanticsRole::ListItem => "listItem"
    @core.SemanticsRole::Grid => "grid"
    @core.SemanticsRole::ScrollView => "scrollArea"
    @core.SemanticsRole::Switch => "switch"
    @core.SemanticsRole::Radio => "radioButton"
    @core.SemanticsRole::Slider => "slider"
    @core.SemanticsRole::Progress => "progressIndicator"
    @core.SemanticsRole::Tab => "tab"
    @core.SemanticsRole::Dialog => "dialog"
    @core.SemanticsRole::Tooltip => "tooltip"
    @core.SemanticsRole::Menu => "menu"
    @core.SemanticsRole::WebView => "webView"
    @core.SemanticsRole::ButtonGroup => "buttonGroup"
    @core.SemanticsRole::Form => "form"
    @core.SemanticsRole::FormField => "formField"
    @core.SemanticsRole::Tree => "tree"
    @core.SemanticsRole::TreeItem => "treeItem"
    @core.SemanticsRole::Group => "group"
  }
}
