///|
/// Backend-owned semantics update translated for AccessKit transport.
pub struct AccessKitUpdate {
  generation : @core.SemanticsGeneration
  tree_update : @moon_accesskit.TreeUpdate
  removed : Array[@core.SemanticsNodeId]
}

///|
pub(all) enum AccessKitActionResult {
  Handled(@runtime.SemanticsActionReceipt)
  Rejected(@runtime.SemanticsActionDispatchError)
  BridgeUnavailable(String)
} derive(Eq, Debug)

///|
/// AccessKit translation and dispatch boundary. Platform identity and native
/// binding availability remain owned by each concrete backend.
pub(all) struct AccessKitBridge {
  diagnostic_name : String
  available : Bool
  publish : (@runtime.SemanticsRead) -> AccessKitUpdate?
  perform : (@runtime.PerformSemanticsActionRequest) -> AccessKitActionResult
}

///|
pub fn AccessKitUpdate::generation(
  self : AccessKitUpdate,
) -> @core.SemanticsGeneration {
  self.generation
}

///|
pub fn AccessKitUpdate::tree_update(
  self : AccessKitUpdate,
) -> @moon_accesskit.TreeUpdate {
  self.tree_update
}

///|
pub fn AccessKitUpdate::removed(
  self : AccessKitUpdate,
) -> Array[@core.SemanticsNodeId] {
  self.removed.copy()
}

///|
pub fn accesskit_node_id_for_semantics(
  node_id : @core.SemanticsNodeId,
) -> @moon_accesskit.NodeId {
  @moon_accesskit.NodeId::from_u64(node_id.value())
}

///|
pub fn accesskit_rect_from_core(rect : @core.Rect) -> @moon_accesskit.Rect {
  @moon_accesskit.Rect(
    rect.origin.x,
    rect.origin.y,
    rect.origin.x + rect.size.width,
    rect.origin.y + rect.size.height,
  )
}

///|
pub fn accesskit_role_from_semantics(
  role : @core.SemanticsRole,
) -> @moon_accesskit.Role {
  match role {
    @core.SemanticsRole::None => @moon_accesskit.Role::GenericContainer
    @core.SemanticsRole::Text => @moon_accesskit.Role::TextRun
    @core.SemanticsRole::Link => @moon_accesskit.Role::Link
    @core.SemanticsRole::Heading => @moon_accesskit.Role::Heading
    @core.SemanticsRole::Navigation => @moon_accesskit.Role::Navigation
    @core.SemanticsRole::Main => @moon_accesskit.Role::Main
    @core.SemanticsRole::Button => @moon_accesskit.Role::Button
    @core.SemanticsRole::Checkbox => @moon_accesskit.Role::CheckBox
    @core.SemanticsRole::TextField => @moon_accesskit.Role::TextInput
    @core.SemanticsRole::List => @moon_accesskit.Role::List
    @core.SemanticsRole::ListItem => @moon_accesskit.Role::ListItem
    @core.SemanticsRole::Grid => @moon_accesskit.Role::Grid
    @core.SemanticsRole::ScrollView => @moon_accesskit.Role::ScrollView
    @core.SemanticsRole::Switch => @moon_accesskit.Role::Switch
    @core.SemanticsRole::Radio => @moon_accesskit.Role::RadioButton
    @core.SemanticsRole::Slider => @moon_accesskit.Role::Slider
    @core.SemanticsRole::Progress => @moon_accesskit.Role::ProgressIndicator
    @core.SemanticsRole::Tab => @moon_accesskit.Role::Tab
    @core.SemanticsRole::Dialog => @moon_accesskit.Role::Dialog
    @core.SemanticsRole::Tooltip => @moon_accesskit.Role::Tooltip
    @core.SemanticsRole::Menu => @moon_accesskit.Role::Menu
    @core.SemanticsRole::WebView => @moon_accesskit.Role::GenericContainer
    @core.SemanticsRole::ButtonGroup => @moon_accesskit.Role::Group
    @core.SemanticsRole::Form => @moon_accesskit.Role::Form
    @core.SemanticsRole::FormField => @moon_accesskit.Role::GenericContainer
    @core.SemanticsRole::Tree => @moon_accesskit.Role::Tree
    @core.SemanticsRole::TreeItem => @moon_accesskit.Role::TreeItem
    @core.SemanticsRole::Group => @moon_accesskit.Role::Group
  }
}

