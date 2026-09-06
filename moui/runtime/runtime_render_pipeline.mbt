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
  // Overlay/presentation placement runs after the layout fixpoint so anchor
  // resolution never re-enters layout and never keys layout caches.
  self.apply_overlay_placements()
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
  self.anchor_registry.clear()
  self.element_tree.root.collect_anchor_frames(
    self.layout_tree.root,
    self.anchor_registry,
  )
  self.dirty.needs_rebuild = false
  self.dirty.needs_layout = false
  self.dirty.dirty_layout_elements.clear()
  self.refresh_dirty_element_queue()
  ignore(self.try_pending_scroll_from_current_layout())
}

///|
/// Compute final overlay frames from the fresh anchor registry. Overlay hosts
/// position their presentation children during layout only provisionally
/// (correct sizes, placeholder origins); this pass resolves the anchors and,
/// when a computed frame differs from the placed frame, re-places the tree
/// with the overrides applied. The registry is position-snapshotted from the
/// base tree, so the resolved frames are stable across subsequent cache hits.
fn RuntimeState::apply_overlay_placements(self : RuntimeState) -> Unit {
  let context : @core.OverlayPlacementContext = {
    viewport: Rect::new(
      x=0.0,
      y=0.0,
      width=self.size.width,
      height=self.size.height,
    ),
    host_frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    child_sizes: self.layout_tree.root.children.map(child => child.frame.size),
    anchor_frames: self.anchor_registry.snapshot(),
    state: self.element_tree.root.control.view_state,
  }
  let overrides : Array[(Int, Array[(Int, Rect)])] = []
  let spines : Array[ElementId] = []
  let layers : Array[ElementId] = []
  let active_surfaces : Array[ElementId] = []
  collect_overlay_overrides(
    self.element_tree.root,
    self.layout_tree.root,
    context,
    [],
    overrides,
    spines,
    layers,
    active_surfaces,
  )
  self.layer_stack = layers
  self.track_overlay_surface_lifecycle(active_surfaces)
  if overrides.is_empty() {
    self.overlay_overrides = []
    return
  }
  self.overlay_overrides = overrides
  // Force a re-place that consumes the overrides; unchanged subtrees still
  // reuse their measured caches, so only positioned frames are recomputed.
  self.element_tree.root.layout_cache.clear()
  self.layout_tree = {
    root: self.element_tree.root.place_with_text_system(
      Rect::new(x=0.0, y=0.0, width=self.size.width, height=self.size.height),
      environment=self.environment,
      text_system=self.text_system,
      layout_direction=self.environment.layout_direction,
      overlay_overrides=self.overlay_overrides,
    ),
  }
  // Ancestor render caches embed descendant paint bounds; the re-place moved
  // overlay frames, so every cache along the hosts' ancestor spines is stale.
  for id in spines {
    self.mark_dirty(id)
  }
  self.dirty.needs_paint = true
  self.dirty.needs_redraw = true
}

///|
/// Descend the element/placed trees in lockstep and collect final overlay
/// frames for every node that reports `place_overlays` positions differing
/// from its currently placed child frames. `spines` receives the ancestor
/// element paths (including the host) of every host whose frames changed, so
/// stale ancestor render caches can be cleared.
fn collect_overlay_overrides(
  element : ElementNode,
  placed : PlacedNode,
  context : @core.OverlayPlacementContext,
  path : Array[ElementId],
  out : Array[(Int, Array[(Int, Rect)])],
  spines : Array[ElementId],
  layers : Array[ElementId],
  active_surfaces : Array[ElementId],
) -> Unit {
  let child_path : Array[ElementId] = path.copy()
  child_path.push(element.id)
  match
    element.view_node.place_overlays({
      ..context,
      host_frame: placed.frame,
      child_sizes: placed.children.map(child => child.frame.size),
      state: element.control.view_state,
    }) {
    Some(pairs) => {
      // Overrides must cover every overlay-positioned child: the re-place
      // rebuilds the spine and would otherwise drop unchanged children back to
      // their provisional frames.
      let any_changed = pairs
        .iter()
        .any(pair => {
          pair.0 < placed.children.length() &&
          placed.children[pair.0].frame != pair.1
        })
      // Overrides must cover every overlay-positioned child: the re-place
      // rebuilds the spine and would otherwise drop unchanged children back to
      // their provisional frames.
      let any_changed = pairs
        .iter()
        .any(pair => {
          pair.0 < placed.children.length() &&
          placed.children[pair.0].frame != pair.1
        })
      if any_changed {
        out.push((element.id.value(), pairs))
        for id in child_path {
          spines.push(id)
        }
      }
      if pairs.length() > 0 &&
        element.view_node.keyboard_policy()
        is @core.KeyboardPolicy::TopMostDismissal {
        layers.push(element.id)
      }
      for pair in pairs {
        if pair.0 < element.children.length() {
          active_surfaces.push(element.children[pair.0].id)
        }
      }
    }
    None => ()
  }
  for index, child in element.children {
    if index < placed.children.length() {
      collect_overlay_overrides(
        child,
        placed.children[index],
        context,
        child_path,
        out,
        spines,
        layers,
        active_surfaces,
      )
    }
  }
}

