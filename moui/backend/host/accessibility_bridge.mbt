///|
pub(all) enum NativeAccessibilityBridgeKind {
  AppKit
  UIAutomation
  ATSPI
  TestBridge
} derive(Eq, Debug, ToJson)

///|
/// Runtime-owned semantics update translated for AccessKit transport.
pub struct NativeAccessibilityUpdate {
  generation : @core.SemanticsGeneration
  tree_update : @accesskit.TreeUpdate
  removed : Array[@core.SemanticsNodeId]
}

///|
pub(all) struct NativeAccessibilityActionRequest {
  node_id : @core.SemanticsNodeId
  generation : @core.SemanticsGeneration
  action : @core.SemanticsAction
} derive(Eq, Debug, ToJson)

///|
pub(all) enum NativeAccessibilityActionResult {
  Handled(@runtime.SemanticsActionReceipt)
  Rejected(@runtime.SemanticsActionDispatchError)
  BridgeUnavailable(String)
} derive(Eq, Debug)

///|
pub(all) struct NativeAccessibilityBridge {
  kind : NativeAccessibilityBridgeKind
  available : Bool
  publish : (@runtime.SemanticsRead) -> NativeAccessibilityUpdate?
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
pub fn NativeAccessibilityUpdate::generation(
  self : NativeAccessibilityUpdate,
) -> @core.SemanticsGeneration {
  self.generation
}

///|
pub fn NativeAccessibilityUpdate::tree_update(
  self : NativeAccessibilityUpdate,
) -> @accesskit.TreeUpdate {
  self.tree_update
}

///|
pub fn NativeAccessibilityUpdate::removed(
  self : NativeAccessibilityUpdate,
) -> Array[@core.SemanticsNodeId] {
  self.removed.copy()
}

///|
pub fn accesskit_node_id_for_semantics(
  node_id : @core.SemanticsNodeId,
) -> @accesskit.NodeId {
  @accesskit.NodeId::from_u64(node_id.value())
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
  action : @core.SemanticsActionKind,
) -> @accesskit.Action {
  match action {
    @core.SemanticsActionKind::Activate => @accesskit.Action::Click
    @core.SemanticsActionKind::Focus => @accesskit.Action::Focus
    @core.SemanticsActionKind::SetText => @accesskit.Action::SetValue
    @core.SemanticsActionKind::Submit => @accesskit.Action::Click
    @core.SemanticsActionKind::Scroll => @accesskit.Action::ScrollIntoView
    @core.SemanticsActionKind::Select => @accesskit.Action::Click
    @core.SemanticsActionKind::Expand => @accesskit.Action::Expand
    @core.SemanticsActionKind::Collapse => @accesskit.Action::Collapse
    @core.SemanticsActionKind::Dismiss => @accesskit.Action::HideTooltip
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
  access_node.set_children(node.children.map(accesskit_node_id_for_semantics))
  access_node
}

///|
fn empty_accesskit_root() -> (@accesskit.NodeId, @accesskit.Node) {
  let id = @accesskit.NodeId::from_u64(0UL)
  (id, @accesskit.Node(@accesskit.Role::GenericContainer))
}

///|
fn build_accesskit_update(
  generation : @core.SemanticsGeneration,
  root : @core.SemanticsNodeId?,
  focused : @core.SemanticsNodeId?,
  nodes : Array[@core.SemanticsNode],
  removed : Array[@core.SemanticsNodeId],
) -> NativeAccessibilityUpdate {
  let (root_id, empty_node) = match root {
    Some(node_id) => (accesskit_node_id_for_semantics(node_id), None)
    None => {
      let (node_id, node) = empty_accesskit_root()
      (node_id, Some(node))
    }
  }
  let focus_id = match focused {
    Some(node_id) => accesskit_node_id_for_semantics(node_id)
    None => root_id
  }
  let update = @accesskit.TreeUpdate(@accesskit.TreeId::root(), focus_id)
  update.set_tree(@accesskit.Tree(root_id))
  match empty_node {
    Some(node) => update.push_node(root_id, node)
    None => ()
  }
  for node in nodes {
    update.push_node(
      accesskit_node_id_for_semantics(node.node_id),
      accesskit_node_from_semantics(node),
    )
  }
  { generation, tree_update: update, removed }
}

///|
pub fn accesskit_update_from_semantics_read(
  read : @runtime.SemanticsRead,
) -> NativeAccessibilityUpdate? {
  match read {
    @runtime.SemanticsRead::Full(snapshot) =>
      Some(
        build_accesskit_update(
          snapshot.generation(),
          snapshot.root(),
          snapshot.focused(),
          snapshot.nodes(),
          [],
        ),
      )
    @runtime.SemanticsRead::Delta(delta) =>
      Some(
        build_accesskit_update(
          delta.to(),
          delta.root(),
          delta.focused(),
          delta.upserted(),
          delta.removed(),
        ),
      )
    @runtime.SemanticsRead::Unchanged(_) => None
  }
}

///|
pub fn NativeAccessibilityActionRequest::new(
  node_id~ : @core.SemanticsNodeId,
  generation~ : @core.SemanticsGeneration,
  action~ : @core.SemanticsAction,
) -> NativeAccessibilityActionRequest {
  { node_id, generation, action }
}

///|
pub fn NativeAccessibilityBridge::new(
  kind~ : NativeAccessibilityBridgeKind,
  available? : Bool = true,
  publish? : (@runtime.SemanticsRead) -> NativeAccessibilityUpdate? = read => {
    accesskit_update_from_semantics_read(read)
  },
  perform? : (NativeAccessibilityActionRequest) -> NativeAccessibilityActionResult = _request => {
    NativeAccessibilityActionResult::BridgeUnavailable(
      "native accessibility action transport is not configured",
    )
  },
) -> NativeAccessibilityBridge {
  { kind, available, publish, perform }
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
pub fn NativeAccessibilityBridge::publish_semantics(
  self : NativeAccessibilityBridge,
  read : @runtime.SemanticsRead,
) -> NativeAccessibilityUpdate? {
  if self.available {
    (self.publish)(read)
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
pub fn NativeAccessibilityBridge::runtime(
  kind~ : NativeAccessibilityBridgeKind,
  runtime~ : @runtime.AppRuntime,
) -> NativeAccessibilityBridge {
  NativeAccessibilityBridge::new(kind~, perform=request => {
    match
      runtime.perform_semantics_action({
        target: @core.SemanticsTarget::ByNodeId(request.node_id),
        action: request.action,
        precondition: @runtime.SemanticsGenerationPrecondition::Exact(
          request.generation,
        ),
      }) {
      Ok(receipt) => NativeAccessibilityActionResult::Handled(receipt)
      Err(error) => NativeAccessibilityActionResult::Rejected(error)
    }
  })
}

///|
pub fn semantics_action_label(action : @core.SemanticsAction) -> String {
  match action {
    @core.SemanticsAction::Activate => "activate"
    @core.SemanticsAction::Focus => "focus"
    @core.SemanticsAction::SetText(_) => "set-text"
    @core.SemanticsAction::Submit => "submit"
    @core.SemanticsAction::Scroll(_) => "scroll"
    @core.SemanticsAction::Select => "select"
    @core.SemanticsAction::Expand => "expand"
    @core.SemanticsAction::Collapse => "collapse"
    @core.SemanticsAction::Dismiss => "dismiss"
  }
}
