///|
/// Portable render command recorded before a concrete backend turns it into
/// native Canvas calls.
#warnings("-deprecated_syntax")
pub(all) enum RenderCommand {
  SaveCanvas
  RestoreCanvas
  ClearCanvas(Color)
  ClipCanvasRect(Rect, ClipOp)
  DrawCanvasRect(Rect, Paint)
  DrawCanvasPath(Path, Paint)
  DrawCanvasTextUtf8(Bytes, Point, Paint)
  DrawCanvasTextRunUtf8(
    Bytes,
    TextRunDescriptor,
    RendererResourceKey,
    Point,
    Paint
  )
  DeclareRenderResource(RendererResourceDescriptor)
  PresentSurface
} derive(Debug, Eq)

///|
pub fn RenderCommand::clear(color : Color) -> RenderCommand {
  ClearCanvas(color)
}

///|
pub fn RenderCommand::clip_rect(
  rect : Rect,
  op? : ClipOp = Intersect,
) -> RenderCommand {
  ClipCanvasRect(rect.sorted(), op)
}

///|
pub fn RenderCommand::draw_rect(
  rect : Rect,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasRect(rect.sorted(), paint)
}

///|
pub fn RenderCommand::draw_path(
  path : Path,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasPath(path, paint)
}

///|
pub fn RenderCommand::draw_text_utf8(
  text : Bytes,
  origin : Point,
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  DrawCanvasTextUtf8(text, origin, paint)
}

///|
fn default_render_text_run_descriptor(text : Bytes) -> TextRunDescriptor {
  TextRunDescriptor::new(range=TextRange::new(0, text.length()))
}

///|
pub fn RenderCommand::draw_text_run_utf8(
  text : Bytes,
  origin : Point,
  descriptor? : TextRunDescriptor? = None,
  font_key? : RendererResourceKey = RendererResourceKey::font(b""),
  paint? : Paint = Paint::new(),
) -> RenderCommand {
  let descriptor = match descriptor {
    None => default_render_text_run_descriptor(text)
    Some(descriptor) => descriptor
  }
  DrawCanvasTextRunUtf8(text, descriptor, font_key, origin, paint)
}

///|
pub fn RenderCommand::declare_resource(
  descriptor : RendererResourceDescriptor,
) -> RenderCommand {
  DeclareRenderResource(descriptor)
}

///|
pub fn RenderCommand::is_draw(self : RenderCommand) -> Bool {
  self
  is (DrawCanvasRect(_, _)
  | DrawCanvasPath(_, _)
  | DrawCanvasTextUtf8(_, _, _)
  | DrawCanvasTextRunUtf8(_, _, _, _, _))
}

///|
pub fn RenderCommand::is_state(self : RenderCommand) -> Bool {
  self is (SaveCanvas | RestoreCanvas)
}

///|
pub fn RenderCommand::is_clip(self : RenderCommand) -> Bool {
  self is ClipCanvasRect(_, _)
}

///|
pub fn RenderCommand::is_clear(self : RenderCommand) -> Bool {
  self is ClearCanvas(_)
}

///|
pub fn RenderCommand::is_present(self : RenderCommand) -> Bool {
  self is PresentSurface
}

///|
pub fn RenderCommand::is_text(self : RenderCommand) -> Bool {
  self is (DrawCanvasTextUtf8(_, _, _) | DrawCanvasTextRunUtf8(_, _, _, _, _))
}

///|
pub fn RenderCommand::is_resource_declaration(self : RenderCommand) -> Bool {
  self is DeclareRenderResource(_)
}

///|
pub fn RenderCommand::text_run_resource_key(
  self : RenderCommand,
) -> RendererResourceKey? {
  match self {
    DrawCanvasTextRunUtf8(text, descriptor, font_key, _, _) =>
      Some(descriptor.resource_key(text, font_key~))
    _ => None
  }
}

///|
pub fn RenderCommand::resource_descriptor(
  self : RenderCommand,
) -> RendererResourceDescriptor? {
  match self {
    DrawCanvasPath(path, _) => Some(path.resource_descriptor())
    DrawCanvasTextRunUtf8(text, descriptor, font_key, _, _) =>
      Some(descriptor.resource_descriptor(text, font_key~))
    DeclareRenderResource(descriptor) => Some(descriptor)
    _ => None
  }
}

///|
fn RenderCommand::draw_bounds(self : RenderCommand) -> Rect? {
  match self {
    DrawCanvasRect(rect, _) => Some(rect.sorted())
    DrawCanvasPath(path, _) => path.bounds()
    _ => None
  }
}

///|
fn RenderCommand::save_depth_delta(self : RenderCommand) -> Int {
  match self {
    SaveCanvas => 1
    RestoreCanvas => -1
    _ => 0
  }
}

