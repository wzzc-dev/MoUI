///|
fn RuntimeState::request_redraw(self : RuntimeState) -> Unit {
  self.dirty.needs_redraw = true
  match self.redraw_callback {
    Some(callback) => callback()
    None => ()
  }
}

///|
fn RuntimeState::request_rebuild_wakeup(self : RuntimeState) -> Unit {
  if !self.dirty.needs_redraw {
    self.dirty.rebuild_wakeup_redraw = true
  }
  self.request_redraw()
}

///|
fn RuntimeState::mark_visual_work(self : RuntimeState) -> Unit {
  self.dirty.rebuild_wakeup_redraw = false
}

///|
fn RuntimeState::settle_rebuild_wakeup(self : RuntimeState) -> Unit {
  if self.dirty.rebuild_wakeup_redraw &&
    !self.dirty.needs_rebuild &&
    !self.dirty.needs_layout &&
    !self.dirty.needs_paint &&
    !self.animfocus.active_animations {
    self.dirty.needs_redraw = false
    self.dirty.rebuild_wakeup_redraw = false
  }
}

///|
fn RuntimeState::ensure_render_tree(self : RuntimeState) -> Unit {
  self.rebuild_if_possible()
  if self.dirty.needs_layout || self.dirty.needs_paint {
    self.render_current_tree()
  }
  if self.dirty.needs_platform {
    self.refresh_platform_tree()
  }
}

///|
fn RuntimeState::refresh_platform_tree(self : RuntimeState) -> Unit {
  self.ensure_layout_tree()
  self.platform_tree = {
    root: self.element_tree.root.platform_with_environment(
      self.layout_tree.root,
      RenderEnvironment::from_environment(self.environment).with_text_system(
        self.text_system,
      ),
    ),
  }
  self.dirty.needs_platform = false
  self.dirty.dirty_platform_elements.clear()
  self.refresh_dirty_element_queue()
  self.settle_rebuild_wakeup()
}

///|
fn RuntimeState::ensure_layout_tree(self : RuntimeState) -> Unit {
  let mut passes = 0
  while self.dirty.needs_rebuild || self.dirty.needs_layout {
    if passes >= 64 {
      abort("runtime layout did not stabilize after 64 passes")
    }
    passes = passes + 1
    self.layout_current_tree()
  }
}

///|
fn RuntimeState::layout_current_tree(self : RuntimeState) -> Unit {
  self.rebuild_if_possible()
  self.stats.layout_pass_count = self.stats.layout_pass_count + 1
  self.layout_tree = {
    root: self.element_tree.root.place_with_text_system(
      Rect::new(x=0.0, y=0.0, width=self.size.width, height=self.size.height),
      environment=self.environment,
      text_system=self.text_system,
      layout_direction=self.environment.layout_direction,
    ),
  }
  self.dirty.needs_rebuild = false
  self.dirty.needs_layout = false
  self.dirty.dirty_layout_elements.clear()
  self.refresh_dirty_element_queue()
  ignore(self.try_pending_scroll_from_current_layout())
}

