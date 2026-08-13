///|
fn semantics_delta_between(
  previous : SemanticsSnapshot,
  current : SemanticsSnapshot,
) -> SemanticsDelta {
  let previous_nodes : Map[SemanticsNodeId, SemanticsNode] = Map([])
  let current_ids : Map[SemanticsNodeId, Bool] = Map([])
  for node in previous.nodes {
    previous_nodes[node.node_id] = node
  }
  let upserted : Array[SemanticsNode] = []
  for node in current.nodes {
    current_ids[node.node_id] = true
    if previous_nodes.get(node.node_id) != Some(node) {
      upserted.push(node)
    }
  }
  let removed : Array[SemanticsNodeId] = []
  for node in previous.nodes {
    if !current_ids.contains(node.node_id) {
      removed.push(node.node_id)
    }
  }
  let announcements : Array[AccessibilityAnnouncement] = []
  for node in current.nodes {
    if node.live != SemanticsLive::Off {
      let text = join_semantics_text(
        join_semantics_text(node.label, node.value),
        node.description,
      )
      let changed = match previous_nodes.get(node.node_id) {
        Some(before) =>
          text !=
          join_semantics_text(
            join_semantics_text(before.label, before.value),
            before.description,
          )
        None => true
      }
      if text != "" && changed {
        announcements.push({
          node_id: node.node_id,
          generation: current.generation,
          live: node.live,
          is_atomic: node.live_atomic,
          text,
        })
      }
    }
  }
  {
    from: previous.generation,
    to: current.generation,
    root: current.root,
    focused: current.focused,
    semantic_focused: current.semantic_focused,
    upserted,
    removed,
    issues: current.issues.map(clone_semantics_issue),
    announcements,
  }
}
