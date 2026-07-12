///|
let harmonyos_demo_session : Ref[@harmonyos_host.HarmonyOsRuntimeSession?] = Ref(
  None,
)

///|
fn harmonyos_demo_safe_scale(scale_factor : Double) -> Double {
  if scale_factor > 0.0 {
    scale_factor
  } else {
    1.0
  }
}

///|
fn harmonyos_demo_metrics(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> @host.HostSurfaceMetrics {
  let scale = harmonyos_demo_safe_scale(scale_factor)
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
fn harmonyos_demo_runtime(
  metrics : @host.HostSurfaceMetrics,
) -> @runtime.AppRuntime {
  @runtime.new_program(
    program=@harmonyos_demo_app.program(),
    size=metrics.logical_size,
  )
}

///|
fn harmonyos_demo_pointer_phase(phase : Int) -> @core.PointerPhase? {
  match phase {
    0 => Some(@core.PointerPhase::Down)
    1 => Some(@core.PointerPhase::Move)
    2 => Some(@core.PointerPhase::Up)
    3 => Some(@core.PointerPhase::Cancel)
    _ => None
  }
}

///|
pub fn harmonyos_demo_attach_surface(
  surface_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  harmonyos_demo_detach_surface()
  let metrics = harmonyos_demo_metrics(width, height, scale_factor)
  let runtime = harmonyos_demo_runtime(metrics)
  match
    @harmonyos_skia_backend.create_session(
      runtime~,
      surface=@harmonyos_host.HarmonyOsSurfaceHandle::new(raw=surface_handle),
      metrics~,
    ) {
    Some(session) => {
      harmonyos_demo_session.val = Some(session)
      true
    }
    None => false
  }
}

///|
pub fn harmonyos_demo_resize(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  match harmonyos_demo_session.val {
    Some(session) => {
      ignore(
        session.resize(harmonyos_demo_metrics(width, height, scale_factor)),
      )
      true
    }
    None => false
  }
}

///|
pub fn harmonyos_demo_dispatch_pointer(
  phase : Int,
  x : Double,
  y : Double,
  time_ms : Double,
) -> Bool {
  match (harmonyos_demo_session.val, harmonyos_demo_pointer_phase(phase)) {
    (Some(session), Some(pointer_phase)) => {
      let metrics = session.metrics()
      let scale = harmonyos_demo_safe_scale(metrics.scale_factor)
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
pub fn harmonyos_demo_render_frame() -> Bool {
  match harmonyos_demo_session.val {
    Some(session) => {
      ignore(session.render_frame())
      true
    }
    None => false
  }
}

///|
pub fn harmonyos_demo_frame_tick(time_ms : Double) -> Bool {
  match harmonyos_demo_session.val {
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
  match harmonyos_demo_session.val {
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
      harmonyos_demo_session.val,
      @host.mobile_text_input_response(kind, text, start, end),
    ) {
    (Some(session), Some(response)) => session.dispatch_host_response(response)
    _ => false
  }
}

///|
pub fn moui_mobile_dispatch_command(kind : Int) -> Bool {
  match (harmonyos_demo_session.val, @host.mobile_command_response(kind)) {
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
      harmonyos_demo_session.val,
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
  match harmonyos_demo_session.val {
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
pub fn harmonyos_demo_detach_surface() -> Unit {
  match harmonyos_demo_session.val {
    Some(session) => session.dispose()
    None => ()
  }
  harmonyos_demo_session.val = None
}

///|
fn main {
  println(@harmonyos_skia_backend.harmonyos_skia_provider_preflight_summary())
}
