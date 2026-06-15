///|
fn RuntimeState::request_redraw(self : RuntimeState) -> Unit {
  self.needs_redraw = true
  match self.redraw_callback {
    Some(callback) => callback()
    None => ()
  }
}

///|
fn RuntimeState::ensure_render_tree(self : RuntimeState) -> Unit {
  if self.needs_rebuild || self.needs_layout || self.needs_paint {
    self.render_current_tree()
  }
}

///|
fn RuntimeState::ensure_layout_tree(self : RuntimeState) -> Unit {
  if self.needs_rebuild || self.needs_layout {
    self.layout_current_tree()
  }
}

///|
fn RuntimeState::layout_current_tree(self : RuntimeState) -> Unit {
  self.rebuild_if_possible()
  self.layout_pass_count = self.layout_pass_count + 1
  self.layout_tree = {
    root: self.element_tree.root.place_with_text_system(
      Rect::new(x=0.0, y=0.0, width=self.size.width, height=self.size.height),
      text_system=self.text_system,
      layout_direction=self.environment.layout_direction,
    ),
  }
  self.needs_rebuild = false
  self.needs_layout = false
}

///|
fn RuntimeState::render_current_tree(self : RuntimeState) -> Unit {
  let previous_render = self.render_tree
  let dirty_ids = self.dirty_elements.copy()
  let force_full_reason = if self.needs_rebuild {
    Some("rebuild requested")
  } else if previous_render.root.element_id.value() == 0 {
    Some("initial frame")
  } else {
    None
  }
  self.ensure_layout_tree()
  self.paint_pass_count = self.paint_pass_count + 1
  self.render_tree = {
    root: self.element_tree.root.render_focused_with_text_system(
      self.layout_tree.root,
      focused=self.focused_element,
      environment=self.environment,
      text_system=self.text_system,
    ),
  }
  self.last_damage_region = self.compute_damage_region(
    previous_render,
    self.render_tree,
    dirty_ids,
    force_full_reason~,
  )
  self.needs_rebuild = false
  self.needs_layout = false
  self.needs_paint = false
  self.clear_dirty_queue()
}

///|
fn RuntimeState::compute_damage_region(
  self : RuntimeState,
  previous : RenderTree,
  current : RenderTree,
  dirty_ids : Array[ElementId],
  force_full_reason~ : String?,
) -> DamageRegion {
  match force_full_reason {
    Some(reason) => DamageRegion::full(reason)
    None => {
      if dirty_ids.is_empty() {
        return DamageRegion::full("dirty bounds unavailable")
      }
      let surface = Rect::new(
        x=0.0,
        y=0.0,
        width=self.size.width,
        height=self.size.height,
      )
      let rects : Array[Rect] = []
      let mut missing_bounds = false
      for id in dirty_ids {
        if !previous.root.has_dirty_descendant(id, dirty_ids) &&
          !current.root.has_dirty_descendant(id, dirty_ids) {
          let mut found_bounds = false
          match previous.root.find_damage_bounds(id) {
            Some(bounds) => {
              rects.push(bounds)
              found_bounds = true
            }
            None => ()
          }
          match current.root.find_damage_bounds(id) {
            Some(bounds) => {
              rects.push(bounds)
              found_bounds = true
            }
            None => ()
          }
          if !found_bounds {
            missing_bounds = true
          }
        }
      }
      if missing_bounds || rects.is_empty() {
        DamageRegion::full("dirty bounds unavailable")
      } else {
        DamageRegion::from_rects(rects, surface)
      }
    }
  }
}

///|
fn RuntimeState::record_cached_layer_updates(
  self : RuntimeState,
  commands : Array[DrawCommand],
) -> Unit {
  let mut updated = false
  for command in commands {
    match command {
      BeginCachedLayer(spec) =>
        if self.record_cached_layer_update(spec) {
          updated = true
        }
      _ => ()
    }
  }
  if updated {
    self.cache_epoch = self.cache_epoch + 1
  }
}

