///|
/// Legacy command-only consumers historically received one flat stream with
/// layout placement already folded into command geometry. Keep that contract
/// separate from `DrawFrame`: renderers need the node-local commands and their
/// transform scopes, while tests, preview code, and command-only adapters
/// observe screen-space geometry.
///
/// Only layout translations are folded here. Paint-level transforms remain
/// explicit commands, exactly as they did before content-local scrolling.
fn RenderNode::collect_legacy_draw_commands(
  self : RenderNode,
  commands : Array[DrawCommand],
) -> Unit {
  self.collect_legacy_draw_commands_at(Point::new(x=0.0, y=0.0), commands)
}

///|
fn RenderNode::collect_legacy_draw_commands_at(
  self : RenderNode,
  origin : Point,
  commands : Array[DrawCommand],
) -> Unit {
  let overlays : Array[DrawCommand] = []
  let deferred : Array[RenderNode] = []
  self.collect_legacy_draw_commands_with_overlays(
    origin, commands, overlays, deferred,
  )
  RenderNode::drain_deferred_legacy(deferred, commands, overlays)
  for command in overlays {
    commands.push(command)
  }
}

///|
fn RenderNode::drain_deferred_legacy(
  deferred : Array[RenderNode],
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
) -> Unit {
  let mut head = 0
  while head < deferred.length() {
    let node = deferred[head]
    node.collect_legacy_draw_commands_with_overlays(
      node.frame.origin,
      commands,
      overlays,
      deferred,
    )
    head = head + 1
  }
}

///|
fn RenderNode::collect_legacy_draw_commands_with_overlays(
  self : RenderNode,
  offset : Point,
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
      PushOpacity(
        match self.render_opacity {
          Some(opacity) => opacity
          None => 1.0
        },
      ),
    )
  }
  RenderNode::append_translated_commands(commands, self.paint_commands, offset)
  for child in self.children {
    if child.is_overlay_child {
      deferred.push(child)
    } else if child.is_paint_layer {
      child.collect_legacy_draw_commands_with_overlays(
        offset, commands, overlays, deferred,
      )
    } else {
      let transformed_origin = runtime_transform_point(
        self.child_transform,
        child.frame.origin,
      )
      let child_offset = Point::new(
        x=offset.x + transformed_origin.x,
        y=offset.y + transformed_origin.y,
      )
      child.collect_legacy_draw_commands_with_overlays(
        child_offset, commands, overlays, deferred,
      )
    }
  }
  RenderNode::append_translated_commands(
    commands,
    self.post_paint_commands,
    offset,
  )
  RenderNode::append_translated_commands(
    overlays,
    self.overlay_paint_commands,
    offset,
  )
}

///|
fn RenderNode::append_translated_commands(
  output : Array[DrawCommand],
  source : Array[DrawCommand],
  offset : Point,
) -> Unit {
  if offset.x == 0.0 && offset.y == 0.0 {
    output.append(source)
  } else {
    for command in source {
      output.push(translate_draw_command(command, offset))
    }
  }
}

