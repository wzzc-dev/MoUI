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
  let plan = if environment.matches_default_cache_key() &&
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
  // A scroll/clip container wraps its children in a pushed clip rect (see
  // `ScrollContainerView::paint` and `ClipModifier`). The clip only constrains
  // drawn pixels, not `RenderNode::paint_bounds`, so a long column inside a
  // short scroll viewport reports a `paint_bounds` that spills over earlier
  // siblings — the showcase sidebar search field becomes un-clickable after
  // the story list scrolls, because the list's `paint_bounds` grows up over
  // the field and wins hit-test. Detect a leading `PushClip`/`PushRoundedClip`
  // in this node's own commands and clip each child's `paint_bounds` to that
  // rect before union. Picker/date-picker popups paint through
  // `overlay_commands` (not children) and stay unaffected.
  let child_clip : @core.Rect? = paint_plan_child_clip(plan.commands)
  let child_environment = environment.with_child_context(self.view_node)
  for index, child in self.children {
    if index < placed.children.length() {
      let rendered = child.render_with_environment(
        placed.children[index],
        focused,
        child_environment,
      )
      match child_clip {
        Some(clip) =>
          match clip.intersection(rendered.paint_bounds) {
            Some(clipped) =>
              children.push({ ..rendered, paint_bounds: clipped })
            None => children.push({ ..rendered, paint_bounds: clip })
          }
        None => children.push(rendered)
      }
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
    paint_bounds,
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
/// Returns the rect this node's own commands clip children into, if any.
///
/// A leading `PushClip(Rect)` or `PushRoundedClip(RoundedRect)` (as emitted by
/// `ScrollContainerView::paint` and the `ClipModifier` view) wraps the node's
/// children in a clip. The clip constrains drawn pixels but not
/// `RenderNode::paint_bounds`, so without this hint a long column inside a
/// short scroll viewport reports a `paint_bounds` that spills over earlier
/// siblings — the showcase sidebar search field becomes un-clickable after
/// the story list scrolls, because the list's `paint_bounds` grows up over
/// the field and wins hit-test.
///
/// Only the first clip command is consulted: that is the one `ScrollContainer`
/// and `ClipModifier` emit before any children, and matches the painting order
/// (children paint between the push and its matching pop). Picker and
/// date-picker popups paint through `overlay_commands` rather than children,
/// so they remain unaffected by this clip.
fn paint_plan_child_clip(commands : Array[@core.DrawCommand]) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::PushClip(rect) => return Some(rect)
      @core.DrawCommand::PushRoundedClip(rounded) => return Some(rounded.rect)
      _ => ()
    }
  }
  None
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
