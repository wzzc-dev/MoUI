///|
fn RenderNode::collect_draw_commands(
  self : RenderNode,
  commands : Array[DrawCommand],
) -> Unit {
  let overlays : Array[DrawCommand] = []
  let deferred : Array[RenderNode] = []
  self.collect_draw_commands_with_overlays(commands, overlays, deferred)
  RenderNode::drain_deferred_draw(deferred, commands, overlays)
  for command in overlays {
    commands.push(command)
  }
}

///|
fn RenderNode::drain_deferred_draw(
  deferred : Array[RenderNode],
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
) -> Unit {
  let mut head = 0
  while head < deferred.length() {
    deferred[head].collect_draw_commands_with_overlays(
      commands, overlays, deferred,
    )
    head = head + 1
  }
}

///|
fn RenderNode::drain_deferred_frame(
  deferred : Array[RenderNode],
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
) -> Unit {
  let mut head = 0
  while head < deferred.length() {
    deferred[head].collect_frame_commands_with_overlays(
      commands, overlays, deferred,
    )
    head = head + 1
  }
}

///|
/// Return the union of view-level overlay paint bounds. Native platform views
/// may use this to expose the already-rendered overlay pixels above their own
/// surface without introducing a second renderer.
fn RenderNode::overlay_bounds(self : RenderNode) -> @core.Rect? {
  let mut bounds : @core.Rect? = None
  for command in self.overlay_paint_commands {
    bounds = @core.optional_rect_union(bounds, command.bounds())
  }
  for child in self.children {
    bounds = @core.optional_rect_union(bounds, child.overlay_bounds())
  }
  bounds
}

///|
fn RenderNode::collect_frame_commands(
  self : RenderNode,
  commands : Array[DrawCommand],
) -> Unit {
  let overlays : Array[DrawCommand] = []
  let deferred : Array[RenderNode] = []
  self.collect_frame_commands_with_overlays(commands, overlays, deferred)
  RenderNode::drain_deferred_frame(deferred, commands, overlays)
  for command in overlays {
    commands.push(command)
  }
}

///|
fn RenderNode::collect_frame_commands_with_overlays(
  self : RenderNode,
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
  deferred : Array[RenderNode],
) -> Unit {
  let fade = match self.render_opacity {
    Some(opacity) => opacity < 1.0
    None => false
  }
  if fade {
    commands.push(
      DrawCommand::PushOpacity(
        match self.render_opacity {
          Some(opacity) => opacity
          None => 1.0
        },
      ),
    )
  }
  if self.is_repaint_boundary {
    match self.cached_layer_spec() {
      Some(spec) => {
        commands.push(BeginRetainedLayer(spec))
        self.collect_uncached_frame_commands_with_overlays(
          commands, overlays, deferred,
        )
        commands.push(EndRetainedLayer(spec.key))
      }
      None =>
        self.collect_uncached_frame_commands_with_overlays(
          commands, overlays, deferred,
        )
    }
  } else {
    self.collect_uncached_frame_commands_with_overlays(
      commands, overlays, deferred,
    )
  }
}

///|
fn RenderNode::collect_draw_commands_with_overlays(
  self : RenderNode,
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
  deferred : Array[RenderNode],
) -> Unit {
  let fade = match self.render_opacity {
    Some(opacity) => opacity < 1.0
    None => false
  }
  if fade {
    commands.push(
      DrawCommand::PushOpacity(
        match self.render_opacity {
          Some(opacity) => opacity
          None => 1.0
        },
      ),
    )
  }
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
  for command in self.paint_commands {
    commands.push(command)
  }
  for child in self.children {
    if child.is_overlay_child {
      deferred.push(child)
    } else {
      child.collect_draw_commands_with_overlays(commands, overlays, deferred)
    }
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
  deferred : Array[RenderNode],
) -> Unit {
  for command in self.paint_commands {
    commands.push(command)
  }
  for child in self.children {
    if child.is_overlay_child {
      deferred.push(child)
    } else {
      child.collect_frame_commands_with_overlays(commands, overlays, deferred)
    }
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
  // Cache building inlines hoisted overlay children so the retained layer is
  // self-contained; only the root traversal defers them.
  let deferred : Array[RenderNode] = []
  self.collect_draw_commands_with_overlays(commands, overlays, deferred)
  RenderNode::drain_deferred_draw(deferred, commands, overlays)
  {
    ..self,
    is_repaint_boundary: true,
    layer_cache_key: Some(self.repaint_boundary_cache_key()),
    cached_draw_commands: Some(commands),
    cached_overlay_draw_commands: Some(overlays),
  }
}

///|
fn RenderNode::cached_layer_spec(self : RenderNode) -> RetainedLayerSpec? {
  match self.layer_cache_key {
    Some(key) =>
      Some(
        RetainedLayerSpec::new(
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
/// True when any hoisted overlay subtree under this node (including hoisted
/// children of descendants) covers `point`. Pointer dispatch and focus pickup
/// use this as a global prepass so a popup anywhere in the tree wins over
/// in-flow content painted underneath it.
fn RenderNode::subtree_overlay_contains(
  self : RenderNode,
  point : Point,
) -> Bool {
  for child in self.children {
    if child.is_overlay_child && child.hit_bounds().contains(point) {
      return true
    }
    if child.subtree_overlay_contains(point) {
      return true
    }
  }
  false
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
  overlay_enter? : Array[(ElementId, Double)] = [],
) -> RenderNode {
  self.render_with_environment(
    placed,
    focused,
    RenderEnvironment::from_environment(environment)
    .with_text_system(text_system)
    .with_now_ms(now_ms),
    overlay_enter~,
  )
}
