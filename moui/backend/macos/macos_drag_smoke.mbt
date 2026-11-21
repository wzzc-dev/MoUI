///|
/// Synthetic slider-drag smoke.
///
/// Dispatches a pointer press on the fixture's slider thumb and then one
/// pointer move per presented frame, recording the present-to-present
/// interval. That interval is the whole interaction loop the user feels —
/// event dispatch, rebuild, renderer replay, present, pump wait — so Sun and
/// Skia routes (and debug/release builds) compare on measured numbers instead
/// of feel. One move per present keeps the loop identical across routes: the
/// pump never has queued moves waiting, it always redraws for the single new
/// event.

///|
let slider_drag_smoke_move_step = 8.0

///|
let slider_drag_smoke_moves = 40

///|
let slider_drag_smoke_press_x = 288.0

///|
let slider_drag_smoke_press_y = 24.0

///|
fn MacosNativeHostBackend::record_slider_drag_smoke(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
) -> Bool {
  if !self.slider_drag_smoke || self.slider_drag_smoke_done {
    return false
  }
  let runtime_slot = match
    self.core.lifecycle.runtime_slots().lookup(window_id) {
    Some(slot) => slot
    None => return false
  }
  // The primary window shows after the first present; until it is key the
  // pump has no focused slot, so wait the way the IME smoke does.
  let window_focused = match runtime_slot.record.phase {
    WindowFocused => true
    _ => false
  }
  if !window_focused {
    self.request_platform_redraw(window_id)
    return false
  }
  let now = macos_perf_now_ms()
  if self.slider_drag_smoke_last_present_ms > 0.0 {
    let interval = now - self.slider_drag_smoke_last_present_ms
    if interval > 0.0 {
      self.slider_drag_smoke_intervals_ms.push(interval)
    }
  }
  self.slider_drag_smoke_last_present_ms = now
  let moves_done = self.slider_drag_smoke_intervals_ms.length() >=
    slider_drag_smoke_moves
  if moves_done {
    self.slider_drag_smoke_done = true
    self.report_slider_drag_smoke()
    self.dispose_window(window_id)
    return true
  }
  if !self.slider_drag_smoke_down_dispatched {
    self.slider_drag_smoke_down_dispatched = true
    self.slider_drag_smoke_x = slider_drag_smoke_press_x
    ignore(
      runtime_slot.driver.dispatch(
        Pointer(
          @core.PointerEvent::new(
            position=@core.Point::new(
              x=slider_drag_smoke_press_x,
              y=slider_drag_smoke_press_y,
            ),
            phase=Down,
          ),
        ),
      ),
    )
  } else {
    let next_x = self.slider_drag_smoke_x + slider_drag_smoke_move_step
    self.slider_drag_smoke_x = next_x
    ignore(
      runtime_slot.driver.dispatch(
        Pointer(
          @core.PointerEvent::new(
            position=@core.Point::new(x=next_x, y=slider_drag_smoke_press_y),
            phase=Move,
          ),
        ),
      ),
    )
  }
  false
}

///|
fn MacosNativeHostBackend::report_slider_drag_smoke(
  self : MacosNativeHostBackend,
) -> Unit {
  let intervals = self.slider_drag_smoke_intervals_ms
  let frames = intervals.length()
  guard frames > 0 else {
    println("MoUI macOS drag smoke: no frames recorded")
    return
  }
  let sorted = intervals.copy()
  sorted.sort()
  let p50 = sorted[frames / 2]
  let p95 = sorted[(frames * 95 / 100).min(frames - 1)]
  let max = sorted[frames - 1]
  let mut sum = 0.0
  for value in intervals {
    sum = sum + value
  }
  let fps = if sum > 0.0 { frames.to_double() / (sum / 1000.0) } else { 0.0 }
  println(
    "MoUI macOS drag smoke: frames=\{frames} p50_ms=\{p50} p95_ms=\{p95} max_ms=\{max} fps=\{fps}",
  )
}
