///|
/// Embedded runtime backend on the window-hosted route: surface/input come
/// only from `wzzc-dev/window/harmonyos` HostCmd → ApplicationHandler.
/// Surface attachment is driven only by the platform event loop. The backend
/// is a thin shell around the shared `HostedWindowBackend`; native
/// XComponent surface access and window creation stay here.
pub struct HarmonyOSEmbeddedRuntimeBackend {
  backend : @embedded_runtime.HostedWindowBackend
  // Last reported image status summary, so the per-frame pump only logs on a
  // transition instead of every frame.
  mut image_status_summary : String
  // Generation of the semantics snapshot last published to ArkUI, so the
  // accessibility pump skips projection while the tree is unchanged.
  mut accessibility_cursor : @core.SemanticsGeneration?
  // Last clock the pump heartbeat reported at, so the diagnostic log bursts at
  // most ~10/s while a frame is owed.
  mut pump_report_ms : Double
  // TEMP: pointer-move sample counter for the drag-tracking investigation.
  mut pointer_move_samples : Int32
}

///|
pub extend HarmonyOSEmbeddedRuntimeBackend with @wzzc-dev/window/harmonyos.ApplicationHandler::{
  standard_key_binding,
  suspended,
  new_events,
  memory_warning,
  device_event,
  destroy_surfaces,
  can_create_surfaces,
  resumed,
  window_event,
  about_to_wait,
  proxy_wake_up,
}

///|
pub fn HarmonyOSEmbeddedRuntimeBackend::new(
  title~ : String = "MoUI",
  runtime_factory~ : (@core.SurfaceMetrics) -> @runtime.AppRuntime,
  renderer_providers~ : Array[@render.RendererProvider],
  auto_exit_after_frames~ : Int32? = None,
) -> HarmonyOSEmbeddedRuntimeBackend {
  new_harmonyos_embedded_runtime(
    title~,
    runtime_factory~,
    surface_binding_factory=() => harmonyos_surface_binding(renderer_providers),
    auto_exit_after_frames~,
  )
}

///|
/// Application-builder entry for the HarmonyOS window-hosted event loop.
pub fn entry(auto_exit_after_frames~ : Int32? = None) -> @runtime.PlatformEntry {
  @runtime.PlatformEntry::new(id="harmonyos", launch=request => {
    let runtime = request.runtime()
    let app = HarmonyOSEmbeddedRuntimeBackend::new(
      title=request.title(),
      runtime_factory=_metrics => runtime,
      renderer_providers=request.renderer_providers(),
      auto_exit_after_frames~,
    )
    harmonyos_report_vsync_status()
    let event_loop = @window_harmonyos.EventLoop::new()
    // Frame pacing: poll tight while a frame is owed (a scroll glide, an
    // animation) and idle-sleep otherwise — the same scheme the macOS host
    // uses. Measured on device (2026-11-02): a 17 ms wait bound barely spans
    // the 60 Hz period, so the wait timed out every frame and the fallback
    // slept another 17 ms — a 34 ms pure-wait floor plus ~19 ms of present
    // work locked every frame to 53 ms (19 fps) across 39k frames. A small
    // bound plus a 1 ms fallback lets the loop run at the frame-work rate
    // (~20 ms on the Showcase images page); the compositor coalesces
    // out-of-phase presents, and idle keeps the 4 ms poll.
    event_loop.run_app_with_frame_pacing(
      app,
      needs_redraw=fn() { app.needs_redraw() },
      active_frame_ms=2,
    )
  })
}

///|
/// Stable token for an image resource status, used in the device log.
fn image_status_token(status : @render.ImageResourceStatus) -> String {
  match status {
    ImageLoading => "loading"
    ImageReady => "ready"
    ImageFailed => "failed"
    ImageDisposed => "disposed"
  }
}

