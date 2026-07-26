///|
priv struct MountResult {
  node : ElementNode
  next_id : Int
}

///|
priv struct ReconcileResult {
  node : ElementNode
  next_id : Int
  dirty_kind : ReconcileDirtyKind
}

///|
priv struct ChildrenReconcileResult {
  children : Array[ElementNode]
  next_id : Int
  dirty_kind : ReconcileDirtyKind
}

///|
priv enum ReconcileDirtyKind {
  ReconcileClean
  ReconcilePaint
  ReconcileLayout
}

///|
test {
  ignore(ReconcileDirtyKind::ReconcilePaint)
}

///|
fn ReconcileDirtyKind::rank(self : ReconcileDirtyKind) -> Int {
  match self {
    ReconcileClean => 0
    ReconcilePaint => 1
    ReconcileLayout => 2
  }
}

///|
fn ReconcileDirtyKind::combine(
  self : ReconcileDirtyKind,
  other : ReconcileDirtyKind,
) -> ReconcileDirtyKind {
  if self.rank() >= other.rank() {
    self
  } else {
    other
  }
}

///|
priv struct KeyedChildComposite {
  key : String
  kind : String
} derive(Eq, Hash)

///|
fn mount_runtime_view_node(spec : &RuntimeViewNode) -> ElementNode {
  mount_runtime_view_node_with_next(spec, 1).node
}

///|
fn mount_runtime_view_node_with_next(
  spec : &RuntimeViewNode,
  next_id : Int,
) -> MountResult {
  mount_runtime_view_node_for_runtime(spec, None, next_id)
}

///|
fn mount_runtime_view_node_for_runtime(
  spec : &RuntimeViewNode,
  runtime : RuntimeState?,
  next_id : Int,
) -> MountResult {
  let id = ElementId::new(next_id)
  let mut next = next_id + 1
  let children : Array[ElementNode] = []
  let mut component_subscriptions : Array[StateSubscription] = []
  let mut component_effects : Array[ComponentEffect] = []
  match (spec.has_build_child(), runtime) {
    (true, Some(runtime)) => {
      let built = build_component_child(spec, runtime, id, [], [])
      component_subscriptions = built.subscriptions
      component_effects = built.effects
      let mounted = mount_runtime_view_node_for_runtime(
        built.child_view_node,
        Some(runtime),
        next,
      )
      children.push(mounted.node)
      next = mounted.next_id
    }
    _ => ()
  }
  for child_view_node in spec.children() {
    let mounted = mount_runtime_view_node_for_runtime(
      child_view_node, runtime, next,
    )
    children.push(mounted.node)
    next = mounted.next_id
  }
  {
    node: {
      id,
      key: runtime_view_node_identity_key(spec),
      view_node: spec,
      children,
      dirty: DirtyFlags::all(),
      control: ElementControlState::new(),
      component: ElementComponentState::new(
        subscriptions=component_subscriptions,
        effects=component_effects,
      ),
      layout_cache: ElementLayoutCache::empty(),
      render_cache: ElementRenderCache::empty(),
    },
    next_id: next,
  }
}

///|
fn reconcile_element_for_runtime(
  old : ElementNode,
  next_view_node : &RuntimeViewNode,
  runtime : RuntimeState?,
  next_id : Int,
) -> ReconcileResult {
  if !runtime_view_nodes_have_same_identity(old.view_node, next_view_node) {
    old.cancel_component_tree_subscriptions()
    let mounted = mount_runtime_view_node_for_runtime(
      next_view_node, runtime, next_id,
    )
    {
      node: mounted.node,
      next_id: mounted.next_id,
      dirty_kind: ReconcileLayout,
    }
  } else {
    let own_dirty = runtime_view_node_reconcile_dirty_kind(
      old.view_node,
      next_view_node,
    )
    old.view_node = next_view_node
    old.key = runtime_view_node_identity_key(old.view_node)
    let children_result = if old.view_node.has_build_child() {
      {
        children: old.children,
        next_id,
        dirty_kind: ReconcileDirtyKind::ReconcileClean,
      }
    } else {
      reconcile_children_for_runtime(
        old.children,
        old.view_node,
        runtime,
        next_id,
      )
    }
    old.children = children_result.children
    let dirty_kind = own_dirty.combine(children_result.dirty_kind)
    old.apply_reconcile_dirty(dirty_kind)
    { node: old, next_id: children_result.next_id, dirty_kind }
  }
}