///|
fn translate_draw_command(command : DrawCommand, offset : Point) -> DrawCommand {
  match command {
    Clear(color) => Clear(color)
    FillRect(rect, color) => FillRect(translate_rect(rect, offset), color)
    StrokeRect(rect, color, width) =>
      StrokeRect(translate_rect(rect, offset), color, width)
    FillRoundedRect(rounded, color) =>
      FillRoundedRect(translate_rounded(rounded, offset), color)
    StrokeRoundedRect(rounded, color, width) =>
      StrokeRoundedRect(translate_rounded(rounded, offset), color, width)
    FillRoundedRectBrush(rounded, brush) =>
      FillRoundedRectBrush(
        translate_rounded(rounded, offset),
        translate_brush(brush, offset),
      )
    StrokeRoundedRectBrush(rounded, brush, width) =>
      StrokeRoundedRectBrush(
        translate_rounded(rounded, offset),
        translate_brush(brush, offset),
        width,
      )
    DrawShadow(shadow) =>
      DrawShadow({ ..shadow, rect: translate_rounded(shadow.rect, offset), })
    DrawText(run) =>
      DrawText({ ..run, frame: translate_rect(run.frame, offset), })
    DrawImage(run) =>
      DrawImage({ ..run, frame: translate_rect(run.frame, offset), })
    PushClip(rect) => PushClip(translate_rect(rect, offset))
    PopClip => PopClip
    PushRoundedClip(rounded) =>
      PushRoundedClip(translate_rounded(rounded, offset))
    PopRoundedClip => PopRoundedClip
    PushTransform(transform) => PushTransform(transform)
    PopTransform => PopTransform
    PushOpacity(opacity) => PushOpacity(opacity)
    PopOpacity => PopOpacity
    PushLayer(layer) =>
      PushLayer({ ..layer, mask: translate_layer_mask(layer.mask, offset), })
    PopLayer => PopLayer
    BeginRetainedLayer(spec) =>
      BeginRetainedLayer({ ..spec, frame: translate_rect(spec.frame, offset), })
    EndRetainedLayer(key) => EndRetainedLayer(key)
    PushFilter(effect) => PushFilter(effect)
    PopFilter => PopFilter
    DrawPath(path) => DrawPath(translate_path(path, offset))
    DrawShaderEffect(spec) =>
      DrawShaderEffect({ ..spec, frame: translate_rect(spec.frame, offset), })
  }
}

///|
fn translate_rect(rect : Rect, offset : Point) -> Rect {
  {
    ..rect,
    origin: Point::new(x=rect.origin.x + offset.x, y=rect.origin.y + offset.y),
  }
}

///|
fn translate_rounded(
  rounded : @core.RoundedRect,
  offset : Point,
) -> @core.RoundedRect {
  { ..rounded, rect: translate_rect(rounded.rect, offset), }
}

///|
fn translate_brush(brush : @core.Brush, offset : Point) -> @core.Brush {
  match brush {
    Solid(color) => Solid(color)
    LinearGradient(gradient) =>
      LinearGradient({
        ..gradient,
        start: translate_point(gradient.start, offset),
        end: translate_point(gradient.end, offset),
      })
    RadialGradient(gradient) =>
      RadialGradient({
        ..gradient,
        center: translate_point(gradient.center, offset),
      })
  }
}

///|
fn translate_layer_mask(
  mask : @core.LayerMask,
  offset : Point,
) -> @core.LayerMask {
  match mask {
    NoMask => NoMask
    RectMask(rect) => RectMask(translate_rect(rect, offset))
    RoundedMask(rounded) => RoundedMask(translate_rounded(rounded, offset))
  }
}

///|
fn translate_point(point : Point, offset : Point) -> Point {
  Point::new(x=point.x + offset.x, y=point.y + offset.y)
}

///|
fn translate_path(path : @core.PathSpec, offset : Point) -> @core.PathSpec {
  let verbs : Array[@core.PathVerb] = []
  for verb in path.verbs {
    verbs.push(
      match verb {
        MoveTo(point) => MoveTo(translate_point(point, offset))
        LineTo(point) => LineTo(translate_point(point, offset))
        QuadTo(control, point) =>
          QuadTo(
            translate_point(control, offset),
            translate_point(point, offset),
          )
        CubicTo(first, second, point) =>
          CubicTo(
            translate_point(first, offset),
            translate_point(second, offset),
            translate_point(point, offset),
          )
        Close => Close
      },
    )
  }
  { ..path, verbs, }
}

///|
fn RenderNode::drain_deferred_draw(
  deferred : Array[RenderNode],
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
) -> Unit {
  let mut head = 0
  while head < deferred.length() {
    let node = deferred[head]
    let screen_space = Transform2D::translation(
      dx=node.frame.origin.x,
      dy=node.frame.origin.y,
    )
    RenderNode::push_transform(commands, screen_space)
    deferred[head].collect_draw_commands_with_overlays(
      screen_space, commands, overlays, deferred,
    )
    RenderNode::pop_transform(commands, screen_space)
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
    let node = deferred[head]
    let screen_space = Transform2D::translation(
      dx=node.frame.origin.x,
      dy=node.frame.origin.y,
    )
    RenderNode::push_transform(commands, screen_space)
    deferred[head].collect_frame_commands_with_overlays(
      screen_space, commands, overlays, deferred,
    )
    RenderNode::pop_transform(commands, screen_space)
    head = head + 1
  }
}