///|
pub fn accesskit_action_from_semantics(
  action : @core.SemanticsActionKind,
) -> @moon_accesskit.Action {
  match action {
    @core.SemanticsActionKind::Activate => @moon_accesskit.Action::Click
    @core.SemanticsActionKind::Focus => @moon_accesskit.Action::Focus
    @core.SemanticsActionKind::SetText => @moon_accesskit.Action::SetValue
    @core.SemanticsActionKind::Submit => @moon_accesskit.Action::Click
    @core.SemanticsActionKind::Scroll => @moon_accesskit.Action::ScrollIntoView
    @core.SemanticsActionKind::Select => @moon_accesskit.Action::Click
    @core.SemanticsActionKind::Expand => @moon_accesskit.Action::Expand
    @core.SemanticsActionKind::Collapse => @moon_accesskit.Action::Collapse
    @core.SemanticsActionKind::Dismiss => @moon_accesskit.Action::HideTooltip
  }
}

///|
pub fn accesskit_node_from_semantics(
  node : @core.SemanticsNode,
) -> @moon_accesskit.Node {
  let access_node = @moon_accesskit.Node(
    accesskit_role_from_semantics(node.role),
  )
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
    access_node.set_toggled(@moon_accesskit.Toggled::True)
  }
  if node.state.expanded {
    access_node.set_expanded(true)
  }
  if node.state.invalid {
    access_node.set_invalid(@moon_accesskit.Invalid::True)
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
fn empty_accesskit_root() -> (@moon_accesskit.NodeId, @moon_accesskit.Node) {
  let id = @moon_accesskit.NodeId::from_u64(0UL)
  (id, @moon_accesskit.Node(@moon_accesskit.Role::GenericContainer))
}

///|
fn build_accesskit_update(
  generation : @core.SemanticsGeneration,
  root : @core.SemanticsNodeId?,
  focused : @core.SemanticsNodeId?,
  nodes : Array[@core.SemanticsNode],
  removed : Array[@core.SemanticsNodeId],
) -> AccessKitUpdate {
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
  let update = @moon_accesskit.TreeUpdate(
    @moon_accesskit.TreeId::root(),
    focus_id,
  )
  update.set_tree(@moon_accesskit.Tree(root_id))
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
) -> AccessKitUpdate? {
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
pub fn accesskit_semantics_action_request(
  node_id~ : @core.SemanticsNodeId,
  generation~ : @core.SemanticsGeneration,
  action~ : @core.SemanticsAction,
) -> @runtime.PerformSemanticsActionRequest {
  {
    target: @core.SemanticsTarget::ByNodeId(node_id),
    action,
    precondition: @runtime.SemanticsGenerationPrecondition::Exact(generation),
  }
}

///|
pub fn AccessKitBridge::new(
  diagnostic_name? : String = "accesskit",
  available? : Bool = true,
  publish? : (@runtime.SemanticsRead) -> AccessKitUpdate? = read => {
    accesskit_update_from_semantics_read(read)
  },
  perform? : (@runtime.PerformSemanticsActionRequest) -> AccessKitActionResult = _request => {
    AccessKitActionResult::BridgeUnavailable(
      "accessibility action transport is not configured",
    )
  },
) -> AccessKitBridge {
  { diagnostic_name, available, publish, perform }
}

///|
pub fn AccessKitBridge::unavailable(
  diagnostic_name? : String = "accesskit",
  reason? : String = "accessibility bridge is unavailable",
) -> AccessKitBridge {
  AccessKitBridge::new(
    diagnostic_name~,
    available=false,
    perform=_request => AccessKitActionResult::BridgeUnavailable(reason),
  )
}

///|
pub fn AccessKitBridge::publish_semantics(
  self : AccessKitBridge,
  read : @runtime.SemanticsRead,
) -> AccessKitUpdate? {
  if self.available {
    (self.publish)(read)
  } else {
    None
  }
}

///|
pub fn AccessKitBridge::perform_action(
  self : AccessKitBridge,
  request : @runtime.PerformSemanticsActionRequest,
) -> AccessKitActionResult {
  if self.available {
    (self.perform)(request)
  } else {
    AccessKitActionResult::BridgeUnavailable(
      "accessibility bridge is unavailable: " + self.diagnostic_name,
    )
  }
}

///|
pub fn AccessKitBridge::driver(
  diagnostic_name? : String = "accesskit",
  driver~ : @runtime.HostRuntimeDriver,
) -> AccessKitBridge {
  AccessKitBridge::new(diagnostic_name~, perform=request => {
    match driver.perform_semantics_action(request) {
      Ok(receipt) => AccessKitActionResult::Handled(receipt)
      Err(error) => AccessKitActionResult::Rejected(error)
    }
  })
}