///|
fn new_harmonyos_embedded_runtime(
  title~ : String,
  runtime_factory~ : (@core.SurfaceMetrics) -> @runtime.AppRuntime,
  surface_binding_factory~ : () -> HarmonyOSSurfaceBinding,
  auto_exit_after_frames~ : Int32?,
) -> HarmonyOSEmbeddedRuntimeBackend {
  {
    backend: @embedded_runtime.HostedWindowBackend::new(
      title~,
      runtime_factory~,
      // Frame timing: the runtime advances its animation clock from this on every
      // presented frame. Without a clock a wheel settle stays latched in flight —
      // the surface moves a few pixels, then freezes until the next input.
      clock_ms=fn() { @window_harmonyos.host_monotonic_ms() },
      // Answer clipboard requests synchronously from the native pasteboard so
      // Ctrl+C / Ctrl+X / Ctrl+V work: the runtime expects `ClipboardText` on the
      // spot, and the queued path only resolves when a shell drains it.
      service_handler=request => {
        // Device log evidence: a shortcut that reaches the clipboard shows up
        // here. Without it Ctrl+C / Ctrl+V silently fell through to the queued
        // path that nothing drains.
        harmonyos_log_service_request(request)
        match request {
          Clipboard(ReadText) =>
            match harmonyos_clipboard_read_text() {
              Some(text) => Some(ClipboardText(text))
              None => Some(Unavailable("clipboard does not contain text"))
            }
          Clipboard(WriteText(text)) =>
            if harmonyos_clipboard_write_text(text) {
              Some(ClipboardWritten)
            } else {
              Some(Unavailable("clipboard write failed"))
            }
          _ => None
        }
      },
      surface_binding_factory=() => {
        host_surface_binding_from_harmonyos(surface_binding_factory())
      },
      auto_exit_after_frames~,
    ),
    image_status_summary: "",
    accessibility_cursor: None,
    pump_report_ms: 0.0,
    pointer_move_samples: 0,
  }
}

///|
pub fn HarmonyOSEmbeddedRuntimeBackend::frames_presented(
  self : HarmonyOSEmbeddedRuntimeBackend,
) -> Int32 {
  self.backend.frames_presented()
}

///|
pub fn HarmonyOSEmbeddedRuntimeBackend::surface_generation(
  self : HarmonyOSEmbeddedRuntimeBackend,
) -> Int32 {
  self.backend.surface_generation()
}

///|
pub fn HarmonyOSEmbeddedRuntimeBackend::session_attached(
  self : HarmonyOSEmbeddedRuntimeBackend,
) -> Bool {
  self.backend.session_attached()
}