///|
/// Return the union of view-level overlay paint bounds. Native platform views
/// may use this to expose the already-rendered overlay pixels above their own
/// surface without introducing a second renderer.
fn RenderNode::overlay_bounds(self : RenderNode) -> @core.Rect? {
  self.overlay_bounds_in_screen(Transform2D::identity())
}

///|
fn RenderNode::overlay_bounds_in_screen(
  self : RenderNode,
  node_to_screen : Transform2D,
) -> @core.Rect? {
  let mut bounds : @core.Rect? = None
  for command in self.overlay_paint_commands {
    match command.bounds() {
      Some(rect) =>
        bounds = @core.optional_rect_union(
          bounds,
          Some(runtime_transform_rect(node_to_screen, rect)),
        )
      None => ()
    }
  }
  let child_content_to_screen = runtime_transform_compose(
    node_to_screen,
    self.child_transform,
  )
  for child in self.children {
    let child_bounds = if child.is_paint_layer {
      child.overlay_bounds_in_screen(node_to_screen)
    } else if child.is_overlay_child {
      child.overlay_bounds_in_screen(
        Transform2D::translation(
          dx=child.frame.origin.x,
          dy=child.frame.origin.y,
        ),
      )
    } else {
      child.overlay_bounds_in_screen(
        runtime_transform_compose(
          child_content_to_screen,
          Transform2D::translation(
            dx=child.frame.origin.x,
            dy=child.frame.origin.y,
          ),
        ),
      )
    }
    bounds = @core.optional_rect_union(bounds, child_bounds)
  }
  bounds
}

///|
fn RenderNode::child_to_screen(
  self : RenderNode,
  node_to_screen : Transform2D,
  child : RenderNode,
) -> Transform2D {
  if child.is_paint_layer {
    node_to_screen
  } else if child.is_overlay_child {
    runtime_overlay_to_screen(child.frame)
  } else {
    runtime_child_to_screen(node_to_screen, self.child_transform, child.frame)
  }
}

///|
fn RenderNode::screen_frame(
  self : RenderNode,
  node_to_screen : Transform2D,
) -> Rect {
  runtime_screen_frame(node_to_screen, self.frame)
}

///|
fn RenderNode::screen_child_frames(
  self : RenderNode,
  node_to_screen : Transform2D,
) -> Array[Rect] {
  let frames : Array[Rect] = []
  for child in self.children {
    let child_to_screen = self.child_to_screen(node_to_screen, child)
    frames.push(runtime_screen_frame(child_to_screen, child.frame))
  }
  frames
}

///|
fn RenderNode::collect_frame_commands(
  self : RenderNode,
  commands : Array[DrawCommand],
) -> Unit {
  let overlays : Array[DrawCommand] = []
  let deferred : Array[RenderNode] = []
  self.collect_frame_commands_with_overlays(
    Transform2D::identity(),
    commands,
    overlays,
    deferred,
  )
  RenderNode::drain_deferred_frame(deferred, commands, overlays)
  for command in overlays {
    commands.push(command)
  }
}

///|
fn RenderNode::collect_frame_commands_with_overlays(
  self : RenderNode,
  node_to_screen : Transform2D,
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
      PushOpacity(
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
          node_to_screen, commands, overlays, deferred,
        )
        commands.push(EndRetainedLayer(spec.key))
      }
      None =>
        self.collect_uncached_frame_commands_with_overlays(
          node_to_screen, commands, overlays, deferred,
        )
    }
  } else {
    self.collect_uncached_frame_commands_with_overlays(
      node_to_screen, commands, overlays, deferred,
    )
  }
}

