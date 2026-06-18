///|
priv struct ElementEventResult {
  changed : Bool
  activated : Bool
  focused : ElementId?
}

///|
fn ElementNode::rebuild_dirty_components(
  self : ElementNode,
  runtime : RuntimeState,
  next_id : Int,
) -> ReconcileResult {
  let mut next = next_id
  let mut dirty_kind = ReconcileDirtyKind::ReconcileClean
  if self.dirty.needs_build {
    match self.erased_view_node.build_child {
      Some(build) => {
        let built = build_component_child(
          build,
          runtime,
          self.id,
          self.component.component_subscriptions,
          self.component.component_effects,
        )
        self.component.component_subscriptions = built.subscriptions
        self.component.component_effects = built.effects
        let result = if self.children.length() > 0 {
          reconcile_element_for_runtime(
            self.children[0],
            built.child_erased_view_node,
            Some(runtime),
            next,
          )
        } else {
          let mounted = mount_erased_view_node_for_runtime(
            built.child_erased_view_node,
            Some(runtime),
            next,
          )
          {
            node: mounted.node,
            next_id: mounted.next_id,
            dirty_kind: ReconcileDirtyKind::ReconcileLayout,
          }
        }
        self.children = [result.node]
        next = result.next_id
        dirty_kind = dirty_kind.combine(result.dirty_kind)
      }
      None => ()
    }
    self.dirty.needs_build = false
    self.apply_reconcile_dirty(dirty_kind)
  }
  let children : Array[ElementNode] = []
  for child in self.children {
    let result = child.rebuild_dirty_components(runtime, next)
    children.push(result.node)
    next = result.next_id
    dirty_kind = dirty_kind.combine(result.dirty_kind)
  }
  self.children = children
  { node: self, next_id: next, dirty_kind }
}

///|
fn ElementNode::has_dirty_build(self : ElementNode) -> Bool {
  if self.dirty.needs_build {
    true
  } else {
    self.children.any(child => child.has_dirty_build())
  }
}

///|
fn ElementNode::has_dirty_layout(self : ElementNode) -> Bool {
  if self.dirty.needs_layout {
    true
  } else {
    self.children.any(child => child.has_dirty_layout())
  }
}

///|
fn ElementNode::has_dirty_paint(self : ElementNode) -> Bool {
  if self.dirty.needs_paint {
    true
  } else {
    self.children.any(child => child.has_dirty_paint())
  }
}

///|
fn ElementNode::view_tree_inspector_snapshot(
  self : ElementNode,
) -> ViewTreeInspectorSnapshot {
  let nodes : Array[ViewInspectorSummary] = []
  self.collect_view_summaries(nodes)
  {
    root_kind: self.erased_view_node.inspector_kind_label(),
    node_count: nodes.length(),
    component_count: self.inspector_component_count(),
    control_count: self.inspector_control_count(),
    modified_count: self.inspector_modified_count(),
    dirty_build_count: nodes.filter(node => node.needs_build).length(),
    dirty_layout_count: nodes.filter(node => node.needs_layout).length(),
    dirty_paint_count: nodes.filter(node => node.needs_paint).length(),
    nodes,
  }
}

///|
fn ElementNode::collect_view_summaries(
  self : ElementNode,
  nodes : Array[ViewInspectorSummary],
) -> Unit {
  nodes.push({
    element_id: self.id,
    kind: self.erased_view_node.inspector_kind_label(),
    key: match self.key {
      Some(key) => key.value
      None => ""
    },
    child_count: self.children.length(),
    needs_build: self.dirty.needs_build,
    needs_layout: self.dirty.needs_layout,
    needs_paint: self.dirty.needs_paint,
  })
  for child in self.children {
    child.collect_view_summaries(nodes)
  }
}

///|
fn ElementNode::inspector_component_count(self : ElementNode) -> Int {
  let mut count = if self.erased_view_node.is_building_erased_view_node() {
    1
  } else {
    0
  }
  for child in self.children {
    count = count + child.inspector_component_count()
  }
  count
}

///|
fn ElementNode::inspector_control_count(self : ElementNode) -> Int {
  let mut count = if self.erased_view_node.inspector_is_control() {
    1
  } else {
    0
  }
  for child in self.children {
    count = count + child.inspector_control_count()
  }
  count
}

