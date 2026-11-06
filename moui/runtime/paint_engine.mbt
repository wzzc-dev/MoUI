///|
using @core {optional_rect_union}

///|
fn ElementNode::render_with_environment(
  self : ElementNode,
  placed : PlacedNode,
  focused : ElementId?,
  environment : RenderEnvironment,
  overlay_enter~ : Array[(ElementId, Double)] = [],
) -> RenderNode {
  let bounds = placed.frame
  // An in-flight enter fade changes the subtree's opacity every frame; the
  // render cache is keyed on frame/focused only, so a fading node must bypass
  // it (read and write) or the first faded frame is served forever.
  let enter_fading = overlay_enter_opacity(
      overlay_enter,
      self.id,
      environment.now_ms,
      overlay_fade_duration_ms(environment),
    )
    is Some(_)
  let focused_here = focused == Some(self.id)
  let cache_key : RenderCacheKey = {
    frame: bounds,
    focused: focused_here,
    environment_id: environment.environment_id,
    style: environment.style,
    font: environment.font,
    foreground: environment.foreground,
    corner_radius: environment.corner_radius,
    text_system_id: environment.text_system.id(),
    state_revision: self.control.state_revision,
    text_revision: self.control.text_revision,
    place_revision: self.layout_cache.place_revision,
  }
  let cache_key_matches = self.render_cache.cached_key == Some(cache_key)
  let cached_render_is_static = match self.render_cache.cached_render {
    Some(render) => !render.animating
    None => false
  }
  if !enter_fading &&
    cache_key_matches &&
    cached_render_is_static &&
    !self.has_dirty_paint() &&
    !self.has_dirty_layout() {
    match self.render_cache.cached_render {
      Some(render) => {
        self.render_cache.hit_count = self.render_cache.hit_count + 1
        return render
      }
      None => ()
    }
  }
  self.render_cache.miss_count = self.render_cache.miss_count + 1
  let children : Array[RenderNode] = []
  let commands : Array[DrawCommand] = []
  let post_commands : Array[DrawCommand] = []
  let overlay_commands : Array[DrawCommand] = []
  let cached_plan_is_static = match self.render_cache.cached_plan {
    Some(plan) => !plan.animating
    None => false
  }
  let plan = if !enter_fading &&
    cache_key_matches &&
    cached_plan_is_static &&
    !self.dirty.needs_paint {
    match self.render_cache.cached_plan {
      Some(plan) => plan
      None =>
        self.view_node.paint(
          self.paint_context(bounds, placed, focused_here, environment),
        )
    }
  } else {
    self.view_node.paint(
      self.paint_context(bounds, placed, focused_here, environment),
    )
  }
  commands.append(plan.commands)
  for layer in plan.child_layers {
    children.push(view_paint_layer_render_node(self.id, layer))
  }
  post_commands.append(plan.post_commands)
  overlay_commands.append(plan.overlay_commands)
  // Child hit regions come from the placed tree (frame ∩ accumulated clip);
  // hoisted overlay children escape ancestor clips entirely, so no paint-time
  // clip trimming is needed here.
  let child_environment_value = self.view_node.child_environment(
    environment.environment,
  )
  let child_environment_id = self.child_environment_identity(
    child_environment_value,
    environment.environment,
    environment.environment_id,
  )
  let child_environment = environment.with_child_context(
    child_environment_value,
    self.view_node.child_style(environment.style),
    child_environment_id,
  )
  for index, child in self.children {
    if index < placed.children.length() {
      let rendered = child.render_with_environment(
        placed.children[index],
        focused,
        child_environment,
        overlay_enter~,
      )
      let rendered = {
        ..rendered,
        is_overlay_child: placed.overlay_child_indices.contains(index),
      }
      children.push(rendered)
    }
  }
  self.dirty.needs_paint = false
  self.refresh_descendant_dirty_flags()
  self.render_cache.content_revision = self.render_cache.content_revision + 1
  let paint_bounds = render_node_paint_bounds(
    Rect::new(x=0.0, y=0.0, width=bounds.size.width, height=bounds.size.height),
    placed.child_transform,
    commands,
    children,
    post_commands,
    overlay_commands,
  )
  // A subtree is animating if this node's own paint reported a mid-animation
  // sample or any rendered child did. Folded up so the runtime only needs to
  // check the root to keep redraws ticking.
  let child_animating = children.iter().any(child => child.animating)
  let animating = plan.animating || child_animating || enter_fading
  let render = {
    element_id: self.id,
    frame: bounds,
    child_transform: placed.child_transform,
    clips_children: placed.clips_children,
    children,
    is_overlay_child: false,
    is_paint_layer: false,
    paint_bounds,
    render_opacity: overlay_enter_opacity(
      overlay_enter,
      self.id,
      environment.now_ms,
      overlay_fade_duration_ms(environment),
    ),
    content_revision: self.render_cache.content_revision,
    is_repaint_boundary: false,
    layer_cache_key: None,
    paint_commands: commands,
    post_paint_commands: post_commands,
    overlay_paint_commands: overlay_commands,
    cached_draw_commands: None,
    cached_overlay_draw_commands: None,
    animating,
  }
  let render = if plan.repaint_boundary {
    if render.contains_overlay_subtree() {
      { ..render, is_repaint_boundary: true, }
    } else {
      render.with_repaint_boundary_cache()
    }
  } else {
    render
  }
  // A fading node must not persist into the cache: its opacity changes every
  // frame while its frame/key stays identical.
  if !enter_fading && !plan.animating {
    self.render_cache.cached_key = Some(cache_key)
    self.render_cache.cached_plan = Some(plan)
  } else {
    self.render_cache.cached_key = None
    self.render_cache.cached_plan = None
  }
  if !enter_fading && !animating {
    self.render_cache.cached_render = Some(render)
  } else {
    self.render_cache.cached_render = None
  }
  render
}

