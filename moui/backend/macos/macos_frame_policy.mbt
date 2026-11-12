///|
/// What the macOS pump should do before producing the next frame.
priv enum MacosFrameWait {
  /// Block on the display refresh clock, bounded by the active timeout.
  WaitForVsync
  /// No clock: sleep for the active interval and retry.
  SleepActive
  /// Nothing is owed: sleep for the idle interval.
  SleepIdle
}

///|
/// Whether the display-refresh clock is requested. The environment switch is
/// an escape hatch for hosts where a synchronous Metal present already waits on
/// the display and an additional vsync wait would double the frame interval.
fn macos_frame_pacing_enabled() -> Bool {
  @env.get_env_var("MOUI_MACOS_FRAME_PACING") != Some("0")
}

///|
/// Pure pacing decision so the pump's wait/sleep branch is testable without a
/// GUI or a real display link.
fn macos_frame_wait_action(
  frame_owed~ : Bool,
  vsync_available~ : Bool,
  pacing_enabled~ : Bool,
) -> MacosFrameWait {
  if !frame_owed {
    SleepIdle
  } else if vsync_available && pacing_enabled {
    WaitForVsync
  } else {
    SleepActive
  }
}

///|
/// Whether any open runtime slot still owes a frame. The pump must not pace on
/// the primary runtime only: child windows have their own drivers.
fn macos_any_runtime_slot_needs_redraw(
  lifecycle : @window_lifecycle.WindowLifecycle,
) -> Bool {
  lifecycle
  .runtime_slots()
  .open_slots()
  .any(slot => @window_host.runtime_slot_needs_redraw(slot))
}

///|
/// Process-wide request flag for the display clock. The async pump opts in;
/// the synchronous `run_app` path does not, so a host that never consumes
/// ticks does not leave a CVDisplayLink running.
let macos_frame_clock_requested : Ref[Bool] = Ref(false)

///|
let macos_frame_clock_running : Ref[Bool] = Ref(false)

///|
fn macos_request_frame_clock() -> Unit {
  macos_frame_clock_requested.val = true
}

///|
fn macos_frame_clock_is_running() -> Bool {
  macos_frame_clock_running.val
}

///|
/// Start the clock once the primary window exists, if the async pump asked for
/// it. Returns whether the clock is running.
fn macos_start_frame_clock(window : @window_macos.Window) -> Bool {
  if !macos_frame_clock_requested.val || !macos_frame_pacing_enabled() {
    return false
  }
  if macos_frame_clock_running.val {
    return true
  }
  let started = @window_macos.host_vsync_init(window)
  macos_frame_clock_running.val = started
  if @env.get_env_var("MOUI_FRAME_LOG") == Some("1") {
    if started {
      println(
        "MoUI macOS display clock started display_id=\{@window_macos.host_vsync_display_id()} refresh_millihz=\{@window_macos.host_vsync_refresh_millihz()}",
      )
    } else {
      println("MoUI macOS display clock unavailable; using timed pacing")
    }
  }
  started
}

///|
/// Stop the clock and clear both the running and request flags.
fn macos_stop_frame_clock() -> Unit {
  @window_macos.host_vsync_shutdown()
  macos_frame_clock_running.val = false
  macos_frame_clock_requested.val = false
}
