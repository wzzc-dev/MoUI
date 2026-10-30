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
    // animation) and idle-sleep otherwise. A fixed 4 ms sleep made every scroll
    // notch wait out the sleep before presenting, which read as stutter — macOS
    // paces the same way, which is why it never showed this.
    // Frame pacing: poll tight while a frame is owed (a scroll glide, an
    // animation) and idle-sleep otherwise — the same scheme the macOS host uses.
    // A fixed sleep made every scroll notch wait it out before presenting.
    event_loop.run_app_with_frame_pacing(app, needs_redraw=fn() {
      app.needs_redraw()
    })
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
        }
        None =>
          self.backend.handle_window_event(event, exit=fn() {
            event_loop.exit()
          })
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
  match self.backend.read_semantics() {
    Some(read) => {
      // Only `Full` reads carry a tree; the projection returns an empty
      // snapshot for deltas, which leaves ArkUI on the node ids it cached.
      let projection = harmonyos_accessibility_project(read)
      ignore(harmonyos_accessibility_publish(projection))
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