///|
fn RuntimeState::render_current_tree(self : RuntimeState) -> Unit {
  let previous_render = self.render_tree
  let dirty_ids = self.dirty.dirty_paint_elements.to_array()
  let force_full_reason = match self.dirty.full_damage_reason {
    Some(reason) => Some(reason)
    None =>
      if previous_render.root.element_id.value() == 0 {
        Some("initial frame")
      } else {
        None
      }
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
      overlay_enter=self.overlay_enter_times,
    ),
  }
  // Fold the per-subtree animation flag up to the root: if any painted node
  // reported a mid-animation sample, keep the host ticking redraws until the
  // animation settles. Controls clear this once progress reaches 1.0. Exit
  // ghosts are command snapshots without render nodes, so their in-flight
  // fades must be latched here explicitly or they freeze mid-fade.
  self.animfocus.active_animations = self.render_tree.root.animating ||
    !self.exiting_overlays.is_empty()
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
  self.dirty.full_damage_reason = None
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
      let dirty = DirtyIdSet::new()
      for id in dirty_ids {
        dirty.push(id)
      }
      // One pass per tree replaces the previous up-to-four full traversals
      // per dirty id (has_dirty_descendant + find_damage_bounds on both
      // trees, each a fresh O(n) DFS).
      let previous_index = DamageIndex::build(previous.root, dirty)
      let current_index = DamageIndex::build(current.root, dirty)
      let surface = Rect::new(
        x=0.0,
        y=0.0,
        width=self.size.width,
        height=self.size.height,
      )
      let rects : Array[Rect] = []
      let mut missing_bounds = false
      for id in dirty_ids {
        if !previous_index.has_dirty_descendant(id) &&
          !current_index.has_dirty_descendant(id) {
          let mut found_bounds = false
          match previous_index.damage_bounds(id) {
            Some(bounds) => {
              rects.push(bounds)
              found_bounds = true
            }
            None => ()
          }
          match current_index.damage_bounds(id) {
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
fn RuntimeState::queue_dirty_element(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  self.dirty.dirty_elements.push(id)
}

///|
fn RuntimeState::queue_build_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.dirty.dirty_build_elements.push(id)
}

///|
fn RuntimeState::queue_layout_dirty(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  self.dirty.dirty_layout_elements.push(id)
}

///|
fn RuntimeState::queue_paint_dirty(self : RuntimeState, id : ElementId) -> Unit {
  self.dirty.dirty_paint_elements.push(id)
}

///|
fn RuntimeState::queue_semantics_dirty(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  self.dirty.dirty_semantics_elements.push(id)
}

///|
fn RuntimeState::queue_platform_dirty(
  self : RuntimeState,
  id : ElementId,
) -> Unit {
  self.dirty.dirty_platform_elements.push(id)
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
  let ids = DirtyIdSet::new()
  let build_ids = DirtyIdSet::new()
  let layout_ids = DirtyIdSet::new()
  let paint_ids = DirtyIdSet::new()
  let semantics_ids = DirtyIdSet::new()
  let platform_ids = DirtyIdSet::new()
  self.element_tree.root.collect_dirty_element_ids_by_kind(
    ids, build_ids, layout_ids, paint_ids, semantics_ids, platform_ids,
  )
  if ids.is_empty() {
    self.mark_dirty(self.element_tree.id())
  } else {
    for id in ids.items {
      self.queue_dirty_element(id)
    }
    if !build_ids.is_empty() {
      for id in build_ids.items {
        self.dirty.dirty_build_elements.push(id)
      }
      self.dirty.needs_rebuild = true
    }
    if !layout_ids.is_empty() {
      self.mark_visual_work()
      for id in layout_ids.items {
        self.dirty.dirty_layout_elements.push(id)
      }
      self.dirty.needs_layout = true
    }
    for id in paint_ids.items {
      self.dirty.dirty_paint_elements.push(id)
    }
    for id in semantics_ids.items {
      self.mark_semantics_dirty(id)
    }
    for id in platform_ids.items {
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
  self.dirty.dirty_elements.to_array()
}

///|
fn RuntimeState::refresh_dirty_element_queue(self : RuntimeState) -> Unit {
  self.dirty.dirty_elements.clear()
  for id in self.dirty.dirty_build_elements.items {
    self.dirty.dirty_elements.push(id)
  }
  for id in self.dirty.dirty_layout_elements.items {
    self.dirty.dirty_elements.push(id)
  }
  for id in self.dirty.dirty_paint_elements.items {
    self.dirty.dirty_elements.push(id)
  }
  for id in self.dirty.dirty_semantics_elements.items {
    self.dirty.dirty_elements.push(id)
  }
  for id in self.dirty.dirty_platform_elements.items {
    self.dirty.dirty_elements.push(id)
  }
}

///|
/// Overlay surface lifecycle (ADR 0033): surfaces that disappeared since the
/// previous pass are retained as fading command snapshots (exit); surfaces
/// that just appeared get an enter fade driven by the frame clock through the
/// render pass (see `RenderNode.render_opacity`).
fn RuntimeState::track_overlay_surface_lifecycle(
  self : RuntimeState,
  active_surfaces : Array[ElementId],
) -> Unit {
  let now_ms = self.animfocus.now_ms
  // Exit retention: capture removed surfaces from the previous render tree.
  for id in self.active_surface_ids {
    let still_active = active_surfaces.any(active => active == id)
    if !still_active {
      match self.render_tree.root.find_render_node(id) {
        Some(node) => {
          let commands : Array[DrawCommand] = []
          node.collect_draw_commands(commands)
          if commands.length() > 0 {
            self.exiting_overlays.push({
              commands,
              started_ms: now_ms,
              duration_ms: self.overlay_transition_duration_ms(),
            })
            self.dirty.full_damage_reason = Some("overlay exited")
          }
        }
        None => ()
      }
    }
  }
  self.active_surface_ids = active_surfaces.copy()
  // Enter fade bookkeeping: record first-seen time. Completed entries stay
  // registered so an active surface is never re-recorded (which would restart
  // its fade every placement pass and make it flicker); entries are dropped
  // only when their surface disappears.
  let mut index = 0
  while index < self.overlay_enter_times.length() {
    let entry = self.overlay_enter_times[index]
    let still_active = active_surfaces.any(active => active == entry.0)
    if !still_active {
      ignore(self.overlay_enter_times.remove(index))
    } else {
      index = index + 1
    }
  }
  for id in active_surfaces {
    let known = self.overlay_enter_times.any(entry => entry.0 == id)
    if !known {
      self.overlay_enter_times.push((id, now_ms))
    }
  }
  let any_fading = self.overlay_enter_times.any(entry => {
    now_ms - entry.1 < self.overlay_transition_duration_ms()
  })
  if any_fading {
    self.animfocus.active_animations = true
  }
}

///|
/// Duration of overlay enter/exit fades, resolved from the environment's
/// resolved theme motion tier. Reduced-motion environments complete
/// immediately (duration 0), matching the core animation primitives.
fn RuntimeState::overlay_transition_duration_ms(self : RuntimeState) -> Double {
  if self.environment.reduced_motion {
    return 0.0
  }
  self.environment.theme.motion.normal_ms
}