///|
fn RuntimeState::render_current_tree(self : RuntimeState) -> Unit {
  let previous_render = self.render_tree
  let dirty_ids = self.dirty.dirty_paint_elements.copy()
  let force_full_reason = if self.dirty.needs_rebuild {
    Some("rebuild requested")
  } else if previous_render.root.element_id.value() == 0 {
    Some("initial frame")
  } else {
    None
  }
  self.ensure_layout_tree()
  self.stats.paint_pass_count = self.stats.paint_pass_count + 1
  self.render_tree = {
    root: self.element_tree.root.render_focused_with_text_system(
      self.layout_tree.root,
      focused=self.animfocus.focused_element,
      environment=self.environment,
      text_system=self.text_system,
      now_ms=self.animfocus.now_ms,
    ),
  }
  // Fold the per-subtree animation flag up to the root: if any painted node
  // reported a mid-animation sample, keep the host ticking redraws until the
  // animation settles. Controls clear this once progress reaches 1.0.
  self.animfocus.active_animations = self.render_tree.root.animating
  // If an animation is still in flight, request another frame right after the
  // paint that observed it. This is evaluated after `active_animations` is
  // updated, so once a transition settles the flag flips false and the redraw
  // loop stops naturally instead of ticking one extra frame forever.
  if self.animfocus.active_animations {
    self.dirty.needs_redraw = true
    match self.redraw_callback {
      Some(callback) => callback()
      None => ()
    }
  }
  self.stats.last_damage_region = self.compute_damage_region(
    previous_render,
    self.render_tree,
    dirty_ids,
    force_full_reason~,
  )
  self.dirty.needs_rebuild = false
  self.dirty.needs_layout = false
  self.dirty.needs_paint = false
  self.dirty.dirty_paint_elements.clear()
  self.refresh_dirty_element_queue()
  if self.dirty.needs_platform {
    self.refresh_platform_tree()
  }
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
fn RuntimeState::record_cached_layer_frame(
  self : RuntimeState,
  next_known_layers : Array[CachedLayerState],
  next_admissions : Array[CachedLayerAdmissionState],
) -> Unit {
  let known_changed = !self.stats.known_layer_cache_keys.same_cached_layers(
    next_known_layers,
  )
  if known_changed {
    self.stats.cache_epoch = self.stats.cache_epoch + 1
  }
  self.stats.known_layer_cache_keys.clear()
  self.stats.known_layer_cache_keys.append(next_known_layers)
  self.stats.cached_layer_admissions.clear()
  self.stats.cached_layer_admissions.append(next_admissions)
}

///|
fn Array::same_cached_layers(
  self : Array[CachedLayerState],
  other : Array[CachedLayerState],
) -> Bool {
  if self.length() != other.length() {
    return false
  }
  for index in 0..<self.length() {
    if self[index].key != other[index].key ||
      self[index].content_revision != other[index].content_revision {
      return false
    }
  }
  true
}

///|
fn RuntimeState::invalidate_cached_layer_key(
  self : RuntimeState,
  key : String,
) -> Unit {
  let retained : Array[CachedLayerState] = []
  for existing in self.stats.known_layer_cache_keys {
    if existing.key != key {
      retained.push(existing)
    }
  }
  let known_changed = retained.length() !=
    self.stats.known_layer_cache_keys.length()
  if known_changed {
    self.stats.known_layer_cache_keys.clear()
    self.stats.known_layer_cache_keys.append(retained)
    self.stats.cache_epoch = self.stats.cache_epoch + 1
  }
  let admission_changed = self.remove_cached_layer_admissions(key)
  if known_changed || admission_changed {
    self.request_redraw()
  }
}

///|
fn RuntimeState::remove_cached_layer_admissions(
  self : RuntimeState,
  key : String,
) -> Bool {
  let retained : Array[CachedLayerAdmissionState] = []
  for admission in self.stats.cached_layer_admissions {
    if admission.key != key {
      retained.push(admission)
    }
  }
  if retained.length() != self.stats.cached_layer_admissions.length() {
    self.stats.cached_layer_admissions.clear()
    self.stats.cached_layer_admissions.append(retained)
    true
  } else {
    false
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
  push_unique_element_id(self.dirty.dirty_elements, id)
}

///|
fn RuntimeState::queue_build_dirty(self : RuntimeState, id : ElementId) -> Unit {
  push_unique_element_id(self.dirty.dirty_build_elements, id)
}

///|
fn RuntimeState::queue_layout_dirty(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  push_unique_element_id(self.dirty.dirty_layout_elements, id)
}

///|
fn RuntimeState::queue_paint_dirty(self : RuntimeState, id : ElementId) -> Unit {
  push_unique_element_id(self.dirty.dirty_paint_elements, id)
}

///|
fn RuntimeState::queue_semantics_dirty(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  push_unique_element_id(self.dirty.dirty_semantics_elements, id)
}

///|
fn RuntimeState::queue_platform_dirty(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  push_unique_element_id(self.dirty.dirty_platform_elements, id)
}

///|
fn RuntimeState::mark_build_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.mark_visual_work()
  self.queue_dirty_element(id)
  self.queue_build_dirty(id)
  self.queue_layout_dirty(id)
  self.queue_paint_dirty(id)
  self.queue_semantics_dirty(id)
  self.queue_platform_dirty(id)
  self.dirty.needs_rebuild = true
  self.dirty.needs_layout = true
  self.dirty.needs_paint = true
  self.dirty.needs_semantics = true
  self.dirty.needs_platform = true
  self.dirty.needs_redraw = true
}

///|
fn RuntimeState::mark_layout_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.mark_visual_work()
  self.queue_dirty_element(id)
  self.queue_layout_dirty(id)
  self.queue_paint_dirty(id)
  self.queue_semantics_dirty(id)
  self.queue_platform_dirty(id)
  self.dirty.needs_layout = true
  self.dirty.needs_paint = true
  self.dirty.needs_semantics = true
  self.dirty.needs_platform = true
  self.dirty.needs_redraw = true
}

