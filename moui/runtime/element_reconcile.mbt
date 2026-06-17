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
fn mount_runtime_widget(spec : RuntimeWidget) -> ElementNode {
  mount_runtime_widget_with_next(spec, 1).node
}

///|
fn mount_runtime_widget_with_next(
  spec : RuntimeWidget,
  next_id : Int,
) -> MountResult {
  mount_runtime_widget_for_runtime(spec, None, next_id)
}

///|
fn mount_runtime_widget_for_runtime(
  spec : RuntimeWidget,
  runtime : RuntimeState?,
  next_id : Int,
) -> MountResult {
  let id = ElementId::new(next_id)
  let mut next = next_id + 1
  let children : Array[ElementNode] = []
  let mut component_subscriptions : Array[StateSubscription] = []
  let mut component_effects : Array[ComponentEffect] = []
  match (spec.build_child, runtime) {
    (Some(build), Some(runtime)) => {
      let built = build_component_child(build, runtime, id, [], [])
      component_subscriptions = built.subscriptions
      component_effects = built.effects
      let mounted = mount_runtime_widget_for_runtime(
        built.child_widget,
        Some(runtime),
        next,
      )
      children.push(mounted.node)
      next = mounted.next_id
    }
    _ => ()
  }
  for child_widget in (spec.children)() {
    let mounted = mount_runtime_widget_for_runtime(child_widget, runtime, next)
    children.push(mounted.node)
    next = mounted.next_id
  }
  {
    node: {
      id,
      key: spec.identity_key(),
      widget: spec,
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
  next_widget : RuntimeWidget,
  runtime : RuntimeState?,
  next_id : Int,
) -> ReconcileResult {
  if !old.widget.same_identity(next_widget) {
    old.cancel_component_tree_subscriptions()
    let mounted = mount_runtime_widget_for_runtime(
      next_widget, runtime, next_id,
    )
    {
      node: mounted.node,
      next_id: mounted.next_id,
      dirty_kind: ReconcileLayout,
    }
  } else {
    let own_dirty = old.widget.reconcile_dirty_kind(next_widget)
    let next_widget = preserve_widget_runtime_state(old.widget, next_widget)
    old.widget = next_widget
    old.key = old.widget.identity_key()
    let children_result = if old.widget.is_building_widget() {
      {
        children: old.children,
        next_id,
        dirty_kind: ReconcileDirtyKind::ReconcileClean,
      }
    } else {
      reconcile_children_for_runtime(old.children, old.widget, runtime, next_id)
    }
    old.children = children_result.children
    let dirty_kind = own_dirty.combine(children_result.dirty_kind)
    old.apply_reconcile_dirty(dirty_kind)
    { node: old, next_id: children_result.next_id, dirty_kind }
  }
}

///|
fn preserve_widget_runtime_state(
  old : RuntimeWidget,
  next : RuntimeWidget,
) -> RuntimeWidget {
  { ..next, state: old.state }
}

///|
fn reconcile_children_for_runtime(
  old_children : Array[ElementNode],
  next_widget : RuntimeWidget,
  runtime : RuntimeState?,
  next_id : Int,
) -> ChildrenReconcileResult {
  let next_widgets = child_widgets(next_widget)
  let children : Array[ElementNode] = []
  let used : Array[Bool] = []
  for _ in old_children {
    used.push(false)
  }
  let mut next = next_id
  let mut dirty = ReconcileDirtyKind::ReconcileClean
  for index, child_widget in next_widgets {
    let old_index = find_reusable_child(old_children, used, child_widget, index)
    match old_index {
      Some(old_index) => {
        used[old_index] = true
        let result = reconcile_element_for_runtime(
          old_children[old_index],
          child_widget,
          runtime,
          next,
        )
        children.push(result.node)
        next = result.next_id
        dirty = dirty.combine(result.dirty_kind)
      }
      None => {
        let mounted = mount_runtime_widget_for_runtime(
          child_widget, runtime, next,
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
fn find_reusable_child(
  old_children : Array[ElementNode],
  used : Array[Bool],
  child_widget : RuntimeWidget,
  index : Int,
) -> Int? {
  match child_widget.identity_key() {
    Some(key) => {
      for old_index, old_child in old_children {
        if !used[old_index] &&
          old_child.key == Some(key) &&
          old_child.widget.kind() == child_widget.kind() {
          return Some(old_index)
        }
      }
      None
    }
    None =>
      if index < old_children.length() &&
        !used[index] &&
        old_children[index].key is None &&
        old_children[index].widget.kind() == child_widget.kind() {
        Some(index)
      } else {
        None
      }
  }
}

///|
fn child_widgets(spec : RuntimeWidget) -> Array[RuntimeWidget] {
  (spec.children)()
}
