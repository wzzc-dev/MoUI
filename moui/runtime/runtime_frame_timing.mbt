///|
pub struct RuntimeFrameTiming {
  priv build_ms : Double
  priv layout_ms : Double
  priv paint_ms : Double
  priv draw_ms : Double
  priv total_ms : Double
} derive(Eq, Debug, ToJson)

///|
pub struct ProfiledDrawFrame {
  priv frame : @core.DrawFrame
  priv timing : RuntimeFrameTiming
}

///|
fn RuntimeFrameTiming::zero() -> RuntimeFrameTiming {
  { build_ms: 0.0, layout_ms: 0.0, paint_ms: 0.0, draw_ms: 0.0, total_ms: 0.0 }
}

///|
pub fn RuntimeFrameTiming::build_ms(self : RuntimeFrameTiming) -> Double {
  self.build_ms
}

///|
pub fn RuntimeFrameTiming::layout_ms(self : RuntimeFrameTiming) -> Double {
  self.layout_ms
}

///|
pub fn RuntimeFrameTiming::paint_ms(self : RuntimeFrameTiming) -> Double {
  self.paint_ms
}

///|
pub fn RuntimeFrameTiming::draw_ms(self : RuntimeFrameTiming) -> Double {
  self.draw_ms
}

///|
pub fn RuntimeFrameTiming::total_ms(self : RuntimeFrameTiming) -> Double {
  self.total_ms
}

///|
pub fn ProfiledDrawFrame::frame(self : ProfiledDrawFrame) -> @core.DrawFrame {
  self.frame
}

///|
pub fn ProfiledDrawFrame::timing(
  self : ProfiledDrawFrame,
) -> RuntimeFrameTiming {
  self.timing
}

///|
fn runtime_elapsed_ms(start : Double, finish : Double) -> Double {
  (finish - start).max(0.0)
}

///|
/// Runs the same pipeline as draw_frame, while timing runtime-owned phases
/// with a caller-supplied monotonic millisecond clock. Renderer encoding and
/// presentation remain renderer/host measurements and are not included.
pub fn AppRuntime::profile_draw_frame(
  self : AppRuntime,
  clock : () -> Double,
) -> ProfiledDrawFrame {
  let total_start = clock()
  let build_ms = if self.state.dirty.needs_rebuild {
    let start = clock()
    self.state.rebuild_if_possible()
    runtime_elapsed_ms(start, clock())
  } else {
    0.0
  }
  let layout_ms = if self.state.dirty.needs_layout {
    let start = clock()
    self.state.ensure_layout_tree()
    runtime_elapsed_ms(start, clock())
  } else {
    0.0
  }
  let paint_ms = if self.state.dirty.needs_paint {
    let start = clock()
    self.state.render_current_tree()
    runtime_elapsed_ms(start, clock())
  } else {
    0.0
  }
  let draw_start = clock()
  let frame = self.state.build_draw_frame()
  let draw_ms = runtime_elapsed_ms(draw_start, clock())
  let timing = RuntimeFrameTiming::{
    build_ms,
    layout_ms,
    paint_ms,
    draw_ms,
    total_ms: runtime_elapsed_ms(total_start, clock()),
  }
  self.state.last_frame_timing = timing
  { frame, timing }
}