///|
fn RenderNode::collect_draw_commands_with_overlays(
  self : RenderNode,
  node_to_screen : Transform2D,
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
      PushOpacity(
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
          RenderNode::append_overlay_commands(
            overlays, cached_overlays, node_to_screen,
          )
        None => ()
      }
      return
    }
    None => ()
  }
  for command in self.paint_commands {
    commands.push(command)
  }
  let child_content_to_screen = runtime_transform_compose(
    node_to_screen,
    self.child_transform,
  )
  for child in self.children {
    if child.is_overlay_child {
      deferred.push(child)
    } else if child.is_paint_layer {
      child.collect_draw_commands_with_overlays(
        node_to_screen, commands, overlays, deferred,
      )
    } else {
      // Paint commands are content-local. Apply the node's content transform
      // and the child's frame together so a scroll tick does not need to
      // rewrite any descendant's draw commands.
      let child_space = runtime_transform_compose(
        self.child_transform,
        Transform2D::translation(
          dx=child.frame.origin.x,
          dy=child.frame.origin.y,
        ),
      )
      let child_to_screen = runtime_transform_compose(
        child_content_to_screen,
        Transform2D::translation(
          dx=child.frame.origin.x,
          dy=child.frame.origin.y,
        ),
      )
      RenderNode::push_transform(commands, child_space)
      child.collect_draw_commands_with_overlays(
        child_to_screen, commands, overlays, deferred,
      )
      RenderNode::pop_transform(commands, child_space)
    }
  }
  for command in self.post_paint_commands {
    commands.push(command)
  }
  RenderNode::append_overlay_commands(
    overlays,
    self.overlay_paint_commands,
    node_to_screen,
  )
}

///|
fn RenderNode::collect_uncached_frame_commands_with_overlays(
  self : RenderNode,
  node_to_screen : Transform2D,
  commands : Array[DrawCommand],
  overlays : Array[DrawCommand],
  deferred : Array[RenderNode],
) -> Unit {
  for command in self.paint_commands {
    commands.push(command)
  }
  let child_content_to_screen = runtime_transform_compose(
    node_to_screen,
    self.child_transform,
  )
  for child in self.children {
    if child.is_overlay_child {
      deferred.push(child)
    } else if child.is_paint_layer {
      child.collect_frame_commands_with_overlays(
        node_to_screen, commands, overlays, deferred,
      )
    } else {
      let child_space = runtime_transform_compose(
        self.child_transform,
        Transform2D::translation(
          dx=child.frame.origin.x,
          dy=child.frame.origin.y,
        ),
      )
      let child_to_screen = runtime_transform_compose(
        child_content_to_screen,
        Transform2D::translation(
          dx=child.frame.origin.x,
          dy=child.frame.origin.y,
        ),
      )
      RenderNode::push_transform(commands, child_space)
      child.collect_frame_commands_with_overlays(
        child_to_screen, commands, overlays, deferred,
      )
      RenderNode::pop_transform(commands, child_space)
    }
  }
  for command in self.post_paint_commands {
    commands.push(command)
  }
  RenderNode::append_overlay_commands(
    overlays,
    self.overlay_paint_commands,
    node_to_screen,
  )
}

///|
fn RenderNode::push_transform(
  commands : Array[DrawCommand],
  transform : Transform2D,
) -> Unit {
  if !runtime_transform_is_identity(transform) {
    commands.push(PushTransform(transform))
  }
}

///|
fn RenderNode::pop_transform(
  commands : Array[DrawCommand],
  transform : Transform2D,
) -> Unit {
  if !runtime_transform_is_identity(transform) {
    commands.push(PopTransform)
  }
}

///|
fn RenderNode::append_overlay_commands(
  overlays : Array[DrawCommand],
  source : Array[DrawCommand],
  node_to_screen : Transform2D,
) -> Unit {
  let transformed = !runtime_transform_is_identity(node_to_screen)
  if transformed {
    overlays.push(PushTransform(node_to_screen))
  }
  for command in source {
    overlays.push(command)
  }
  if transformed {
    overlays.push(PopTransform)
  }
}

