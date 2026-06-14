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
fn mount_view_spec(spec : ViewSpec) -> ElementNode {
  mount_view_spec_with_next(spec, 1).node
}

///|
fn mount_view_spec_with_next(spec : ViewSpec, next_id : Int) -> MountResult {
  mount_view_spec_for_runtime(spec, None, next_id)
}

///|
fn mount_view_spec_for_runtime(
  spec : ViewSpec,
  runtime : RuntimeState?,
  next_id : Int,
) -> MountResult {
  let id = ElementId::new(next_id)
  let mut next = next_id + 1
  let children : Array[ElementNode] = []
  let mut component_subscriptions : Array[StateSubscription] = []
  let mut component_effects : Array[ComponentEffect] = []
  match spec {
    ComponentSpec(data) =>
      match runtime {
        Some(runtime) => {
          let built = build_component_spec(data.component, runtime, id, [], [])
          component_subscriptions = built.subscriptions
          component_effects = built.effects
          let mounted = mount_view_spec_for_runtime(
            built.child_spec,
            Some(runtime),
            next,
          )
          children.push(mounted.node)
          next = mounted.next_id
        }
        None => ()
      }
    FlexSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_for_runtime(child_spec, runtime, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    PaddingSpec(data) => {
      let mounted = mount_view_spec_for_runtime(data.child, runtime, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    FrameSpec(data) => {
      let mounted = mount_view_spec_for_runtime(data.child, runtime, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    StackSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_for_runtime(child_spec, runtime, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    ScrollSpec(data) => {
      let mounted = mount_view_spec_for_runtime(data.child, runtime, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    GridSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_for_runtime(child_spec, runtime, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    ListSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_for_runtime(child_spec, runtime, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    CustomLayoutSpec(data) =>
      for child_spec in data.children {
        let mounted = mount_view_spec_for_runtime(child_spec, runtime, next)
        children.push(mounted.node)
        next = mounted.next_id
      }
    SheetSpec(data) => {
      let mounted = mount_view_spec_for_runtime(data.content, runtime, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    ContainerSpec(data) =>
      match data.child {
        Some(child) => {
          let mounted = mount_view_spec_for_runtime(child, runtime, next)
          children.push(mounted.node)
          next = mounted.next_id
        }
        None => ()
      }
    ModifiedSpec(data) => {
      let mounted = mount_view_spec_for_runtime(data.child, runtime, next)
      children.push(mounted.node)
      next = mounted.next_id
    }
    _ => ()
  }
  {
    node: {
      id,
      key: spec.identity_key(),
      spec,
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
  next_spec : ViewSpec,
  runtime : RuntimeState?,
  next_id : Int,
) -> ReconcileResult {
  if !old.spec.same_identity(next_spec) {
    old.cancel_component_tree_subscriptions()
    let mounted = mount_view_spec_for_runtime(next_spec, runtime, next_id)
    {
      node: mounted.node,
      next_id: mounted.next_id,
      dirty_kind: ReconcileLayout,
    }
  } else {
    let own_dirty = old.spec.reconcile_dirty_kind(next_spec)
    old.spec = next_spec
    old.key = old.spec.identity_key()
    let children_result = if old.spec is ComponentSpec(_) {
      {
        children: old.children,
        next_id,
        dirty_kind: ReconcileDirtyKind::ReconcileClean,
      }
    } else {
      reconcile_children_for_runtime(old.children, old.spec, runtime, next_id)
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
  next_spec : ViewSpec,
  runtime : RuntimeState?,
  next_id : Int,
) -> ChildrenReconcileResult {
  let next_specs = child_specs(next_spec)
  let children : Array[ElementNode] = []
  let used : Array[Bool] = []
  for _ in old_children {
    used.push(false)
  }
  let mut next = next_id
  let mut dirty = ReconcileDirtyKind::ReconcileClean
  for index, child_spec in next_specs {
    let old_index = find_reusable_child(old_children, used, child_spec, index)
    match old_index {
      Some(old_index) => {
        used[old_index] = true
        let result = reconcile_element_for_runtime(
          old_children[old_index],
          child_spec,
          runtime,
          next,
        )
        children.push(result.node)
        next = result.next_id
        dirty = dirty.combine(result.dirty_kind)
      }
      None => {
        let mounted = mount_view_spec_for_runtime(child_spec, runtime, next)
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
fn find_reusable_child(
  old_children : Array[ElementNode],
  used : Array[Bool],
  child_spec : ViewSpec,
  index : Int,
) -> Int? {
  match child_spec.identity_key() {
    Some(key) => {
      for old_index, old_child in old_children {
        if !used[old_index] &&
          old_child.key == Some(key) &&
          old_child.spec.kind() == child_spec.kind() {
          return Some(old_index)
        }
      }
      None
    }
    None =>
      if index < old_children.length() &&
        !used[index] &&
        old_children[index].key is None &&
        old_children[index].spec.kind() == child_spec.kind() {
        Some(index)
      } else {
        None
      }
  }
}

///|
fn child_specs(spec : ViewSpec) -> Array[ViewSpec] {
  match spec {
    FlexSpec(data) => data.children
    PaddingSpec(data) => [data.child]
    FrameSpec(data) => [data.child]
    StackSpec(data) => data.children
    ScrollSpec(data) => [data.child]
    GridSpec(data) => data.children
    ListSpec(data) => data.children
    CustomLayoutSpec(data) => data.children
    SheetSpec(data) => [data.content]
    ContainerSpec(data) =>
      match data.child {
        Some(child) => [child]
        None => []
      }
    ModifiedSpec(data) => [data.child]
    ComponentSpec(_) => []
    _ => []
  }
}
