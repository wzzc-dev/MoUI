///|
/// Dev-only offscreen host mode.
///
/// The generated hot host normally launches `@windows_backend.entry()`, which
/// owns a real HWND. Hosted CI runners run in Session 0 and cannot create an
/// interactive window, so the dev runner can opt into this entry instead with
/// `MOUI_HOT_OFFSCREEN=1`. The entry renders the same host runtime and
/// `DevBridgeView` frame tree through the selected renderer's CPU presenter,
/// while the generated host program drives plugin `FrameTick`s from a
/// host-owned timer source pumped by the offscreen frame loop.
///
/// Generation polling and `MOUI_HOT_INJECT_FILE` injection happen directly on
/// the offscreen loop; no window message loop exists in this mode.
///
/// This is not a production backend. It reuses the renderer-neutral
/// `HostSurface` / `RendererSession` contracts, `HostRuntimeDriver` hooks, and
/// the existing `dev_*` bridge ABI unchanged.

///|
extern "C" fn moui_devhost_sleep_ms(milliseconds : Int32) -> Unit = "moui_devhost_sleep_ms"

///|
extern "C" fn moui_devhost_now_ms() -> Double = "moui_devhost_now_ms"

///|
/// Whether `MOUI_HOT_OFFSCREEN` asks the generated host for the offscreen
/// entry. Unset, empty and `0` keep the windowed default.
pub fn offscreen_requested() -> Bool {
  offscreen_enabled(env_nonempty("MOUI_HOT_OFFSCREEN"))
}

///|
fn offscreen_enabled(value : String?) -> Bool {
  match value {
    Some(value) => {
      let value = value.trim()
      value != "" && value != "0"
    }
    None => false
  }
}

///|
/// Host monotonic clock in milliseconds. Used for both the runtime animation
/// clock and the plugin `FrameTick` timestamps, so app timers advance in
/// headless runs instead of freezing at time zero.
fn offscreen_now_ms() -> Double {
  moui_devhost_now_ms()
}

///|
priv struct OffscreenTimer {
  interval_ms : Double
  dispatch : (@core.Frame) -> Unit
  mut next_ms : Double
  mut last_ms : Double
  mut cancelled : Bool
}

///|
/// Timers registered by `offscreen_timer_source()` and fired by
/// `pump_offscreen_timers` on the offscreen loop thread. A plain timer-queue
/// callback would run on a foreign thread with no host clock; the generated
/// host therefore subscribes to this source instead when offscreen mode is on.
let offscreen_timers : Ref[Array[OffscreenTimer]] = Ref([])

///|
/// A dev-only timer source driven by the offscreen frame loop. Unlike the
/// platform timer sources it neither owns a native timer nor a clock: the
/// loop decides when a tick is due, so plugin time and host repaints advance
/// on the same thread that polls reloads and draws.
pub fn offscreen_timer_source() -> @services.TimerSource {
  @services.TimerSource::new(start=(interval_ms, dispatch) => {
    let interval = if interval_ms > 0.0 { interval_ms } else { 16.0 }
    let now = offscreen_now_ms()
    let timer : OffscreenTimer = {
      interval_ms: interval,
      dispatch,
      next_ms: now + interval,
      last_ms: now,
      cancelled: false,
    }
    offscreen_timers.val.push(timer)
    Some(() => timer.cancelled = true)
  })
}

///|
/// Fire every due offscreen timer at `now_ms`. A stalled loop catches up with
/// one tick instead of replaying every missed interval; the plugin's own
/// environment advances its timer registry from the tick's timestamp.
pub fn pump_offscreen_timers(now_ms : Double) -> Unit {
  // Copy so a dispatch that registers another timer cannot disturb iteration.
  let timers = offscreen_timers.val.copy()
  for timer in timers {
    if timer.cancelled {
      continue
    }
    if now_ms >= timer.next_ms {
      let delta_ms = (now_ms - timer.last_ms).max(0.0)
      timer.last_ms = now_ms
      timer.next_ms = now_ms + timer.interval_ms
      (timer.dispatch)(@core.Frame::new(time_ms=now_ms, delta_ms~))
    }
  }
}

