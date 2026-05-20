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