///|
fn reconcile_children_for_runtime(
  old_children : Array[ElementNode],
  next_view_node : &RuntimeViewNode,
  runtime : RuntimeState?,
  next_id : Int,
) -> ChildrenReconcileResult {
  let next_view_nodes = next_view_node.children()
  let children : Array[ElementNode] = []
  let used : Array[Bool] = []
  for _ in old_children {
    used.push(false)
  }
  // Build a key->[old_indices] index for keyed children lookup when the old
  // children list is large enough that linear scanning would be quadratic.
  // Below the threshold the index construction cost outweighs the savings.
  let key_index = if old_children.length() >= keyed_index_threshold() {
    Some(build_keyed_child_index(old_children))
  } else {
    None
  }
  let mut next = next_id
  let mut dirty = ReconcileDirtyKind::ReconcileClean
  for index, child_view_node in next_view_nodes {
    let old_index = find_reusable_child(
      old_children, used, key_index, child_view_node, index,
    )
    match old_index {
      Some(old_index) => {
        used[old_index] = true
        let result = reconcile_element_for_runtime(
          old_children[old_index],
          child_view_node,
          runtime,
          next,
        )
        children.push(result.node)
        next = result.next_id
        dirty = dirty.combine(result.dirty_kind)
      }
      None => {
        let mounted = mount_runtime_view_node_for_runtime(
          child_view_node, runtime, next,
        )
        children.push(mounted.node)
        next = mounted.next_id
        dirty = dirty.combine(ReconcileDirtyKind::ReconcileLayout)
      }
    }
  }
  for index, old_child in old_children {
    if !used[index] {
      old_child.cancel_component_tree_subscriptions()
      dirty = dirty.combine(ReconcileDirtyKind::ReconcileLayout)
    }
  }
  { children, next_id: next, dirty_kind: dirty }
}

///|
fn ElementNode::apply_reconcile_dirty(
  self : ElementNode,
  dirty : ReconcileDirtyKind,
) -> Unit {
  match dirty {
    ReconcileClean => ()
    ReconcilePaint => {
      self.dirty.mark_paint()
      self.render_cache.clear()
    }
    ReconcileLayout => {
      self.dirty.mark_layout()
      self.clear_cached_layout_and_paint()
    }
  }
}

///|
/// Threshold for switching from linear scan to indexed lookup.
/// Below this, the overhead of building the index outweighs the savings.
fn keyed_index_threshold() -> Int {
  32
}

///|
/// Build a composite-key -> [old_indices] index for keyed children.
/// Composite key is "{key.value}|{kind}" so same-key-different-kind nodes
/// (a developer error) do not cross-match. The array preserves encounter
/// order so the first !used match semantics of the original linear scan
/// is preserved. Duplicate keys are rare, so arrays are usually length 1.
fn build_keyed_child_index(
  old_children : Array[ElementNode],
) -> Map[KeyedChildComposite, Array[Int]] {
  let index : Map[KeyedChildComposite, Array[Int]] = Map([])
  for old_index, old_child in old_children {
    match old_child.key {
      Some(key) => {
        let composite = {
          key: key.value(),
          kind: runtime_view_node_kind(old_child.view_node),
        }
        match index.get(composite) {
          Some(arr) => arr.push(old_index)
          None => index[composite] = [old_index]
        }
      }
      None => ()
    }
  }
  index
}

///|
fn find_reusable_child(
  old_children : Array[ElementNode],
  used : Array[Bool],
  key_index : Map[KeyedChildComposite, Array[Int]]?,
  child_view_node : &RuntimeViewNode,
  index : Int,
) -> Int? {
  match runtime_view_node_identity_key(child_view_node) {
    Some(key) =>
      match key_index {
        Some(idx) => {
          let composite = {
            key: key.value(),
            kind: runtime_view_node_kind(child_view_node),
          }
          match idx.get(composite) {
            Some(candidates) => {
              // candidates is usually length 1 (unique keys); rare
              // duplicates keep a short array. Find first !used.
              for old_index in candidates {
                if !used[old_index] {
                  return Some(old_index)
                }
              }
              None
            }
            None => None
          }
        }
        None => {
          // Below threshold: original linear scan.
          for old_index, old_child in old_children {
            if !used[old_index] &&
              old_child.key == Some(key) &&
              runtime_view_node_kind(old_child.view_node) ==
              runtime_view_node_kind(child_view_node) {
              return Some(old_index)
            }
          }
          None
        }
      }
    None =>
      if index < old_children.length() &&
        !used[index] &&
        old_children[index].key is None &&
        runtime_view_node_kind(old_children[index].view_node) ==
        runtime_view_node_kind(child_view_node) {
        Some(index)
      } else {
        None
      }
  }
}
