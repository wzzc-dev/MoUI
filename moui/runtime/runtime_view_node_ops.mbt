///|
fn runtime_view_node_identity_key(node : &RuntimeViewNode) -> Key? {
  node.identity().key
}

///|
fn runtime_view_node_kind(node : &RuntimeViewNode) -> String {
  node.identity().kind
}

///|
fn runtime_view_node_inspector_kind_label(node : &RuntimeViewNode) -> String {
  node.identity().kind
}

///|
fn runtime_view_node_inspector_is_control(node : &RuntimeViewNode) -> Bool {
  node.focusable()
}

///|
fn runtime_view_nodes_have_same_identity(
  current : &RuntimeViewNode,
  next : &RuntimeViewNode,
) -> Bool {
  current.identity() == next.identity()
}

///|
fn runtime_view_node_reconcile_dirty_kind(
  current : &RuntimeViewNode,
  next : &RuntimeViewNode,
) -> ReconcileDirtyKind {
  let changes = next.declaration().changes_from(current.declaration())
  {
    layout: changes.layout(),
    paint: changes.paint(),
    semantics: changes.semantics() ||
    current.semantics() != next.semantics() ||
    current.semantics_action_kinds() != next.semantics_action_kinds(),
    platform: changes.platform(),
  }
}
