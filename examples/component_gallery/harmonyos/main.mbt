///|
let component_gallery_harmonyos_session : Ref[
  @harmonyos_host.HarmonyOsRuntimeSession?,
] = Ref(None)

///|
fn component_gallery_harmonyos_safe_scale(scale_factor : Double) -> Double {
  if scale_factor > 0.0 {
    scale_factor
  } else {
    1.0
  }
}

///|
fn component_gallery_harmonyos_metrics(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> @host.HostSurfaceMetrics {
  let scale = component_gallery_harmonyos_safe_scale(scale_factor)
  @host.HostSurfaceMetrics::new(
    logical_size=@core.Size::new(
      width=width.to_double() / scale,
      height=height.to_double() / scale,
    ),
    physical_size=@core.Size::new(
      width=width.to_double(),
      height=height.to_double(),
    ),
    scale_factor=scale,
  )
}

///|
fn component_gallery_harmonyos_selection() -> @render.NativeRendererSelection {
  @host.mobile_renderer_selection(
    @render.NativeGpuPlatform::HarmonyOs,
    gpu_available=@harmonyos_skia_backend.harmonyos_skia_gpu_available(),
  )
}

///|
fn component_gallery_harmonyos_session_runtime() -> @component_gallery_app.SessionRuntimeInfo {
  let selection = component_gallery_harmonyos_selection()
  @component_gallery_app.session_runtime_from_selection(
    host="HarmonyOS",
    backend=selection.selected.label(),
    surface_route=selection.surface_route.label(),
    requested=selection.requested.label(),
    gpu_available=selection.gpu_available,
    gpu_promoted=selection.gpu_promoted,
    note=match selection.fallback_reason {
      Some(reason) => reason
      None =>
        "Mobile product default is Skia GPU when the host surface is available."
    },
  )
}

///|
fn component_gallery_harmonyos_runtime(
  metrics : @host.HostSurfaceMetrics,
) -> @runtime.AppRuntime {
  @runtime.new_program(
    program=@component_gallery_app.program(
      active_platform=@component_gallery_app.PlatformId::HarmonyOs,
      session_runtime=component_gallery_harmonyos_session_runtime(),
    ),
    size=metrics.logical_size,
  )
}

///|
fn component_gallery_harmonyos_renderer_options() -> @harmonyos_skia_backend.HarmonyOsSkiaAppOptions {
  let selection = component_gallery_harmonyos_selection()
  @harmonyos_skia_backend.HarmonyOsSkiaAppOptions::new(
    surface_route=selection.surface_route,
  )
}

///|
fn component_gallery_harmonyos_pointer_phase(
  phase : Int,
) -> @core.PointerPhase? {
  match phase {
    0 => Some(@core.PointerPhase::Down)
    1 => Some(@core.PointerPhase::Move)
    2 => Some(@core.PointerPhase::Up)
    3 => Some(@core.PointerPhase::Cancel)
    _ => None
  }
}

///|
pub fn component_gallery_harmonyos_attach_surface(
  surface_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  component_gallery_harmonyos_detach_surface()
  let metrics = component_gallery_harmonyos_metrics(width, height, scale_factor)
  let runtime = component_gallery_harmonyos_runtime(metrics)
  match
    @harmonyos_skia_backend.create_session(
      runtime~,
      surface=@harmonyos_host.HarmonyOsSurfaceHandle::new(raw=surface_handle),
      metrics~,
      options=component_gallery_harmonyos_renderer_options(),
    ) {
    Some(session) => {
      component_gallery_harmonyos_session.val = Some(session)
      true
    }
    None => false
  }
}

///|
pub fn moui_mobile_renderer_configure(mode : String) -> Bool {
  @host.mobile_renderer_configure(mode)
}

///|
pub fn moui_mobile_renderer_status_json() -> String {
  @host.mobile_renderer_status_json(
    @render.NativeGpuPlatform::HarmonyOs,
    gpu_available=@harmonyos_skia_backend.harmonyos_skia_gpu_available(),
  )
}

///|
pub fn component_gallery_harmonyos_resize(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  match component_gallery_harmonyos_session.val {
    Some(session) => {
      ignore(
        session.resize(
          component_gallery_harmonyos_metrics(width, height, scale_factor),
        ),
      )
      true
    }
    None => false
  }
}

///|
pub fn component_gallery_harmonyos_dispatch_pointer(
  phase : Int,
  x : Double,
  y : Double,
  time_ms : Double,
) -> Bool {
  match
    (
      component_gallery_harmonyos_session.val,
      component_gallery_harmonyos_pointer_phase(phase),
    ) {
    (Some(session), Some(pointer_phase)) => {
      let metrics = session.metrics()
      let scale = component_gallery_harmonyos_safe_scale(metrics.scale_factor)
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
pub fn component_gallery_harmonyos_dispatch_scroll(
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  phase : Int,
) -> Bool {
  match component_gallery_harmonyos_session.val {
    Some(session) => {
      let metrics = session.metrics()
      let scale = component_gallery_harmonyos_safe_scale(metrics.scale_factor)
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
pub fn component_gallery_harmonyos_render_frame() -> Bool {
  match component_gallery_harmonyos_session.val {
    Some(session) => {
      ignore(session.render_frame())
      true
    }
    None => false
  }
}

///|
pub fn component_gallery_harmonyos_frame_tick(time_ms : Double) -> Bool {
  match component_gallery_harmonyos_session.val {
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
  match component_gallery_harmonyos_session.val {
    Some(session) => session.drain_host_updates_json()
    None => "[]"
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
      component_gallery_harmonyos_session.val,
      @host.mobile_text_input_response(kind, text, start, end),
    ) {
    (Some(session), Some(response)) => session.dispatch_host_response(response)
    _ => false
  }
}

///|
pub fn moui_mobile_dispatch_command(kind : Int) -> Bool {
  match
    (
      component_gallery_harmonyos_session.val,
      @host.mobile_command_response(kind),
    ) {
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
      component_gallery_harmonyos_session.val,
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
  match component_gallery_harmonyos_session.val {
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
pub fn component_gallery_harmonyos_detach_surface() -> Unit {
  match component_gallery_harmonyos_session.val {
    Some(session) => session.dispose()
    None => ()
  }
  component_gallery_harmonyos_session.val = None
}

///|
fn main {
  println(@harmonyos_skia_backend.harmonyos_skia_provider_preflight_summary())
}
