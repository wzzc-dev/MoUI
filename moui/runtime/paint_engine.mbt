///|
using @core {optional_rect_union}

///|
fn ElementNode::render_with_environment(
  self : ElementNode,
  placed : PlacedNode,
  focused : ElementId?,
  environment : RenderEnvironment,
  overlay_enter? : Array[(ElementId, Double)] = [],
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
  if environment.matches_default_cache_key() &&
    !enter_fading &&
    !self.has_dirty_paint() &&
    !self.has_dirty_layout() &&
    self.render_cache.cached_render_frame == Some(bounds) &&
    self.render_cache.cached_render_focused == focused {
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
  let plan = if !enter_fading &&
    environment.matches_default_cache_key() &&
    !self.dirty.needs_paint &&
    self.render_cache.cached_render_frame == Some(bounds) &&
    self.render_cache.cached_render_focused == focused {
    match self.render_cache.cached_plan {
      Some(plan) => plan
      None =>
        self.view_node.paint({
          frame: bounds,
          child_frames: placed.children.map(child => child.frame),
          focused: focused == Some(self.id),
          state: self.control.view_context(focused == Some(self.id)),
          text_control: self.control.text_context(),
          environment: render_environment_to_view_environment(environment),
          style: environment.style,
          text_system: environment.text_system,
          now_ms: environment.now_ms,
        })
    }
  } else {
    self.view_node.paint({
      frame: bounds,
      child_frames: placed.children.map(child => child.frame),
      focused: focused == Some(self.id),
      state: self.control.view_context(focused == Some(self.id)),
      text_control: self.control.text_context(),
      environment: render_environment_to_view_environment(environment),
      style: environment.style,
      text_system: environment.text_system,
      now_ms: environment.now_ms,
    })
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
  let child_environment = environment.with_child_context(self.view_node)
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
    bounds, commands, children, post_commands, overlay_commands,
  )
  // A subtree is animating if this node's own paint reported a mid-animation
  // sample or any rendered child did. Folded up so the runtime only needs to
  // check the root to keep redraws ticking.
  let child_animating = children.iter().any(child => child.animating)
  let animating = plan.animating || child_animating || enter_fading
  let render = {
    element_id: self.id,
    frame: bounds,
    children,
    is_overlay_child: false,
    paint_bounds,
    hit_rect: Some(placed.hit_rect),
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
    render.with_repaint_boundary_cache()
  } else {
    render
  }
  // A fading node must not persist into the cache: its opacity changes every
  // frame while its frame/key stays identical.
  if environment.matches_default_cache_key() && !enter_fading {
    self.render_cache.cached_render_frame = Some(bounds)
    self.render_cache.cached_render_focused = focused
    self.render_cache.cached_plan = Some(plan)
    self.render_cache.cached_render = Some(render)
  }
  render
}

///|
fn view_paint_layer_render_node(
  element_id : ElementId,
  layer : @core.ViewPaintLayer,
) -> RenderNode {
  let paint_bounds = render_node_paint_bounds(
    layer.frame,
    layer.commands,
    [],
    [],
    layer.overlay_commands,
  )
  {
    element_id,
    frame: layer.frame,
    children: [],
    is_overlay_child: false,
    paint_bounds,
    hit_rect: None,
    render_opacity: None,
    content_revision: layer.content_revision,
    is_repaint_boundary: true,
    layer_cache_key: Some(layer.cache_key),
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
    bounds = optional_rect_union(bounds, Some(child.paint_bounds))
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
