///|
fn RenderCommand::save_depth_delta(self : RenderCommand) -> Int32 {
  match self {
    SaveCanvas | SaveCanvasLayer(_, _, _, _, _) => 1
    RestoreCanvas => -1
    _ => 0
  }
}

///|
pub(all) struct RenderCommandStats {
  command_count : Int32
  draw_count : Int32
  state_count : Int32
  transform_count : Int32
  clip_count : Int32
  clear_count : Int32
  present_count : Int32
  text_count : Int32
  resource_declaration_count : Int32
  image_resource_count : Int32
  shader_resource_count : Int32
  filter_resource_count : Int32
  path_resource_count : Int32
  text_resource_count : Int32
  max_save_depth : Int32
  final_save_depth : Int32
  unbalanced_restore_count : Int32
} derive(Debug, Eq)

///|
pub extend RenderCommandStats with Debug::{to_repr}

///|
pub extend RenderCommandStats with Eq::{not_equal, equal}

///|
pub fn RenderCommandStats::empty() -> RenderCommandStats {
  {
    command_count: 0,
    draw_count: 0,
    state_count: 0,
    transform_count: 0,
    clip_count: 0,
    clear_count: 0,
    present_count: 0,
    text_count: 0,
    resource_declaration_count: 0,
    image_resource_count: 0,
    shader_resource_count: 0,
    filter_resource_count: 0,
    path_resource_count: 0,
    text_resource_count: 0,
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
fn RenderCommandStats::record_command(
  self : RenderCommandStats,
  command : RenderCommand,
  current_save_depth : Int32,
) -> (RenderCommandStats, Int32) {
  let mut depth = current_save_depth + command.save_depth_delta()
  let mut unbalanced_restore_count = self.unbalanced_restore_count
  if depth < 0 {
    unbalanced_restore_count += 1
    depth = 0
  }
  let draw_increment = if command.is_draw() { 1 } else { 0 }
  let state_increment = if command.is_state() { 1 } else { 0 }
  let transform_increment = if command.is_transform() { 1 } else { 0 }
  let clip_increment = if command.is_clip() { 1 } else { 0 }
  let clear_increment = if command.is_clear() { 1 } else { 0 }
  let present_increment = if command.is_present() { 1 } else { 0 }
  let text_increment = if command.is_text() { 1 } else { 0 }
  let resource_declaration_increment = if command.is_resource_declaration() {
    1
  } else {
    0
  }
  let resource_counts = command.resource_counts()
  (
    {
      command_count: self.command_count + 1,
      draw_count: self.draw_count + draw_increment,
      state_count: self.state_count + state_increment,
      transform_count: self.transform_count + transform_increment,
      clip_count: self.clip_count + clip_increment,
      clear_count: self.clear_count + clear_increment,
      present_count: self.present_count + present_increment,
      text_count: self.text_count + text_increment,
      resource_declaration_count: self.resource_declaration_count +
      resource_declaration_increment,
      image_resource_count: self.image_resource_count +
      resource_counts.image_resource_count,
      shader_resource_count: self.shader_resource_count +
      resource_counts.shader_resource_count,
      filter_resource_count: self.filter_resource_count +
      resource_counts.filter_resource_count,
      path_resource_count: self.path_resource_count +
      resource_counts.path_resource_count,
      text_resource_count: self.text_resource_count +
      resource_counts.text_resource_count,
      max_save_depth: Int32::max(self.max_save_depth, depth),
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
