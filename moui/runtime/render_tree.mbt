///|
fn RenderNode::collect_draw_commands(
  self : RenderNode,
  commands : Array[DrawCommand],
) -> Unit {
  let overlays : Array[DrawCommand] = []
  self.collect_draw_commands_with_overlays(commands, overlays)
  for command in overlays {
    commands.push(command)
  }
}

///|
fn RenderNode::collect_frame_commands(
  self : RenderNode,
  commands : Array[DrawCommand],
  known_layers : Array[CachedLayerState],
  previous_admissions : Array[CachedLayerAdmissionState],
  next_known_layers : Array[CachedLayerState],
  next_admissions : Array[CachedLayerAdmissionState],
) -> Unit {
  let overlays : Array[DrawCommand] = []
  self.collect_frame_commands_with_overlays(
    commands, overlays, known_layers, previous_admissions, next_known_layers, next_admissions,
  )
  for command in overlays {
    commands.push(command)
  }
}

///|
fn RenderNode::collect_frame_commands_with_overlays(
  self : RenderNode,
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
  known_layers : Array[CachedLayerState],
  previous_admissions : Array[CachedLayerAdmissionState],
  next_known_layers : Array[CachedLayerState],
  next_admissions : Array[CachedLayerAdmissionState],
) -> Unit {
  if self.is_repaint_boundary {
    match self.cached_layer_spec() {
      Some(spec) => {
        let visible_streak = previous_admissions.cached_layer_visible_streak(
            spec,
          ) +
          1
        next_admissions.record_cached_layer_admission(spec, visible_streak)
        if known_layers.has_current_cached_layer(spec) {
          commands.push(DrawCachedLayer(spec))
          next_known_layers.record_current_cached_layer(spec)
          self.collect_cached_overlay_commands(overlays)
        } else if visible_streak >= cached_layer_warmup_threshold() {
          commands.push(BeginCachedLayer(spec))
          self.collect_uncached_frame_commands_with_overlays(
            commands, overlays, known_layers, previous_admissions, next_known_layers,
            next_admissions,
          )
          commands.push(EndCachedLayer(spec.key))
          next_known_layers.record_current_cached_layer(spec)
        } else {
          self.collect_uncached_frame_commands_with_overlays(
            commands, overlays, known_layers, previous_admissions, next_known_layers,
            next_admissions,
          )
        }
      }
      None =>
        self.collect_uncached_frame_commands_with_overlays(
          commands, overlays, known_layers, previous_admissions, next_known_layers,
          next_admissions,
        )
    }
  } else {
    self.collect_uncached_frame_commands_with_overlays(
      commands, overlays, known_layers, previous_admissions, next_known_layers, next_admissions,
    )
  }
}

///|
fn RenderNode::collect_cached_overlay_commands(
  self : RenderNode,
  overlays : Array[DrawCommand],
) -> Unit {
  match self.cached_overlay_draw_commands {
    Some(cached_overlays) =>
      for command in cached_overlays {
        overlays.push(command)
      }
    None => ()
  }
}

///|
fn RenderNode::collect_draw_commands_with_overlays(
  self : RenderNode,
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
) -> Unit {
  match self.cached_draw_commands {
    Some(cached) => {
      for command in cached {
        commands.push(command)
      }
      match self.cached_overlay_draw_commands {
        Some(cached_overlays) =>
          for command in cached_overlays {
            overlays.push(command)
          }
        None => ()
      }
      return
    }
    None => ()
  }
  self.collect_uncached_draw_commands_with_overlays(commands, overlays)
}

///|
fn RenderNode::collect_uncached_draw_commands_with_overlays(
  self : RenderNode,
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
) -> Unit {
  for command in self.paint_commands {
    commands.push(command)
  }
  for child in self.children {
    child.collect_draw_commands_with_overlays(commands, overlays)
  }
  for command in self.post_paint_commands {
    commands.push(command)
  }
  for command in self.overlay_paint_commands {
    overlays.push(command)
  }
}

///|
fn RenderNode::collect_uncached_frame_commands_with_overlays(
  self : RenderNode,
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
  known_layers : Array[CachedLayerState],
  previous_admissions : Array[CachedLayerAdmissionState],
  next_known_layers : Array[CachedLayerState],
  next_admissions : Array[CachedLayerAdmissionState],
) -> Unit {
  for command in self.paint_commands {
    commands.push(command)
  }
  for child in self.children {
    child.collect_frame_commands_with_overlays(
      commands, overlays, known_layers, previous_admissions, next_known_layers, next_admissions,
    )
  }
  for command in self.post_paint_commands {
    commands.push(command)
  }
  for command in self.overlay_paint_commands {
    overlays.push(command)
  }
}