///|
fn ElementNode::inspector_modified_count(self : ElementNode) -> Int {
  let mut count = if self.erased_view_node.identity.kind.has_prefix("Modified<") {
    1
  } else {
    0
  }
  for child in self.children {
    count = count + child.inspector_modified_count()
  }
  count
}

///|
fn ElementNode::mark_build_dirty_by_id(
  self : ElementNode,
  id : ElementId,
) -> Bool {
  if self.id == id {
    self.dirty.mark_build()
    self.clear_cached_layout_and_paint()
    true
  } else {
    let mut found = false
    for child in self.children {
      found = child.mark_build_dirty_by_id(id) || found
    }
    if found {
      self.dirty.mark_layout()
      self.clear_cached_layout_and_paint()
    }
    found
  }
}

///|
fn ElementNode::mark_paint_dirty_by_id(
  self : ElementNode,
  id : ElementId,
) -> Bool {
  if self.id == id {
    self.dirty.mark_paint()
    self.render_cache.clear()
    true
  } else {
    let mut found = false
    for child in self.children {
      found = child.mark_paint_dirty_by_id(id) || found
    }
    if found {
      self.dirty.mark_paint()
      self.render_cache.clear()
    }
    found
  }
}

///|
fn ElementNode::collect_dirty_element_ids_by_kind(
  self : ElementNode,
  all_ids : Array[ElementId],
  build_ids : Array[ElementId],
  layout_ids : Array[ElementId],
  paint_ids : Array[ElementId],
) -> Unit {
  if self.dirty.needs_build || self.dirty.needs_layout || self.dirty.needs_paint {
    push_unique_element_id(all_ids, self.id)
  }
  if self.dirty.needs_build {
    push_unique_element_id(build_ids, self.id)
  }
  if self.dirty.needs_layout {
    push_unique_element_id(layout_ids, self.id)
  }
  if self.dirty.needs_paint {
    push_unique_element_id(paint_ids, self.id)
  }
  for child in self.children {
    child.collect_dirty_element_ids_by_kind(
      all_ids, build_ids, layout_ids, paint_ids,
    )
  }
}

///|
fn ElementNode::mark_root_component_build_dirty(self : ElementNode) -> Bool {
  if self.erased_view_node.is_building_erased_view_node() {
    self.dirty.mark_build()
    self.clear_cached_layout_and_paint()
    true
  } else {
    false
  }
}

///|
fn ElementNode::mark_component_tree_build_dirty(self : ElementNode) -> Bool {
  let mut found = false
  if self.erased_view_node.is_building_erased_view_node() {
    self.dirty.mark_build()
    self.clear_cached_layout_and_paint()
    found = true
  }
  for child in self.children {
    found = child.mark_component_tree_build_dirty() || found
  }
  if found {
    self.dirty.mark_layout()
    self.clear_cached_layout_and_paint()
  }
  found
}

///|
fn ElementNode::mark_subtree_layout_dirty(self : ElementNode) -> Unit {
  self.dirty.mark_layout()
  self.clear_cached_layout_and_paint()
  for child in self.children {
    child.mark_subtree_layout_dirty()
  }
}

///|
fn ElementNode::cancel_component_tree_subscriptions(
  self : ElementNode,
  reason? : ComponentEffectCancelReason = ComponentEffectCancelReason::EffectUnmounted,
) -> Unit {
  self.cancel_component_subscriptions()
  self.cancel_component_effects(reason~)
  for child in self.children {
    child.cancel_component_tree_subscriptions(reason~)
  }
}

///|
fn ElementNode::cancel_component_subscriptions(self : ElementNode) -> Unit {
  for subscription in self.component.component_subscriptions {
    subscription.cancel()
  }
  self.component.component_subscriptions.clear()
}

///|
fn ElementNode::cancel_component_effects(
  self : ElementNode,
  reason~ : ComponentEffectCancelReason,
) -> Unit {
  ComponentEffect::finish_reuse(
    self.component.component_effects,
    reason~,
    cancel_reused=true,
  )
  self.component.component_effects.clear()
}

///|
fn ElementNode::clear_cached_layout_and_paint(self : ElementNode) -> Unit {
  self.layout_cache.clear()
  self.render_cache.clear()
}
