///|
fn embedded_semantics_node(node : @core.SemanticsNode) -> EmbeddedSemanticsNode {
  {
    node_id: node.node_id,
    semantic_id: node.semantic_id,
    role: node.role,
    level: node.level,
    url: node.url,
    label: node.label,
    value: node.value,
    description: node.description,
    state: node.state,
    numeric: node.numeric,
    text: node.text,
    collection: node.collection,
    relations: node.relations,
    live: node.live,
    live_atomic: node.live_atomic,
    actions: node.actions.copy(),
    focus_order: node.focus_order,
    frame: node.frame,
    children: node.children.copy(),
  }
}

///|
fn embedded_semantics_update(
  read : @runtime.SemanticsRead,
) -> EmbeddedSemanticsUpdate? {
  match read {
    @runtime.SemanticsRead::Full(snapshot) =>
      Some({
        kind: "full",
        generation: snapshot.generation(),
        root: snapshot.root(),
        focused: snapshot.focused(),
        semantic_focused: snapshot.semantic_focused(),
        nodes: snapshot.nodes().map(embedded_semantics_node),
        removed: [],
        issues: snapshot.issues(),
        announcements: [],
      })
    @runtime.SemanticsRead::Delta(delta) =>
      Some({
        kind: "delta",
        generation: delta.to(),
        root: delta.root(),
        focused: delta.focused(),
        semantic_focused: delta.semantic_focused(),
        nodes: delta.upserted().map(embedded_semantics_node),
        removed: delta.removed(),
        issues: delta.issues(),
        announcements: delta.announcements(),
      })
    @runtime.SemanticsRead::Unchanged(_) => None
  }
}

///|
fn EmbeddedRuntimeHostBridge::sync_semantics(
  self : EmbeddedRuntimeHostBridge,
  runtime : @runtime.AppRuntime,
) -> Unit {
  let read = match self.semantics_cursor {
    Some(cursor) => runtime.read_semantics(since=cursor)
    None => runtime.read_semantics()
  }
  match read {
    Ok(read) =>
      match embedded_semantics_update(read) {
        Some(update) => {
          self.semantics_cursor = Some(update.generation)
          self.updates.push(EmbeddedHostUpdate::Semantics(update))
        }
        None => ()
      }
    Err(_) => ()
  }
}
