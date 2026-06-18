///|
using @core {optional_rect_union}

///|
fn ElementNode::render_with_environment(
  self : ElementNode,
  placed : PlacedNode,
  focused : ElementId?,
  environment : RenderEnvironment,
) -> RenderNode {
  let bounds = placed.frame
  if environment.matches_default_cache_key() &&
    !self.has_dirty_paint() &&
    !self.has_dirty_layout() &&
    self.render_cache.cached_render_frame == Some(bounds) &&
    self.render_cache.cached_render_focused == focused {
    match self.render_cache.cached_render {
      Some(render) => return render
      None => ()
    }
  }
  let children : Array[RenderNode] = []
  let commands : Array[DrawCommand] = []
  let post_commands : Array[DrawCommand] = []
  let overlay_commands : Array[DrawCommand] = []
  let platform_views : Array[PlatformViewPlacement] = []
  let plan = (self.erased_view_node.paint)({
    frame: bounds,
    child_frames: placed.children.map(child => child.frame),
    focused: focused == Some(self.id),
    state: { ..self.erased_view_node.state, focused: focused == Some(self.id) },
    text_control: self.control.text_context(),
    environment: render_environment_to_view_environment(environment),
    text_system: environment.text_system,
    now_ms: environment.now_ms,
  })
  commands.append(plan.commands)
  for layer in plan.child_layers {
    children.push(view_paint_layer_render_node(self.id, layer))
  }
  post_commands.append(plan.post_commands)
  overlay_commands.append(plan.overlay_commands)
  platform_views.append(plan.platform_views)
  for index, child in self.children {
    if index < placed.children.length() {
      children.push(
        child.render_with_environment(
          placed.children[index],
          focused,
          environment,
        ),
      )
    }
  }
  self.dirty.clear()
  self.render_cache.content_revision = self.render_cache.content_revision + 1
  let paint_bounds = render_node_paint_bounds(
    bounds, commands, children, post_commands, overlay_commands,
  )
  // A subtree is animating if this node's own paint reported a mid-animation
  // sample or any rendered child did. Folded up so the runtime only needs to
  // check the root to keep redraws ticking.
  let child_animating = children.iter().any(child => child.animating)
  let animating = plan.animating || child_animating
  let render = {
    element_id: self.id,
    frame: bounds,
    children,
    paint_bounds,
    content_revision: self.render_cache.content_revision,
    is_repaint_boundary: false,
    layer_cache_key: None,
    paint_commands: commands,
    post_paint_commands: post_commands,
    overlay_paint_commands: overlay_commands,
    platform_views,
    cached_draw_commands: None,
    cached_overlay_draw_commands: None,
    animating,
  }
  let render = if plan.repaint_boundary {
    render.with_repaint_boundary_cache()
  } else {
    render
  }
  if environment.matches_default_cache_key() {
    self.render_cache.cached_render_frame = Some(bounds)
    self.render_cache.cached_render_focused = focused
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
    paint_bounds,
    content_revision: layer.content_revision,
    is_repaint_boundary: true,
    layer_cache_key: Some(layer.cache_key),
    paint_commands: layer.commands,
    post_paint_commands: [],
    overlay_paint_commands: layer.overlay_commands,
    platform_views: layer.platform_views,
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