///|
fn RenderNode::with_repaint_boundary_cache(self : RenderNode) -> RenderNode {
  let commands : Array[DrawCommand] = []
  let overlays : Array[DrawCommand] = []
  self.collect_uncached_draw_commands_with_overlays(commands, overlays)
  {
    ..self,
    is_repaint_boundary: true,
    layer_cache_key: Some(self.repaint_boundary_cache_key()),
    cached_draw_commands: Some(commands),
    cached_overlay_draw_commands: Some(overlays),
  }
}

///|
fn RenderNode::cached_layer_spec(self : RenderNode) -> CachedLayerSpec? {
  match self.layer_cache_key {
    Some(key) =>
      Some(
        CachedLayerSpec::new(
          key~,
          frame=self.paint_bounds,
          content_revision=self.content_revision,
        ),
      )
    None => None
  }
}

///|
fn RenderNode::repaint_boundary_cache_key(self : RenderNode) -> String {
  "element=\{self.element_id.value()};x=\{self.frame.origin.x};y=\{self.frame.origin.y};w=\{self.frame.size.width};h=\{self.frame.size.height}"
}

///|
fn Array::has_current_cached_layer(
  self : Array[CachedLayerState],
  spec : CachedLayerSpec,
) -> Bool {
  self.any(layer => {
    layer.key == spec.key && layer.content_revision == spec.content_revision
  })
}

///|
fn Array::record_current_cached_layer(
  self : Array[CachedLayerState],
  spec : CachedLayerSpec,
) -> Unit {
  for index in 0..<self.length() {
    if self[index].key == spec.key {
      self[index] = { key: spec.key, content_revision: spec.content_revision }
      return
    }
  }
  self.push({ key: spec.key, content_revision: spec.content_revision })
}

///|
fn cached_layer_warmup_threshold() -> Int {
  3
}

///|
fn Array::cached_layer_visible_streak(
  self : Array[CachedLayerAdmissionState],
  spec : CachedLayerSpec,
) -> Int {
  for admission in self {
    if admission.key == spec.key &&
      admission.content_revision == spec.content_revision {
      return admission.visible_streak
    }
  }
  0
}

///|
fn Array::record_cached_layer_admission(
  self : Array[CachedLayerAdmissionState],
  spec : CachedLayerSpec,
  visible_streak : Int,
) -> Unit {
  for index in 0..<self.length() {
    if self[index].key == spec.key {
      self[index] = {
        key: spec.key,
        content_revision: spec.content_revision,
        visible_streak,
      }
      return
    }
  }
  self.push({
    key: spec.key,
    content_revision: spec.content_revision,
    visible_streak,
  })
}

///|
fn RenderNode::find_damage_bounds(self : RenderNode, id : ElementId) -> Rect? {
  self.find_damage_bounds_with_boundary(id, None)
}

///|
fn RenderNode::find_damage_bounds_with_boundary(
  self : RenderNode,
  id : ElementId,
  boundary : Rect?,
) -> Rect? {
  let active_boundary = if self.is_repaint_boundary {
    Some(self.paint_bounds)
  } else {
    boundary
  }
  if self.element_id == id {
    match active_boundary {
      Some(bounds) => Some(bounds)
      None => Some(self.paint_bounds)
    }
  } else {
    for child in self.children {
      match child.find_damage_bounds_with_boundary(id, active_boundary) {
        Some(bounds) => return Some(bounds)
        None => ()
      }
    }
    None
  }
}

///|
fn RenderNode::has_dirty_descendant(
  self : RenderNode,
  id : ElementId,
  dirty_ids : Array[ElementId],
) -> Bool {
  match self.find_render_node(id) {
    Some(node) => node.children.any(child => child.contains_any(dirty_ids))
    None => false
  }
}

///|
fn RenderNode::find_render_node(
  self : RenderNode,
  id : ElementId,
) -> RenderNode? {
  if self.element_id == id {
    Some(self)
  } else {
    for child in self.children {
      match child.find_render_node(id) {
        Some(node) => return Some(node)
        None => ()
      }
    }
    None
  }
}

///|
fn RenderNode::contains_any(self : RenderNode, ids : Array[ElementId]) -> Bool {
  if ids.any(id => id == self.element_id) {
    true
  } else {
    self.children.any(child => child.contains_any(ids))
  }
}

///|
fn ElementNode::render_focused_with_text_system(
  self : ElementNode,
  placed : PlacedNode,
  focused~ : ElementId?,
  environment? : Environment = Environment::neutral(),
  text_system~ : TextSystem,
  now_ms~ : Double,
) -> RenderNode {
  self.render_with_environment(
    placed,
    focused,
    RenderEnvironment::from_environment(environment)
    .with_text_system(text_system)
    .with_now_ms(now_ms),
  )
}
