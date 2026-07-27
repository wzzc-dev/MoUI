///|
fn embedding_semantics_node(
  node : @core.SemanticsNode,
) -> EmbeddingSemanticsNode {
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
    actions: node.actions.copy(),
    focus_order: node.focus_order,
    frame: node.frame,
    children: node.children.copy(),
  }
}

///|
fn embedding_semantics_update(
  read : @runtime.SemanticsRead,
) -> EmbeddingSemanticsUpdate? {
  match read {
    @runtime.SemanticsRead::Full(snapshot) =>
      Some({
        kind: "full",
        generation: snapshot.generation(),
        root: snapshot.root(),
        focused: snapshot.focused(),
        nodes: snapshot.nodes().map(embedding_semantics_node),
        removed: [],
        issues: snapshot.issues(),
      })
    @runtime.SemanticsRead::Delta(delta) =>
      Some({
        kind: "delta",
        generation: delta.to(),
        root: delta.root(),
        focused: delta.focused(),
        nodes: delta.upserted().map(embedding_semantics_node),
        removed: delta.removed(),
        issues: delta.issues(),
      })
    @runtime.SemanticsRead::Unchanged(_) => None
  }
}
