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
  let current_revision = current.revision()
  let next_revision = next.revision()
  let layout_clean = current_revision != "" && current_revision == next_revision
  if !layout_clean {
    return ReconcileLayout
  }
  let current_paint_revision = current.paint_revision()
  if current_paint_revision != "" &&
    current_paint_revision != next.paint_revision() {
    return ReconcilePaint
  }
  ReconcileClean
}