///|
pub(all) struct RenderCommandStats {
  command_count : Int
  draw_count : Int
  state_count : Int
  clip_count : Int
  clear_count : Int
  present_count : Int
  text_count : Int
  max_save_depth : Int
  final_save_depth : Int
  unbalanced_restore_count : Int
} derive(Debug, Eq)

///|
pub fn RenderCommandStats::empty() -> RenderCommandStats {
  {
    command_count: 0,
    draw_count: 0,
    state_count: 0,
    clip_count: 0,
    clear_count: 0,
    present_count: 0,
    text_count: 0,
    max_save_depth: 0,
    final_save_depth: 0,
    unbalanced_restore_count: 0,
  }
}

///|
pub fn RenderCommandStats::is_state_balanced(self : RenderCommandStats) -> Bool {
  self.final_save_depth == 0 && self.unbalanced_restore_count == 0
}

///|
/// Command stream for one render pass. This is the value-layer boundary a GUI
/// renderer can build and inspect before handing commands to native Skia.
pub(all) struct RenderCommandList {
  pass : RenderPassDescriptor
  commands : Array[RenderCommand]
} derive(Debug, Eq)

///|
pub fn RenderCommandList::new(pass : RenderPassDescriptor) -> RenderCommandList {
  { pass, commands: Array::new() }
}

///|
pub fn RenderCommandList::for_target(
  target : SurfaceTargetDescriptor,
  bounds? : IRect? = None,
  load_op? : RenderPassLoadOp = LoadExisting,
  clear_color? : Color? = None,
  store_op? : RenderPassStoreOp? = None,
) -> RenderCommandList {
  let commands = RenderCommandList::new(
    RenderPassDescriptor::for_target(
      target,
      bounds~,
      load_op~,
      clear_color~,
      store_op~,
    ),
  )
  match target.gpu_context_resource_descriptor() {
    None => commands
    Some(descriptor) => commands.declare_resource(descriptor)
  }
}

///|
pub fn RenderCommandList::length(self : RenderCommandList) -> Int {
  self.commands.length()
}

///|
pub fn RenderCommandList::is_empty(self : RenderCommandList) -> Bool {
  self.commands.is_empty()
}

///|
pub fn RenderCommandList::append(
  self : RenderCommandList,
  command : RenderCommand,
) -> RenderCommandList {
  let commands = self.commands.copy()
  commands.push(command)
  { ..self, commands, }
}

///|
pub fn RenderCommandList::save(self : RenderCommandList) -> RenderCommandList {
  self.append(SaveCanvas)
}

///|
pub fn RenderCommandList::restore(
  self : RenderCommandList,
) -> RenderCommandList {
  self.append(RestoreCanvas)
}

///|
pub fn RenderCommandList::clear(
  self : RenderCommandList,
  color : Color,
) -> RenderCommandList {
  self.append(ClearCanvas(color))
}

///|
pub fn RenderCommandList::clip_rect(
  self : RenderCommandList,
  rect : Rect,
  op? : ClipOp = Intersect,
) -> RenderCommandList {
  self.append(RenderCommand::clip_rect(rect, op~))
}

///|
pub fn RenderCommandList::draw_rect(
  self : RenderCommandList,
  rect : Rect,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_rect(rect, paint~))
}

///|
pub fn RenderCommandList::draw_path(
  self : RenderCommandList,
  path : Path,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_path(path, paint~))
}

///|
pub fn RenderCommandList::draw_text_utf8(
  self : RenderCommandList,
  text : Bytes,
  origin : Point,
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(RenderCommand::draw_text_utf8(text, origin, paint~))
}

///|
pub fn RenderCommandList::draw_text_run_utf8(
  self : RenderCommandList,
  text : Bytes,
  origin : Point,
  descriptor? : TextRunDescriptor? = None,
  font_key? : RendererResourceKey = RendererResourceKey::font(b""),
  paint? : Paint = Paint::new(),
) -> RenderCommandList {
  self.append(
    RenderCommand::draw_text_run_utf8(
      text,
      origin,
      descriptor~,
      font_key~,
      paint~,
    ),
  )
}

///|
pub fn RenderCommandList::declare_resource(
  self : RenderCommandList,
  descriptor : RendererResourceDescriptor,
) -> RenderCommandList {
  if descriptor.key.is_empty() {
    self
  } else {
    self.append(RenderCommand::declare_resource(descriptor))
  }
}

///|
pub fn RenderCommandList::declare_resources(
  self : RenderCommandList,
  descriptors : Array[RendererResourceDescriptor],
) -> RenderCommandList {
  let mut result = self
  for descriptor in descriptors {
    result = result.declare_resource(descriptor)
  }
  result
}