///|
/// Build the offscreen platform entry. Width and height are logical DIPs at
/// scale 1.0; `frame_interval_ms` paces both the host tick and the render
/// loop.
pub fn offscreen_entry(
  width~ : Double,
  height~ : Double,
  frame_interval_ms~ : Int32,
) -> @apphost.PlatformEntry {
  @apphost.PlatformEntry::new(id="moui-devhost-offscreen", launch=request => {
    run_offscreen(request, width, height, frame_interval_ms)
  })
}

///|
/// A CPU-presented, display-less surface. Skia's raster provider binds when a
/// host presenter exists and does not require a native window handle.
fn offscreen_surface(
  width : Double,
  height : Double,
  present : @render.PresentTarget,
) -> @render.HostSurface {
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width~, height~),
  )
  @render.HostSurface::new(
    surface_id="moui-devhost-offscreen",
    metrics~,
    cpu_present=Some(present),
    image_source=Some(@host_image_native.filesystem_image_source()),
  )
}

///|
/// One offscreen renderer event drain. Image requests are completed through
/// the shared window image task owner, matching the windowed backends; present
/// completions carry no extra state for a CPU-only headless loop.
fn drain_offscreen_events(
  session : @render.RendererSession,
  images : @window_image.WindowImageTasks,
) -> Unit {
  for event in session.drain_events() {
    match event {
      @render.RendererEvent::PresentCompleted(_) => ()
      @render.RendererEvent::ImageLoadRequested(request) =>
        ignore(images.schedule(session, request))
    }
  }
}

///|
/// Render the host runtime headlessly until the process is stopped. No window
/// exists, so generation polling, synthetic input and frame ticking all happen
/// inline on this loop.
fn run_offscreen(
  request : @apphost.AppLaunchRequest,
  width : Double,
  height : Double,
  frame_interval_ms : Int32,
) -> Unit {
  let presented = Ref(0)
  let present = @render.PresentTarget::new(
    description="MoUI dev host offscreen CPU presenter",
    present=_frame => {
      presented.val = presented.val + 1
      true
    },
  )
  let surface = offscreen_surface(width, height, present)
  let session = match
    @apphost.resolve_renderer_session(request.renderer_providers(), surface) {
    Some(session) => session
    None => {
      println(
        "moui-devhost: offscreen renderer unavailable; no frame will be drawn",
      )
      return
    }
  }
  let runtime = request.runtime()
  runtime.set_text_system(session.text_system())
  // The driver applies the same `augment_frame` hook the windowed backends
  // install, so platform views, overlay bounds, semantics, clear color and
  // full damage reach the renderer in offscreen mode too.
  let driver = @apphost.HostRuntimeDriver::new(
    runtime~,
    schedule_redraw=() => (),
    frame_clock=Some(() => offscreen_now_ms()),
    hooks=Some(driver_hooks()),
  )
  let images = @window_image.WindowImageTasks::new(request_redraw=() => ())
  println(
    "moui-devhost: offscreen surface " +
    width.to_int().to_string() +
    "x" +
    height.to_int().to_string() +
    " (cpu present, direct MOUI_HOT_INJECT_FILE polling)",
  )
  let interval = if frame_interval_ms > 0 { frame_interval_ms } else { 16 }
  let sequence = Ref(0)
  let first_present = Ref(false)
  while true {
    // No window message loop exists here: drive the host tick, reload marker
    // and synthetic input hook on the same thread that draws.
    pump_offscreen_timers(offscreen_now_ms())
    poll_injected_events()
    ignore(poll_reload())
    driver.begin_redraw()
    let frame = driver.draw_frame()
    sequence.val = sequence.val + 1
    let token = @render.FrameToken::new(
      surface_generation=1,
      sequence=sequence.val,
    )
    let result = session.render_frame(
      @render.RenderFrameSubmission::new(token~, frame~),
    )
    if result.presented {
      first_present.val = true
    } else if !first_present.val {
      println("moui-devhost: offscreen present failed")
      driver.finish_redraw()
      return
    }
    driver.finish_redraw()
    drain_offscreen_events(session, images)
    moui_devhost_sleep_ms(interval)
  }
}