///|
fn RuntimeState::record_cached_layer_update(
  self : RuntimeState,
  spec : CachedLayerSpec,
) -> Bool {
  let retained : Array[CachedLayerState] = []
  let mut found = false
  let mut changed = false
  for existing in self.known_layer_cache_keys {
    if existing.key == spec.key {
      found = true
      if existing.content_revision != spec.content_revision {
        changed = true
      }
      retained.push({ key: spec.key, content_revision: spec.content_revision })
    } else {
      retained.push(existing)
    }
  }
  if !found {
    retained.push({ key: spec.key, content_revision: spec.content_revision })
    changed = true
  }
  if changed {
    self.known_layer_cache_keys.clear()
    self.known_layer_cache_keys.append(retained)
  }
  changed
}

///|
fn RuntimeState::invalidate_cached_layer_key(
  self : RuntimeState,
  key : String,
) -> Unit {
  let retained : Array[CachedLayerState] = []
  for existing in self.known_layer_cache_keys {
    if existing.key != key {
      retained.push(existing)
    }
  }
  if retained.length() != self.known_layer_cache_keys.length() {
    self.known_layer_cache_keys.clear()
    self.known_layer_cache_keys.append(retained)
    self.cache_epoch = self.cache_epoch + 1
    self.request_redraw()
  }
}

///|
fn push_unique_element_id(queue : Array[ElementId], id : ElementId) -> Unit {
  if !queue.any(existing => existing == id) {
    queue.push(id)
  }
}

///|
fn RuntimeState::queue_dirty_element(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  push_unique_element_id(self.dirty_elements, id)
}

///|
fn RuntimeState::queue_build_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.queue_dirty_element(id)
  push_unique_element_id(self.dirty_build_elements, id)
}

///|
fn RuntimeState::queue_layout_dirty(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  self.queue_dirty_element(id)
  push_unique_element_id(self.dirty_layout_elements, id)
}

///|
fn RuntimeState::queue_paint_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.queue_dirty_element(id)
  push_unique_element_id(self.dirty_paint_elements, id)
}

///|
fn RuntimeState::mark_build_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.queue_build_dirty(id)
  self.queue_layout_dirty(id)
  self.queue_paint_dirty(id)
  self.needs_rebuild = true
  self.needs_layout = true
  self.needs_paint = true
  self.needs_redraw = true
}

///|
fn RuntimeState::mark_layout_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.queue_layout_dirty(id)
  self.queue_paint_dirty(id)
  self.needs_layout = true
  self.needs_paint = true
  self.needs_redraw = true
}

///|
fn RuntimeState::mark_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.queue_paint_dirty(id)
  ignore(self.element_tree.root.mark_paint_dirty_by_id(id))
  self.needs_paint = true
  self.needs_redraw = true
}

///|
fn RuntimeState::mark_current_dirty_elements(self : RuntimeState) -> Unit {
  let ids : Array[ElementId] = []
  let build_ids : Array[ElementId] = []
  let layout_ids : Array[ElementId] = []
  let paint_ids : Array[ElementId] = []
  self.element_tree.root.collect_dirty_element_ids_by_kind(
    ids, build_ids, layout_ids, paint_ids,
  )
  if ids.is_empty() {
    self.mark_dirty(self.element_tree.id())
  } else {
    for id in ids {
      self.queue_dirty_element(id)
    }
    if !build_ids.is_empty() {
      for id in build_ids {
        push_unique_element_id(self.dirty_build_elements, id)
      }
      self.needs_rebuild = true
    }
    if !layout_ids.is_empty() {
      for id in layout_ids {
        push_unique_element_id(self.dirty_layout_elements, id)
      }
      self.needs_layout = true
    }
    for id in paint_ids {
      push_unique_element_id(self.dirty_paint_elements, id)
    }
    self.needs_paint = true
    self.needs_redraw = true
  }
}

///|
fn RuntimeState::dirty_count(self : RuntimeState) -> Int {
  self.dirty_elements.length()
}

///|
fn RuntimeState::dirty_element_ids(self : RuntimeState) -> Array[ElementId] {
  self.dirty_elements.copy()
}

///|
fn RuntimeState::clear_dirty_queue(self : RuntimeState) -> Unit {
  self.dirty_elements.clear()
  self.dirty_build_elements.clear()
  self.dirty_layout_elements.clear()
  self.dirty_paint_elements.clear()
}
