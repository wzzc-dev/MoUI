///|
priv struct ElementEventResult {
  changed : Bool
  activated : Bool
  captured : Bool
  capture_target : ElementId?
  focused : ElementId?
  deliveries : Array[() -> Unit]
}

///|
fn ElementNode::has_dirty_layout(self : ElementNode) -> Bool {
  self.dirty.has_layout()
}

///|
fn ElementNode::has_dirty_paint(self : ElementNode) -> Bool {
  self.dirty.has_paint()
}

///|
fn ElementNode::has_dirty_platform(self : ElementNode) -> Bool {
  self.dirty.has_platform()
}

///|
fn ElementNode::has_dirty_semantics(self : ElementNode) -> Bool {
  self.dirty.has_semantics()
}

///|
fn ElementNode::refresh_descendant_dirty_flags(self : ElementNode) -> Unit {
  self.dirty.descendant_build = self.children.any(child => {
    child.dirty.has_build()
  })
  self.dirty.descendant_layout = self.children.any(child => {
    child.dirty.has_layout()
  })
  self.dirty.descendant_paint = self.children.any(child => {
    child.dirty.has_paint()
  })
  self.dirty.descendant_semantics = self.children.any(child => {
    child.dirty.has_semantics()
  })
  self.dirty.descendant_platform = self.children.any(child => {
    child.dirty.has_platform()
  })
}

///|
fn ElementNode::view_tree_inspector_snapshot(
  self : ElementNode,
) -> ViewTreeInspectorSnapshot {
  let nodes : Array[ViewInspectorSummary] = []
  self.collect_view_summaries(nodes, depth=0)
  {
    root_kind: runtime_view_node_inspector_kind_label(self.view_node),
    node_count: nodes.length(),
    control_count: self.inspector_control_count(),
    modified_count: self.inspector_modified_count(),
    dirty_build_count: nodes.filter(node => node.needs_build).length(),
    dirty_layout_count: nodes.filter(node => node.needs_layout).length(),
    dirty_paint_count: nodes.filter(node => node.needs_paint).length(),
    nodes,
  }
}

///|
fn ElementNode::inspector_layout_cache_hits(self : ElementNode) -> Int {
  let mut total = self.layout_cache.hit_count
  for child in self.children {
    total = total + child.inspector_layout_cache_hits()
  }
  total
}

///|
fn ElementNode::inspector_layout_cache_misses(self : ElementNode) -> Int {
  let mut total = self.layout_cache.miss_count
  for child in self.children {
    total = total + child.inspector_layout_cache_misses()
  }
  total
}

///|
fn ElementNode::inspector_render_cache_hits(self : ElementNode) -> Int {
  let mut total = self.render_cache.hit_count
  for child in self.children {
    total = total + child.inspector_render_cache_hits()
  }
  total
}

///|
fn ElementNode::inspector_render_cache_misses(self : ElementNode) -> Int {
  let mut total = self.render_cache.miss_count
  for child in self.children {
    total = total + child.inspector_render_cache_misses()
  }
  total
}

///|
fn ElementNode::inspector_hit_path(
  self : ElementNode,
  point : @core.Point,
  render : RenderNode,
) -> Array[Int] {
  let path = [self.id.value()]
  let mut index = self.children.length() - 1
  while index >= 0 {
    if index < render.children.length() &&
      render.children[index].hit_bounds().contains(point) {
      path.append(
        self.children[index].inspector_hit_path(point, render.children[index]),
      )
      return path
    }
    index = index - 1
  }
  path
}

///|
fn ElementNode::collect_view_summaries(
  self : ElementNode,
  nodes : Array[ViewInspectorSummary],
  depth~ : Int,
) -> Unit {
  nodes.push({
    element_id: self.id.value(),
    kind: runtime_view_node_inspector_kind_label(self.view_node),
    key: match self.key {
      Some(key) => key.value()
      None => ""
    },
    depth,
    child_count: self.children.length(),
    needs_build: self.dirty.needs_build,
    needs_layout: self.dirty.needs_layout,
    needs_paint: self.dirty.needs_paint,
  })
  for child in self.children {
    child.collect_view_summaries(nodes, depth=depth + 1)
  }
}

///|
fn ElementNode::inspector_control_count(self : ElementNode) -> Int {
  let mut count = if runtime_view_node_inspector_is_control(self.view_node) {
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
  let mut count = if self.view_node.identity().kind.has_prefix("Modified<") {
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
fn ElementNode::mark_paint_dirty_by_id(
  self : ElementNode,
  id : ElementId,
) -> Bool {
  if self.id == id {
    self.dirty.mark_paint()
    self.render_cache.clear()
    true
  } else {
    for child in self.children {
      if child.mark_paint_dirty_by_id(id) {
        self.dirty.mark_paint_descendant()
        self.render_cache.invalidate_composition()
        return true
      }
    }
    false
  }
}

///|
fn ElementNode::mark_semantics_dirty_by_id(
  self : ElementNode,
  id : ElementId,
) -> Bool {
  if self.id == id {
    self.dirty.mark_semantics()
    true
  } else {
    for child in self.children {
      if child.mark_semantics_dirty_by_id(id) {
        self.dirty.mark_semantics_descendant()
        return true
      }
    }
    false
  }
}

///|
fn ElementNode::invalidate_uncommitted_semantics(self : ElementNode) -> Unit {
  // Nodes omitted from the committed tree stay invalidated. That lets hidden
  // and merged descendants rebuild their contribution when an ancestor needs
  // it again without retaining an unreachable duplicate subtree.
  self.dirty.needs_semantics = true
  self.semantics_cache.clear()
  for child in self.children {
    child.invalidate_uncommitted_semantics()
  }
}

///|
fn ElementNode::mark_platform_dirty_by_id(
  self : ElementNode,
  id : ElementId,
) -> Bool {
  if self.id == id {
    self.dirty.mark_platform()
    true
  } else {
    for child in self.children {
      if child.mark_platform_dirty_by_id(id) {
        self.dirty.mark_platform_descendant()
        return true
      }
    }
    false
  }
}

///|
fn ElementNode::collect_dirty_element_ids_by_kind(
  self : ElementNode,
  all_ids : Array[ElementId],
  build_ids : Array[ElementId],
  layout_ids : Array[ElementId],
  paint_ids : Array[ElementId],
  semantics_ids : Array[ElementId],
  platform_ids : Array[ElementId],
) -> Unit {
  if self.dirty.needs_build ||
    self.dirty.needs_layout ||
    self.dirty.needs_paint ||
    self.dirty.needs_semantics ||
    self.dirty.needs_platform {
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
  if self.dirty.needs_semantics {
    push_unique_element_id(semantics_ids, self.id)
  }
  if self.dirty.needs_platform {
    push_unique_element_id(platform_ids, self.id)
  }
  for child in self.children {
    child.collect_dirty_element_ids_by_kind(
      all_ids, build_ids, layout_ids, paint_ids, semantics_ids, platform_ids,
    )
  }
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
fn ElementNode::clear_cached_layout_and_paint(self : ElementNode) -> Unit {
  self.layout_cache.clear()
  self.render_cache.clear()
}