///|
fn RenderNode::with_repaint_boundary_cache(self : RenderNode) -> RenderNode {
  let commands : Array[DrawCommand] = []
  let overlays : Array[DrawCommand] = []
  // Cache building inlines hoisted overlay children so the retained layer is
  // self-contained; only the root traversal defers them.
  let deferred : Array[RenderNode] = []
  self.collect_draw_commands_with_overlays(
    Transform2D::identity(),
    commands,
    overlays,
    deferred,
  )
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
/// A retained command cache is replayed under its owner's accumulated
/// transform. Hoisted overlay children deliberately escape that transform, so
/// a subtree containing one cannot be cached as a self-contained command list.
fn RenderNode::contains_overlay_subtree(self : RenderNode) -> Bool {
  for child in self.children {
    if child.is_overlay_child || child.contains_overlay_subtree() {
      return true
    }
  }
  false
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
fn RenderNode::subtree_overlay_contains_in_screen(
  self : RenderNode,
  point : Point,
  node_to_screen : Transform2D,
) -> Bool {
  for child in self.children {
    let child_to_screen = if child.is_paint_layer {
      node_to_screen
    } else if child.is_overlay_child {
      runtime_overlay_to_screen(child.frame)
    } else {
      runtime_child_to_screen(node_to_screen, self.child_transform, child.frame)
    }
    if child.is_overlay_child &&
      runtime_screen_frame(child_to_screen, child.frame).contains(point) {
      return true
    }
    if child.subtree_overlay_contains_in_screen(point, child_to_screen) {
      return true
    }
  }
  false
}

///|
/// One-pass per-tree index for damage computation. Built once per frame per
/// previous/current tree in `compute_damage_region`, replacing the previous
/// up-to-two full DFS traversals per dirty id with O(1) lookups and O(depth)
/// parent-chain walks.
priv struct DamageIndexEntry {
  paint_bounds : Rect
  parent_id : Int32?
  is_repaint_boundary : Bool
}

///|
priv struct DamageIndex {
  entries : Map[Int32, DamageIndexEntry]
}

///|
fn DamageIndex::build(root : RenderNode) -> DamageIndex {
  let entries : Map[Int32, DamageIndexEntry] = Map([])
  DamageIndex::build_node(root, None, Transform2D::identity(), entries)
  { entries, }
}

///|
fn DamageIndex::build_node(
  node : RenderNode,
  parent_id : Int32?,
  node_to_screen : Transform2D,
  entries : Map[Int32, DamageIndexEntry],
) -> Unit {
  let child_content_to_screen = runtime_transform_compose(
    node_to_screen,
    node.child_transform,
  )
  for child in node.children {
    let world = if child.is_paint_layer {
      node_to_screen
    } else if child.is_overlay_child {
      Transform2D::translation(dx=child.frame.origin.x, dy=child.frame.origin.y)
    } else {
      runtime_transform_compose(
        child_content_to_screen,
        Transform2D::translation(
          dx=child.frame.origin.x,
          dy=child.frame.origin.y,
        ),
      )
    }
    DamageIndex::build_node(
      child,
      Some(node.element_id.value()),
      world,
      entries,
    )
  }
  entries[node.element_id.value()] = {
    paint_bounds: runtime_transform_rect(node_to_screen, node.paint_bounds),
    parent_id,
    is_repaint_boundary: node.is_repaint_boundary,
  }
}

///|
/// Nearest self-or-ancestor repaint-boundary `paint_bounds`, falling back to
/// the node's own bounds — same contract as the removed `find_damage_bounds`.
fn DamageIndex::damage_bounds(self : DamageIndex, id : ElementId) -> Rect? {
  match self.entries.get(id.value()) {
    Some(entry) => {
      if entry.is_repaint_boundary {
        return Some(entry.paint_bounds)
      }
      let mut cursor = entry.parent_id
      while cursor is Some(pid) {
        match self.entries.get(pid) {
          Some(parent) => {
            if parent.is_repaint_boundary {
              return Some(parent.paint_bounds)
            }
            cursor = parent.parent_id
          }
          // Unreachable while every entry except the root has a parent in
          // the map; fall back to the node's own bounds like the old DFS.
          None => return Some(entry.paint_bounds)
        }
      }
      Some(entry.paint_bounds)
    }
    None => None
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
fn ElementNode::render_focused_with_text_system(
  self : ElementNode,
  placed : PlacedNode,
  focused~ : ElementId?,
  environment~ : Environment = Environment::neutral(),
  text_system~ : TextSystem,
  now_ms~ : Double,
  overlay_enter~ : Array[(ElementId, Double)] = [],
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