///|
pub fn HarmonyOSEmbeddedRuntimeBackend::has_session(
  self : HarmonyOSEmbeddedRuntimeBackend,
) -> Bool {
  self.backend.has_session()
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn resumed(
  self,
  _event_loop,
) {
  self.backend.resumed()
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn can_create_surfaces(
  self,
  event_loop,
) {
  ignore(
    self.backend.ensure_surface(create=() => {
      let attrs = @window_core.WindowAttributes::default().with_title(
        self.backend.title(),
      )
      let created : @window_harmonyos.Window? = Some(
        event_loop.try_create_window(attrs),
      ) catch {
        _ => None
      }
      match created {
        Some(window) =>
          Some(
            (
              @embedded_runtime.HostedWindow::new(
                scale_factor=fn() { window.scale_factor() },
                inner_size=fn() { window.inner_size() },
                request_redraw=fn() { window.request_redraw() },
                drop=fn() { window.drop() },
              ),
              window.xcomponent_window_handle(),
            ),
          )
        None => None
      }
    }),
  )
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn destroy_surfaces(
  self,
  _event_loop,
) {
  self.backend.destroy_surfaces()
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn suspended(
  self,
  _event_loop,
) {
  self.backend.suspended()
}

///|
// Frame-path diagnostics for the scroll jank investigation
// (docs/plans/active/harmonyos-scroll-frame-pacing.md). These strings
// allocate per frame and feed the GC churn under measurement; flip off
// once the present-path work lands.
let harmonyos_frame_diagnostics = true

// TEMP: a11y pump toggle for the frame-cost attribution experiment
// (docs/plans/active/harmonyos-scroll-frame-pacing.md).

///|
let harmonyos_a11y_pump_enabled = true

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn window_event(
  self,
  event_loop,
  _id,
  event,
) {
  // A wheel notch carries its cursor position separately (recorded by the host
  // queue). Apply it with the wheel in one dispatch so the scroll targets the
  // cursor instead of the last click, and so no synthetic pointer move (with its
  // hover repaint) is dispatched per notch.
  match event {
    @window_core.WindowEvent::KeyboardInput(_, key_event, _) => {
      // Log the raw chord plus the resolved intent and focus state, so a device
      // capture shows exactly where a clipboard shortcut stops.
      let intent = match self.backend.keyboard_command_intent_event(key_event) {
        Some(intent) =>
          match intent {
            Copy => "copy"
            Cut => "cut"
            Paste => "paste"
            SelectAll => "select-all"
            _ => "other"
          }
        None => "none"
      }
      let focused = self.backend.has_focused_text_input()
      harmonyos_log_image_status(
        "keyboard key=\{key_event.logical_key()} ctrl=\{self.backend.modifiers().control} intent=\{intent} focused=\{focused}",
      )
    }
    _ => ()
  }
  match event {
    @window_core.WindowEvent::MouseWheel(_, delta, _) =>
      match @window_harmonyos.host_take_scroll_cursor() {
        Some((x, y)) => {
          // The axis position is physical; `last_pointer` holds logical
          // coordinates (touch events are divided by the scale factor before they
          // reach it). Passing the raw physical value made the wheel test against
          // a frame that was off by that factor, which is why scrolling only
          // worked where the shifted point still landed inside the scroll area.
          let scale = self.backend.scale_factor()
          let logical = @core.Point::new(x=x / scale, y=y / scale)
          let (dx, dy) = window_scroll_delta_pixels(delta)
          harmonyos_log_image_status(
            "scroll px dx=\{dx.to_int()} dy=\{dy.to_int()} logical=\{logical.x.to_int()},\{logical.y.to_int()} frames=\{self.backend.frames_presented()} clock=\{@window_harmonyos.host_monotonic_ms().to_int()}",
          )
          self.backend.dispatch_wheel(logical, delta)
          // Post-dispatch evidence: if `dispatch_wheel` aborts mid-way (the
          // pre-dispatch render pipeline raises), this line is missing for
          // that wheel while "scroll px" still printed. `needs` answers
          // whether the runtime still owes a frame after the wheel landed.
          if harmonyos_frame_diagnostics {
            harmonyos_log_image_status(
              "wheel dispatched needs=\{self.needs_redraw()} frames=\{self.backend.frames_presented()}",
            )
          }
        }
        None =>
          self.backend.handle_window_event(event, exit=fn() {
            event_loop.exit()
          })
      }
    @window_core.WindowEvent::PointerMoved(_, position, _, _) => {
      // TEMP: pointer-move sampling for the drag-tracking investigation.
      self.pointer_move_samples = self.pointer_move_samples + 1
      if harmonyos_frame_diagnostics && self.pointer_move_samples % 5 == 0 {
        harmonyos_log_image_status(
          "pointer moved sample=\{self.pointer_move_samples} frames=\{self.backend.frames_presented()} pos=\{position.x.to_int()},\{position.y.to_int()}",
        )
      }
      self.backend.handle_window_event(event, exit=fn() { event_loop.exit() })
    }
    @window_core.WindowEvent::RedrawRequested => {
      // Frame-path evidence (docs/plans/active/harmonyos-scroll-frame-pacing.md):
      // a RedrawRequested that presents nothing is the frozen-frames signature
      // from the 2026-11-02 capture. Logged unconditionally while the render
      // rate is under diagnosis; gate to the failure case once the loop keeps
      // pace with the refresh.
      let before_frames = self.backend.frames_presented()
      let render_start = @window_harmonyos.host_monotonic_ms()
      self.backend.handle_window_event(event, exit=fn() { event_loop.exit() })
      if harmonyos_frame_diagnostics {
        harmonyos_log_image_status(
          "redraw frames=\{before_frames}->\{self.backend.frames_presented()} needs=\{self.needs_redraw()} render=\{(@window_harmonyos.host_monotonic_ms() - render_start)}ms \{self.backend.present_breakdown()} \{self.backend.last_frame_timing_summary()}",
        )
      }
    }
    _ =>
      self.backend.handle_window_event(event, exit=fn() { event_loop.exit() })
  }
}

///|
pub impl @window_harmonyos.ApplicationHandler for HarmonyOSEmbeddedRuntimeBackend with fn about_to_wait(
  self,
  _event_loop,
) {
  // Pump heartbeat while a frame is owed: dense lines mean the loop is
  // pumping; gaps mean the loop itself is blocked between pumps. The dirty
  // reason and phase timing ride along for the frame-cost investigation
  // (docs/plans/active/harmonyos-scroll-frame-pacing.md).
  let now = @window_harmonyos.host_monotonic_ms()
  if harmonyos_frame_diagnostics &&
    self.needs_redraw() &&
    now - self.pump_report_ms >= 100.0 {
    self.pump_report_ms = now
    harmonyos_log_image_status(
      "pump needs=true frames=\{self.backend.frames_presented()} clock=\{now.to_int()}",
    )
  }
  self.backend.about_to_wait()
  // Accessibility runs on the platform UI cadence: ArkUI reads whatever tree
  // was published last, and any action it queued during the previous frame is
  // dispatched here rather than from inside the ArkUI callback (which cannot
  // re-enter the runtime).
  self.pump_accessibility()
}

///|
/// Logs whether vsync pacing initialised, so a device capture shows whether the
/// loop is pacing on the display refresh or on the timed fallback.
pub fn harmonyos_report_vsync_status() -> Unit {
  let ok = @window_harmonyos.host_vsync_init()
  harmonyos_log_image_status("vsync init ok=\{ok}")
}

///|
/// Whether the runtime still owes a frame, used by the host loop for frame
/// pacing.
pub fn HarmonyOSEmbeddedRuntimeBackend::needs_redraw(
  self : HarmonyOSEmbeddedRuntimeBackend,
) -> Bool {
  self.backend.needs_redraw()
}

///|
/// Publishes the current semantics tree to the ArkUI accessibility provider and
/// dispatches one queued accessibility action, if any.
pub fn HarmonyOSEmbeddedRuntimeBackend::pump_accessibility(
  self : HarmonyOSEmbeddedRuntimeBackend,
) -> Unit {
  if not(harmonyos_a11y_pump_enabled) {
    // TEMP: disabled for the a11y-pump frame-cost attribution experiment.
    return
  }
  match self.backend.read_semantics(since=self.accessibility_cursor) {
    // The committed tree is exactly the snapshot already published: skip the
    // projection and the publish. This pump runs every loop iteration, so an
    // unconditional full-tree projection is O(nodes) allocation churn per
    // pump — dominant during a scroll glide.
    Some(Unchanged(_)) => ()
    // First publish (no cursor yet) reads `Full` directly.
    Some(Full(snapshot)) => self.publish_accessibility_snapshot(Full(snapshot))
    // The tree moved past the published generation but read back as a delta
    // chain: re-read the authoritative full snapshot. Do not publish the
    // empty projection — the native publish replaces the snapshot pointer
    // unconditionally, which would wipe the node table ArkUI is still reading.
    Some(Delta(_)) =>
      match self.backend.read_semantics() {
        Some(read) => self.publish_accessibility_snapshot(read)
        None => ()
      }
    None => ()
  }
  // Async image load evidence: `ImageLoading -> ImageReady` happens off the
  // frame path, so report every distinct state once.
  let records = self.backend.image_resource_records()
  if records.length() > 0 {
    let summary = records
      .map(record => {
        "\{image_status_token(record.status)}=\{record.width}x\{record.height}"
      })
      .join(",")
    if summary != self.image_status_summary {
      self.image_status_summary = summary
      harmonyos_log_image_status("moui harmonyos images: " + summary)
    }
  }
  // Answer clipboard requests queued by Ctrl+C / Ctrl+V. The embedded runtime
  // only enqueues them; with no shell drainer they would hang forever, which is
  // why the shortcuts did nothing.
  for pending in self.backend.drain_pending_service_requests() {
    match pending.request {
      Clipboard(request) =>
        ignore(
          self.backend.complete_service_request(
            pending.id,
            match request {
              ReadText =>
                match harmonyos_clipboard_read_text() {
                  Some(text) => ClipboardText(text)
                  None => Unavailable("clipboard does not contain text")
                }
              WriteText(text) =>
                if harmonyos_clipboard_write_text(text) {
                  ClipboardWritten
                } else {
                  Unavailable("clipboard write failed")
                }
              _ => Unavailable("clipboard request not supported")
            },
          ),
        )
      _ => ()
    }
  }
  match harmonyos_accessibility_take_action() {
    Some(pending) => {
      let request : @runtime.PerformSemanticsActionRequest = {
        target: @core.SemanticsTarget::ByNodeId(
          @core.SemanticsNodeId::new(pending.element_id.reinterpret_as_uint64()),
        ),
        action: match pending.action {
          1 => @core.SemanticsAction::Activate
          2 => @core.SemanticsAction::Focus
          _ => return
        },
        precondition: @runtime.Exact(
          @core.SemanticsGeneration::new(pending.generation),
        ),
      }
      ignore(self.backend.perform_semantics_action(request))
    }
    None => ()
  }
}

///|
/// Publishes a semantics read to ArkUI and records its generation as the
/// accessibility cursor. Only `Full` reads carry a tree; the native publish
/// replaces the snapshot pointer unconditionally, so anything else must
/// publish nothing rather than the empty projection.
fn HarmonyOSEmbeddedRuntimeBackend::publish_accessibility_snapshot(
  self : HarmonyOSEmbeddedRuntimeBackend,
  read : @runtime.SemanticsRead,
) -> Unit {
  match read {
    Full(snapshot) => {
      ignore(
        harmonyos_accessibility_publish(harmonyos_accessibility_project(read)),
      )
      self.accessibility_cursor = Some(snapshot.generation())
    }
    _ => ()
  }
}

///|
/// Pump one host-sim cycle for tests / offline validation.
pub fn harmonyos_window_hosted_pump_host_sim(
  app : HarmonyOSEmbeddedRuntimeBackend,
  surface_handle~ : UInt64 = 0xABCUL,
  width~ : Int32 = 320,
  height~ : Int32 = 640,
  scale~ : Double = 2.0,
) -> Unit {
  @window_harmonyos.host_reset_for_test()
  let event_loop = @window_harmonyos.EventLoop::new()
  @window_harmonyos.host_push(Start)
  @window_harmonyos.host_push(Resume)
  @window_harmonyos.host_push(
    SurfaceInit(surface_handle, 0UL, width, height, scale),
  )
  ignore(event_loop.pump_app_events(None, app))
  app.backend.force_redraw()
  ignore(event_loop.pump_app_events(None, app))
  @window_harmonyos.host_push(PointerButton(true, 10.0, 20.0))
  @window_harmonyos.host_push(PointerButton(false, 10.0, 20.0))
  ignore(event_loop.pump_app_events(None, app))
  @window_harmonyos.host_push(SurfaceTerm)
  @window_harmonyos.host_push(Stop)
  ignore(event_loop.pump_app_events(None, app))
  event_loop.drop()
}

///|
/// Pixel form of a window-core scroll delta, for the device log.
fn window_scroll_delta_pixels(
  delta : @window_core.MouseScrollDelta,
) -> (Double, Double) {
  match delta {
    LineDelta(x, y) => (x, y)
    PixelDelta(position) => (position.x, position.y)
  }
}
