///|
let ios_counter_session : Ref[@ios_host.IosRuntimeSession?] = Ref(None)

///|
fn ios_counter_metrics(
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
fn ios_counter_runtime(
  metrics : @host.HostSurfaceMetrics,
) -> @runtime.AppRuntime {
  @runtime.new_program(
    program=@counter_app.program(),
    size=metrics.logical_size,
  )
}

///|
fn ios_counter_renderer_options() -> @ios_skia_backend.IosSkiaAppOptions {
  let selection = @host.mobile_renderer_selection(
    @render.NativeGpuPlatform::Ios,
    gpu_available=@ios_skia_backend.ios_skia_gpu_available(),
  )
  @ios_skia_backend.IosSkiaAppOptions::new(
    surface_route=selection.surface_route,
  )
}

///|
fn ios_counter_provider() -> @ios_host.IosRendererProvider {
  @ios_skia_backend.renderer_provider(options=ios_counter_renderer_options())
}

///|
fn ios_counter_pointer_phase(phase : Int) -> @core.PointerPhase? {
  match phase {
    0 => Some(@core.PointerPhase::Down)
    1 => Some(@core.PointerPhase::Move)
    2 => Some(@core.PointerPhase::Up)
    3 => Some(@core.PointerPhase::Cancel)
    _ => None
  }
}

///|
pub fn ios_counter_attach_view(
  view_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  let metrics = ios_counter_metrics(width, height, scale_factor)
  let view = @ios_host.IosViewHandle::new(raw=view_handle)
  let provider = ios_counter_provider()
  match ios_counter_session.val {
    Some(session) => session.attach_view(view, metrics, provider)
    None => {
      let runtime = ios_counter_runtime(metrics)
      match @ios_host.create_session(runtime~, view~, metrics~, provider~) {
        Some(session) => {
          ios_counter_session.val = Some(session)
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
    @render.NativeGpuPlatform::Ios,
    gpu_available=@ios_skia_backend.ios_skia_gpu_available(),
  )
}

///|
pub fn ios_counter_resize(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  match ios_counter_session.val {
    Some(session) => {
      ignore(session.resize(ios_counter_metrics(width, height, scale_factor)))
      true
    }
    None => false
  }
}

///|
pub fn ios_counter_dispatch_pointer(
  phase : Int,
  x : Double,
  y : Double,
  time_ms : Double,
) -> Bool {
  match (ios_counter_session.val, ios_counter_pointer_phase(phase)) {
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
pub fn ios_counter_dispatch_scroll(
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  phase : Int,
) -> Bool {
  match ios_counter_session.val {
    Some(session) => {
      let scale = session.metrics().scale_factor.max(1.0)
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
pub fn ios_counter_render_frame() -> Bool {
  match ios_counter_session.val {
    Some(session) => {
      ignore(session.render_frame())
      true
    }
    None => false
  }
}

///|
pub fn ios_counter_frame_tick(time_ms : Double) -> Bool {
  match ios_counter_session.val {
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
  match ios_counter_session.val {
    Some(session) => session.drain_host_updates_json()
    None => "[]"
  }
}

///|
pub fn moui_mobile_take_host_update_envelope_json() -> String {
  match ios_counter_session.val {
    Some(session) => session.drain_host_update_envelope_json()
    None => "{\"schemaVersion\":1,\"sessionGeneration\":0,\"updates\":[]}"
  }
}

///|
pub fn moui_mobile_dispatch_host_response_envelope_json(text : String) -> Bool {
  match ios_counter_session.val {
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
      ios_counter_session.val,
      @host.mobile_text_input_response(kind, text, start, end),
    ) {
    (Some(session), Some(response)) => session.dispatch_host_response(response)
    _ => false
  }
}

///|
pub fn moui_mobile_dispatch_command(kind : Int) -> Bool {
  match (ios_counter_session.val, @host.mobile_command_response(kind)) {
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
      ios_counter_session.val,
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
  match ios_counter_session.val {
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
  match ios_counter_session.val {
    Some(session) if session.session_generation() == session_generation =>
      moui_mobile_complete_clipboard(id, kind, text, bytes)
    _ => false
  }
}

///|
pub fn ios_counter_detach_view() -> Unit {
  match ios_counter_session.val {
    Some(session) => ignore(session.detach_view())
    None => ()
  }
}

///|
pub fn ios_counter_destroy_application() -> Unit {
  match ios_counter_session.val {
    Some(session) => session.dispose()
    None => ()
  }
  ios_counter_session.val = None
}

///|
pub fn moui_mobile_attach_surface(
  surface_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  ios_counter_attach_view(surface_handle, width, height, scale_factor)
}

///|
pub fn moui_mobile_resize(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  ios_counter_resize(width, height, scale_factor)
}

///|
pub fn moui_mobile_dispatch_pointer(
  phase : Int,
  x : Double,
  y : Double,
  time_ms : Double,
) -> Bool {
  ios_counter_dispatch_pointer(phase, x, y, time_ms)
}

///|
pub fn moui_mobile_dispatch_scroll(
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  phase : Int,
) -> Bool {
  ios_counter_dispatch_scroll(x, y, delta_x, delta_y, phase)
}

///|
pub fn moui_mobile_frame_tick(time_ms : Double) -> Bool {
  ios_counter_frame_tick(time_ms)
}

///|
pub fn moui_mobile_render_frame() -> Bool {
  ios_counter_render_frame()
}

///|
pub fn moui_mobile_detach_surface() -> Unit {
  ios_counter_detach_view()
}

///|
pub fn moui_mobile_destroy_application() -> Unit {
  ios_counter_destroy_application()
}

///|
fn main {
  println(@ios_skia_backend.ios_skia_provider_preflight_summary())
}
