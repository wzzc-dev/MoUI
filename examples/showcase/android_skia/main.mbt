///|
let showcase_android_session : Ref[
  @android_host.AndroidRuntimeSession?,
] = Ref(None)

///|
fn showcase_android_metrics(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> @host.HostSurfaceMetrics {
  @host.HostSurfaceMetrics::new(
    logical_size=@core.Size::new(
      width=width.to_double() / scale_factor,
      height=height.to_double() / scale_factor,
    ),
    physical_size=@core.Size::new(
      width=width.to_double(),
      height=height.to_double(),
    ),
    scale_factor~,
  )
}

///|
fn showcase_android_selection() -> @render.NativeRendererSelection {
  @host.mobile_renderer_selection(
    @render.NativeGpuPlatform::Android,
    gpu_available=@android_skia_backend.android_skia_gpu_available(),
  )
}

///|
fn showcase_android_runtime(
  metrics : @host.HostSurfaceMetrics,
) -> @runtime.AppRuntime {
  @runtime.new_program(
    program=@app.ShowcaseApp::new().program_with_initial_route(
      "platform/mobile-service-probe",
    ),
    size=metrics.logical_size,
  )
}

///|
fn showcase_android_renderer_options() -> @android_skia_backend.AndroidSkiaAppOptions {
  let selection = showcase_android_selection()
  @android_skia_backend.AndroidSkiaAppOptions::new(
    surface_route=selection.surface_route,
  )
}

///|
fn showcase_android_provider() -> @android_host.AndroidRendererProvider {
  @android_skia_backend.renderer_provider(
    options=showcase_android_renderer_options(),
  )
}

///|
fn showcase_android_pointer_phase(phase : Int) -> @core.PointerPhase? {
  match phase {
    0 => Some(@core.PointerPhase::Down)
    1 => Some(@core.PointerPhase::Move)
    2 => Some(@core.PointerPhase::Up)
    3 => Some(@core.PointerPhase::Cancel)
    _ => None
  }
}

///|
pub fn showcase_android_attach_surface(
  surface_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  let metrics = showcase_android_metrics(width, height, scale_factor)
  let surface = @android_host.AndroidSurfaceHandle::new(raw=surface_handle)
  let provider = showcase_android_provider()
  match showcase_android_session.val {
    Some(session) => session.attach_surface(surface, metrics, provider)
    None => {
      let runtime = showcase_android_runtime(metrics)
      match
        @android_host.create_session(runtime~, surface~, metrics~, provider~) {
        Some(session) => {
          showcase_android_session.val = Some(session)
          true
        }
        None => false
      }
    }
  }
}

///|
pub fn moui_mobile_renderer_configure(mode : String) -> Bool {
  @host.mobile_renderer_configure(mode)
}

///|
pub fn moui_mobile_renderer_status_json() -> String {
  @host.mobile_renderer_status_json(
    @render.NativeGpuPlatform::Android,
    gpu_available=@android_skia_backend.android_skia_gpu_available(),
  )
}

///|
pub fn showcase_android_resize(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  match showcase_android_session.val {
    Some(session) => {
      ignore(
        session.resize(
          showcase_android_metrics(width, height, scale_factor),
        ),
      )
      true
    }
    None => false
  }
}

///|
pub fn showcase_android_dispatch_pointer(
  phase : Int,
  x : Double,
  y : Double,
  time_ms : Double,
) -> Bool {
  match
    (
      showcase_android_session.val,
      showcase_android_pointer_phase(phase),
    ) {
    (Some(session), Some(pointer_phase)) => {
      let metrics = session.metrics()
      let scale = if metrics.scale_factor > 0.0 {
        metrics.scale_factor
      } else {
        1.0
      }
      ignore(
        session.dispatch(
          @host.HostEvent::Pointer(
            @core.PointerEvent::new(
              position=@core.Point::new(x=x / scale, y=y / scale),
              phase=pointer_phase,
              button=0,
              time_ms~,
            ),
          ),
        ),
      )
      true
    }
    _ => false
  }
}

///|
pub fn showcase_android_dispatch_scroll(
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  phase : Int,
) -> Bool {
  match showcase_android_session.val {
    Some(session) => {
      let metrics = session.metrics()
      let scale = if metrics.scale_factor > 0.0 {
        metrics.scale_factor
      } else {
        1.0
      }
      let scroll_phase = match phase {
        0 => @host.HostScrollPhase::Started
        1 => @host.HostScrollPhase::Moved
        2 => @host.HostScrollPhase::Ended
        3 => @host.HostScrollPhase::Cancelled
        _ => @host.HostScrollPhase::Moved
      }
      ignore(
        session.dispatch(
          @host.HostEvent::Scroll(
            @host.HostScrollEvent::new(
              position=@core.Point::new(x=x / scale, y=y / scale),
              delta=@host.HostScrollDelta::Pixels(
                @core.Point::new(x=delta_x / scale, y=delta_y / scale),
              ),
              phase=scroll_phase,
            ),
          ),
        ),
      )
      true
    }
    None => false
  }
}

///|
pub fn showcase_android_render_frame() -> Bool {
  match showcase_android_session.val {
    Some(session) => {
      ignore(session.render_frame())
      true
    }
    None => false
  }
}

///|
pub fn showcase_android_frame_tick(time_ms : Double) -> Bool {
  match showcase_android_session.val {
    Some(session) => {
      session.advance_time(time_ms)
      if session.take_redraw_requested() || session.runtime().needs_redraw() {
        ignore(session.render_frame())
        true
      } else {
        false
      }
    }
    None => false
  }
}

///|
pub fn moui_mobile_take_host_updates_json() -> String {
  match showcase_android_session.val {
    Some(session) => session.drain_host_updates_json()
    None => "[]"
  }
}

///|
pub fn moui_mobile_take_host_update_envelope_json() -> String {
  match showcase_android_session.val {
    Some(session) => session.drain_host_update_envelope_json()
    None => "{\"schemaVersion\":1,\"sessionGeneration\":0,\"updates\":[]}"
  }
}

///|
pub fn moui_mobile_dispatch_host_response_envelope_json(text : String) -> Bool {
  match showcase_android_session.val {
    Some(session) => session.dispatch_host_response_envelope_json(text)
    None => false
  }
}

///|
pub fn moui_mobile_dispatch_text_input(
  kind : Int,
  text : String,
  start : Int,
  end : Int,
) -> Bool {
  match
    (
      showcase_android_session.val,
      @host.mobile_text_input_response(kind, text, start, end),
    ) {
    (Some(session), Some(response)) => session.dispatch_host_response(response)
    _ => false
  }
}

///|
pub fn moui_mobile_dispatch_command(kind : Int) -> Bool {
  match
    (showcase_android_session.val, @host.mobile_command_response(kind)) {
    (Some(session), Some(response)) => session.dispatch_host_response(response)
    _ => false
  }
}

///|
pub fn moui_mobile_dispatch_accessibility(
  element_id : Int,
  action : Int,
  value : String,
) -> Bool {
  match
    (
      showcase_android_session.val,
      @host.mobile_accessibility_response(element_id, action, value),
    ) {
    (Some(session), Some(response)) => session.dispatch_host_response(response)
    _ => false
  }
}

///|
pub fn moui_mobile_complete_clipboard(
  id : Int,
  kind : Int,
  text : String,
  bytes : Bytes,
) -> Bool {
  match showcase_android_session.val {
    Some(session) => {
      let result = match kind {
        1 => @host.HostServiceResponse::ClipboardText(text)
        2 => @host.HostServiceResponse::ClipboardImage(bytes)
        3 => @host.HostServiceResponse::ClipboardWritten
        _ => @host.HostServiceResponse::Unavailable(text)
      }
      session.dispatch_host_response(
        @host.MobileHostResponse::Clipboard(
          @host.HostServiceRequestId::new(id),
          result,
        ),
      )
    }
    None => false
  }
}

///|
pub fn moui_mobile_complete_clipboard_v1(
  session_generation : Int,
  id : Int,
  kind : Int,
  text : String,
  bytes : Bytes,
) -> Bool {
  match showcase_android_session.val {
    Some(session) if session.session_generation() == session_generation =>
      moui_mobile_complete_clipboard(id, kind, text, bytes)
    _ => false
  }
}

///|
pub fn showcase_android_detach_surface() -> Unit {
  match showcase_android_session.val {
    Some(session) => ignore(session.detach_surface())
    None => ()
  }
}

///|
pub fn showcase_android_destroy_application() -> Unit {
  match showcase_android_session.val {
    Some(session) => session.dispose()
    None => ()
  }
  showcase_android_session.val = None
}

///|
pub fn moui_mobile_attach_surface(
  surface_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  showcase_android_attach_surface(
    surface_handle, width, height, scale_factor,
  )
}

///|
pub fn moui_mobile_resize(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  showcase_android_resize(width, height, scale_factor)
}

///|
pub fn moui_mobile_dispatch_pointer(
  phase : Int,
  x : Double,
  y : Double,
  time_ms : Double,
) -> Bool {
  showcase_android_dispatch_pointer(phase, x, y, time_ms)
}

///|
pub fn moui_mobile_dispatch_scroll(
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  phase : Int,
) -> Bool {
  showcase_android_dispatch_scroll(x, y, delta_x, delta_y, phase)
}

///|
pub fn moui_mobile_frame_tick(time_ms : Double) -> Bool {
  showcase_android_frame_tick(time_ms)
}

///|
pub fn moui_mobile_render_frame() -> Bool {
  showcase_android_render_frame()
}

///|
pub fn moui_mobile_detach_surface() -> Unit {
  showcase_android_detach_surface()
}

///|
pub fn moui_mobile_destroy_application() -> Unit {
  showcase_android_destroy_application()
}

///|
fn main {
  println(@android_skia_backend.android_skia_provider_preflight_summary())
}