///|
pub fn RenderCommandList::present(
  self : RenderCommandList,
) -> RenderCommandList {
  if self.pass.needs_present() && !self.has_present() {
    self.append(PresentSurface)
  } else {
    self
  }
}

///|
pub fn RenderCommandList::finish(self : RenderCommandList) -> RenderCommandList {
  self.present()
}

///|
pub fn RenderCommandList::has_present(self : RenderCommandList) -> Bool {
  let mut found = false
  for command in self.commands {
    if command.is_present() {
      found = true
    }
  }
  found
}

///|
pub fn RenderCommandList::text_run_resource_keys(
  self : RenderCommandList,
) -> Array[RendererResourceKey] {
  let keys : Array[RendererResourceKey] = Array::new()
  for command in self.commands {
    match command.text_run_resource_key() {
      None => ()
      Some(key) => keys.push(key)
    }
  }
  keys
}

///|
fn renderer_resource_descriptor_list_contains_key(
  descriptors : Array[RendererResourceDescriptor],
  key : RendererResourceKey,
) -> Bool {
  let mut found = false
  for descriptor in descriptors {
    if descriptor.key == key {
      found = true
    }
  }
  found
}

///|
pub fn RenderCommandList::resource_descriptors(
  self : RenderCommandList,
) -> Array[RendererResourceDescriptor] {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  let target_descriptor = self.pass.resource_descriptor()
  if !target_descriptor.key.is_empty() {
    descriptors.push(target_descriptor)
  }
  for command in self.commands {
    match command.resource_descriptor() {
      None => ()
      Some(descriptor) =>
        if !descriptor.key.is_empty() &&
          !renderer_resource_descriptor_list_contains_key(
            descriptors,
            descriptor.key,
          ) {
          descriptors.push(descriptor)
        }
    }
  }
  descriptors
}

///|
pub fn RenderCommandList::resource_plan(
  self : RenderCommandList,
) -> RendererResourcePlan {
  RendererResourcePlan::new(self.resource_descriptors())
}

///|
fn RenderCommandStats::record_command(
  self : RenderCommandStats,
  command : RenderCommand,
  current_save_depth : Int,
) -> (RenderCommandStats, Int) {
  let mut depth = current_save_depth + command.save_depth_delta()
  let mut unbalanced_restore_count = self.unbalanced_restore_count
  if depth < 0 {
    unbalanced_restore_count += 1
    depth = 0
  }
  let draw_increment = if command.is_draw() { 1 } else { 0 }
  let state_increment = if command.is_state() { 1 } else { 0 }
  let clip_increment = if command.is_clip() { 1 } else { 0 }
  let clear_increment = if command.is_clear() { 1 } else { 0 }
  let present_increment = if command.is_present() { 1 } else { 0 }
  let text_increment = if command.is_text() { 1 } else { 0 }
  (
    {
      command_count: self.command_count + 1,
      draw_count: self.draw_count + draw_increment,
      state_count: self.state_count + state_increment,
      clip_count: self.clip_count + clip_increment,
      clear_count: self.clear_count + clear_increment,
      present_count: self.present_count + present_increment,
      text_count: self.text_count + text_increment,
      max_save_depth: Int::max(self.max_save_depth, depth),
      final_save_depth: depth,
      unbalanced_restore_count,
    },
    depth,
  )
}

///|
pub fn RenderCommandList::stats(self : RenderCommandList) -> RenderCommandStats {
  for stats = RenderCommandStats::empty(), depth = 0, i = 0
      i < self.commands.length()
      i = i + 1 {
    let (stats, depth) = stats.record_command(self.commands[i], depth)
    continue stats, depth, i + 1
  } nobreak {
    stats
  }
}

///|
pub fn RenderCommandList::is_state_balanced(self : RenderCommandList) -> Bool {
  self.stats().is_state_balanced()
}

///|
fn include_render_command_bounds(bounds : Rect?, next : Rect) -> Rect? {
  if next.is_empty() {
    bounds
  } else {
    match bounds {
      None => Some(next)
      Some(bounds) => Some(bounds.join(next))
    }
  }
}

///|
pub fn RenderCommandList::touched_bounds(self : RenderCommandList) -> Rect? {
  let pass_bounds = self.pass.bounds.to_rect()
  if pass_bounds.is_empty() {
    None
  } else {
    let initial_bounds : Rect? = None
    for bounds = initial_bounds, i = 0; i < self.commands.length(); i = i + 1 {
      let next = match self.commands[i] {
        ClearCanvas(_) => Some(pass_bounds)
        command =>
          match command.draw_bounds() {
            None => None
            Some(draw_bounds) => draw_bounds.intersect(pass_bounds)
          }
      }
      let bounds = match next {
        None => bounds
        Some(next) => include_render_command_bounds(bounds, next)
      }
      continue bounds, i + 1
    } nobreak {
      bounds
    }
  }
}
