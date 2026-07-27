///|
/// Runtime-owned committed semantics graph. The maps are private and replaced
/// atomically with the public flat snapshot after each semantics commit.
priv struct SemanticsTree {
  root : SemanticsNodeId?
  nodes : Map[SemanticsNodeId, SemanticsNode]
  routes : Map[SemanticsNodeId, SemanticsNodeRoute]
}

///|
fn SemanticsTree::empty() -> SemanticsTree {
  { root: None, nodes: Map([]), routes: Map([]) }
}

///|
fn SemanticsTree::from_reachable(
  root : SemanticsNodeId?,
  nodes : Array[SemanticsNode],
  routes : Map[SemanticsNodeId, SemanticsNodeRoute],
) -> SemanticsTree {
  let reachable_nodes : Map[SemanticsNodeId, SemanticsNode] = Map([])
  let reachable_routes : Map[SemanticsNodeId, SemanticsNodeRoute] = Map([])
  for node in nodes {
    reachable_nodes[node.node_id] = node
    match routes.get(node.node_id) {
      Some(route) => reachable_routes[node.node_id] = route
      None => ()
    }
  }
  { root, nodes: reachable_nodes, routes: reachable_routes }
}