///|
fn RuntimeState::mark_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.mark_visual_work()
  self.queue_dirty_element(id)
  self.queue_paint_dirty(id)
  ignore(self.element_tree.root.mark_paint_dirty_by_id(id))
  self.dirty.needs_paint = true
  self.dirty.needs_redraw = true
}

///|
fn RuntimeState::mark_semantics_dirty(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  self.queue_semantics_dirty(id)
  ignore(self.element_tree.root.mark_semantics_dirty_by_id(id))
  self.dirty.needs_semantics = true
}

///|
fn RuntimeState::mark_platform_dirty(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  self.queue_platform_dirty(id)
  ignore(self.element_tree.root.mark_platform_dirty_by_id(id))
  self.dirty.needs_platform = true
}

///|
fn RuntimeState::mark_current_dirty_elements(self : RuntimeState) -> Unit {
  let ids : Array[ElementId] = []
  let build_ids : Array[ElementId] = []
  let layout_ids : Array[ElementId] = []
  let paint_ids : Array[ElementId] = []
  let semantics_ids : Array[ElementId] = []
  let platform_ids : Array[ElementId] = []
  self.element_tree.root.collect_dirty_element_ids_by_kind(
    ids, build_ids, layout_ids, paint_ids, semantics_ids, platform_ids,
  )
  if ids.is_empty() {
    self.mark_dirty(self.element_tree.id())
  } else {
    for id in ids {
      self.queue_dirty_element(id)
    }
    if !build_ids.is_empty() {
      for id in build_ids {
        push_unique_element_id(self.dirty.dirty_build_elements, id)
      }
      self.dirty.needs_rebuild = true
    }
    if !layout_ids.is_empty() {
      self.mark_visual_work()
      for id in layout_ids {
        push_unique_element_id(self.dirty.dirty_layout_elements, id)
      }
      self.dirty.needs_layout = true
    }
    for id in paint_ids {
      push_unique_element_id(self.dirty.dirty_paint_elements, id)
    }
    for id in semantics_ids {
      self.mark_semantics_dirty(id)
    }
    for id in platform_ids {
      self.mark_platform_dirty(id)
    }
    if !paint_ids.is_empty() {
      self.mark_visual_work()
      self.dirty.needs_paint = true
      self.dirty.needs_redraw = true
    }
    if !semantics_ids.is_empty() {
      self.dirty.needs_semantics = true
    }
  }
}

///|
fn RuntimeState::dirty_count(self : RuntimeState) -> Int {
  self.dirty.dirty_elements.length()
}

///|
fn RuntimeState::dirty_element_ids(self : RuntimeState) -> Array[ElementId] {
  self.dirty.dirty_elements.copy()
}

///|
fn RuntimeState::refresh_dirty_element_queue(self : RuntimeState) -> Unit {
  self.dirty.dirty_elements.clear()
  for id in self.dirty.dirty_build_elements {
    push_unique_element_id(self.dirty.dirty_elements, id)
  }
  for id in self.dirty.dirty_layout_elements {
    push_unique_element_id(self.dirty.dirty_elements, id)
  }
  for id in self.dirty.dirty_paint_elements {
    push_unique_element_id(self.dirty.dirty_elements, id)
  }
  for id in self.dirty.dirty_semantics_elements {
    push_unique_element_id(self.dirty.dirty_elements, id)
  }
  for id in self.dirty.dirty_platform_elements {
    push_unique_element_id(self.dirty.dirty_elements, id)
  }
}