///|
fn ElementNode::paint_context(
  self : ElementNode,
  bounds : Rect,
  placed : PlacedNode,
  focused_here : Bool,
  environment : RenderEnvironment,
) -> @core.ViewPaintContext {
  let local_frame = Rect::new(
    x=0.0,
    y=0.0,
    width=bounds.size.width,
    height=bounds.size.height,
  )
  let child_frames : Array[Rect] = []
  for index, child in placed.children {
    let frame = if placed.overlay_child_indices.contains(index) {
      child.frame
    } else {
      runtime_transform_rect(placed.child_transform, child.frame)
    }
    child_frames.push(frame)
  }
  {
    frame: local_frame,
    child_frames,
    focused: focused_here,
    state: self.control.view_context(focused_here),
    text_control: self.control.text_context(),
    environment: render_environment_to_view_environment(environment),
    style: environment.style,
    text_system: environment.text_system,
    now_ms: environment.now_ms,
  }
}

///|
fn view_paint_layer_render_node(
  element_id : ElementId,
  layer : @core.ViewPaintLayer,
) -> RenderNode {
  let paint_bounds = render_node_paint_bounds(
    Rect::new(
      x=0.0,
      y=0.0,
      width=layer.frame.size.width,
      height=layer.frame.size.height,
    ),
    Transform2D::identity(),
    layer.commands,
    [],
    [],
    layer.overlay_commands,
  )
  {
    element_id,
    frame: layer.frame,
    child_transform: Transform2D::identity(),
    clips_children: false,
    children: [],
    is_overlay_child: false,
    is_paint_layer: true,
    paint_bounds,
    render_opacity: None,
    content_revision: layer.content_revision,
    is_repaint_boundary: true,
    // An empty cache key opts the layer out of the retained-layer cache: its
    // commands are painted fresh every frame (e.g. a viewport-culled block
    // whose raster would depend on scroll position). Everything else retains
    // under its key.
    layer_cache_key: if layer.cache_key == "" {
      None
    } else {
      Some(layer.cache_key)
    },
    paint_commands: layer.commands,
    post_paint_commands: [],
    overlay_paint_commands: layer.overlay_commands,
    cached_draw_commands: Some(layer.commands),
    cached_overlay_draw_commands: Some(layer.overlay_commands),
    animating: false,
  }
}

///|
fn render_node_paint_bounds(
  frame : Rect,
  child_transform : Transform2D,
  commands : Array[DrawCommand],
  children : Array[RenderNode],
  post_commands : Array[DrawCommand],
  overlay_commands : Array[DrawCommand],
) -> Rect {
  let mut bounds : Rect? = Some(frame)
  for command in commands {
    bounds = optional_rect_union(bounds, command.bounds())
  }
  for child in children {
    if child.is_paint_layer {
      bounds = optional_rect_union(bounds, Some(child.paint_bounds))
    } else if !child.is_overlay_child {
      let child_space = runtime_transform_compose(
        child_transform,
        Transform2D::translation(
          dx=child.frame.origin.x,
          dy=child.frame.origin.y,
        ),
      )
      bounds = optional_rect_union(
        bounds,
        Some(runtime_transform_rect(child_space, child.paint_bounds)),
      )
    }
  }
  for command in post_commands {
    bounds = optional_rect_union(bounds, command.bounds())
  }
  for command in overlay_commands {
    bounds = optional_rect_union(bounds, command.bounds())
  }
  match bounds {
    Some(rect) => rect
    None => frame
  }
}

///|
/// Overlay enter/exit fade duration resolved from the paint environment:
/// reduced-motion completes immediately, otherwise the resolved theme's
/// normal motion tier (same source as `RuntimeState::overlay_transition_duration_ms`).
fn overlay_fade_duration_ms(environment : RenderEnvironment) -> Double {
  if environment.reduced_motion {
    return 0.0
  }
  environment.environment.theme.motion.normal_ms
}

///|
/// Enter-fade opacity for an overlay surface: 1.0 once the fade completed (or
/// when the surface is not tracked). A zero duration (reduced motion) always
/// takes the terminal branch.
fn overlay_enter_opacity(
  overlay_enter : Array[(ElementId, Double)],
  element_id : ElementId,
  now_ms : Double,
  duration_ms : Double,
) -> Double? {
  let mut started_ms : Double? = None
  for entry in overlay_enter {
    if entry.0 == element_id {
      started_ms = Some(entry.1)
    }
  }
  match started_ms {
    Some(started) => {
      let elapsed = now_ms - started
      if elapsed >= duration_ms {
        None
      } else {
        Some((elapsed / duration_ms).clamp(min=0.0, max=1.0))
      }
    }
    None => None
  }
}
