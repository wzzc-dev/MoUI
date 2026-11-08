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
  previous_declaration : @core.ViewDeclaration?,
) -> (ReconcileDirtyKind, @core.ViewDeclaration) {
  let next_declaration = next.declaration()
  // `declaration()` is pure over the node's stored fields, so the retained
  // element's cached copy is interchangeable with recomputing it. Canonical
  // keys are byte-encoded on every call, and the previous side never changes
  // between reconciles.
  let current_declaration = match previous_declaration {
    Some(cached) => cached
    None => current.declaration()
  }
  let changes = next_declaration.changes_from(current_declaration)
  // F1: the semantics channel's contract is "output changes exactly when its
  // canonical key changes". When the next declaration's semantics channel is
  // `Exact` and no effective change was detected (which for an `Exact` next
  // channel means both sides carry the same key), the structural
  // `ViewSemanticsInfo` comparison and the `semantics_action_kinds` rebuild
  // (which allocates an array per call) are redundant re-derivations of the
  // declared contract. Every other channel pair keeps the defensive
  // comparison. A layout change already implies semantics, so only the
  // no-change path reaches the comparison at all.
  let semantics = if changes.semantics() {
    true
  } else if next_declaration.semantics() is Exact(_) {
    false
  } else {
    current.semantics() != next.semantics() ||
    current.semantics_action_kinds() != next.semantics_action_kinds()
  }
  (
    {
      layout: changes.layout(),
      paint: changes.paint(),
      semantics,
      platform: changes.platform(),
    },
    next_declaration,
  )
}
