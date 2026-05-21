///|
pub(all) struct RuntimeInspectorSnapshot {
  size : Size
  dirty_count : Int
  needs_rebuild : Bool
  needs_layout : Bool
  needs_paint : Bool
  needs_redraw : Bool
  draw_command_count : Int
}

///|
pub(all) struct LayoutInspectorSnapshot {
  root_frame : Rect
  node_count : Int
  leaf_count : Int
  max_depth : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RenderInspectorSnapshot {
  command_count : Int
  text_count : Int
  image_count : Int
  clip_depth : Int
  layer_depth : Int
  filter_depth : Int
  path_count : Int
  shader_count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SemanticsInspectorSnapshot {
  root_role : SemanticsRole
  node_count : Int
  focusable_count : Int
  action_count : Int
  max_depth : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct FrameProfile {
  frame : Frame
  dirty_count : Int
  draw_command_count : Int
  active_animations : Int
} derive(Eq, Debug, ToJson)

///|
pub fn RuntimeInspectorSnapshot::from_runtime(
  runtime : AppRuntime,
) -> RuntimeInspectorSnapshot {
  RuntimeInspectorSnapshot::{
    size: runtime.size(),
    dirty_count: runtime.dirty_count(),
    needs_rebuild: runtime.needs_rebuild(),
    needs_layout: runtime.needs_layout(),
    needs_paint: runtime.needs_paint(),
    needs_redraw: runtime.needs_redraw(),
    draw_command_count: runtime.draw_commands().length(),
  }
}

///|
pub fn LayoutInspectorSnapshot::from_runtime(
  runtime : AppRuntime,
) -> LayoutInspectorSnapshot {
  let layout = runtime.layout()
  {
    root_frame: layout.frame,
    node_count: layout_node_count(layout),
    leaf_count: layout_leaf_count(layout),
    max_depth: layout_max_depth(layout),
  }
}

///|
pub fn RenderInspectorSnapshot::from_runtime(
  runtime : AppRuntime,
) -> RenderInspectorSnapshot {
  render_inspector_from_commands(runtime.draw_commands())
}

///|
pub fn SemanticsInspectorSnapshot::from_runtime(
  runtime : AppRuntime,
) -> SemanticsInspectorSnapshot {
  let semantics = runtime.semantics()
  {
    root_role: semantics.role,
    node_count: semantics_node_count(semantics),
    focusable_count: semantics_focusable_count(semantics),
    action_count: semantics_action_count(semantics),
    max_depth: semantics_max_depth(semantics),
  }
}

///|
pub fn FrameProfile::capture(
  runtime : AppRuntime,
  frame : Frame,
) -> FrameProfile {
  runtime.dispatch_event(AppEvent::FrameTick(frame))
  {
    frame,
    dirty_count: runtime.dirty_count(),
    draw_command_count: runtime.draw_commands().length(),
    active_animations: runtime.animation_count(),
  }
}

///|
fn layout_node_count(node : LayoutResult) -> Int {
  let mut count = 1
  for child in node.children {
    count = count + layout_node_count(child)
  }
  count
}

///|
fn layout_leaf_count(node : LayoutResult) -> Int {
  if node.children.length() == 0 {
    1
  } else {
    let mut count = 0
    for child in node.children {
      count = count + layout_leaf_count(child)
    }
    count
  }
}

///|
fn layout_max_depth(node : LayoutResult) -> Int {
  let mut depth = 1
  for child in node.children {
    depth = devtools_max_int(depth, 1 + layout_max_depth(child))
  }
  depth
}

///|
fn render_inspector_from_commands(
  commands : Array[DrawCommand],
) -> RenderInspectorSnapshot {
  let mut text_count = 0
  let mut image_count = 0
  let mut clip_depth = 0
  let mut max_clip_depth = 0
  let mut layer_depth = 0
  let mut max_layer_depth = 0
  let mut filter_depth = 0
  let mut max_filter_depth = 0
  let mut path_count = 0
  let mut shader_count = 0
  for command in commands {
    match command {
      DrawText(_) => text_count = text_count + 1
      DrawImage(_) => image_count = image_count + 1
      PushClip(_) | PushRoundedClip(_) => {
        clip_depth = clip_depth + 1
        max_clip_depth = devtools_max_int(max_clip_depth, clip_depth)
      }
      PopClip | PopRoundedClip =>
        clip_depth = devtools_max_int(0, clip_depth - 1)
      PushLayer(_) => {
        layer_depth = layer_depth + 1
        max_layer_depth = devtools_max_int(max_layer_depth, layer_depth)
      }
      PopLayer => layer_depth = devtools_max_int(0, layer_depth - 1)
      PushFilter(_) => {
        filter_depth = filter_depth + 1
        max_filter_depth = devtools_max_int(max_filter_depth, filter_depth)
      }
      PopFilter => filter_depth = devtools_max_int(0, filter_depth - 1)
      DrawPath(_) => path_count = path_count + 1
      DrawShaderEffect(_) => shader_count = shader_count + 1
      _ => ()
    }
  }
  {
    command_count: commands.length(),
    text_count,
    image_count,
    clip_depth: max_clip_depth,
    layer_depth: max_layer_depth,
    filter_depth: max_filter_depth,
    path_count,
    shader_count,
  }
}

///|
fn semantics_node_count(node : SemanticsNode) -> Int {
  let mut count = 1
  for child in node.children {
    count = count + semantics_node_count(child)
  }
  count
}

///|
fn semantics_focusable_count(node : SemanticsNode) -> Int {
  let mut count = if node.focus_order is Some(_) { 1 } else { 0 }
  for child in node.children {
    count = count + semantics_focusable_count(child)
  }
  count
}

///|
fn semantics_action_count(node : SemanticsNode) -> Int {
  let mut count = node.actions.length()
  for child in node.children {
    count = count + semantics_action_count(child)
  }
  count
}

///|
fn semantics_max_depth(node : SemanticsNode) -> Int {
  let mut depth = 1
  for child in node.children {
    depth = devtools_max_int(depth, 1 + semantics_max_depth(child))
  }
  depth
}

///|
fn devtools_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
