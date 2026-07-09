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
fn component_gallery_harmonyos_runtime(
  metrics : @host.HostSurfaceMetrics,
) -> @runtime.AppRuntime {
  @runtime.new_program(
    program=@component_gallery_app.program(
      active_platform=@component_gallery_app.PlatformId::HarmonyOs,
    ),
    size=metrics.logical_size,
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
    ) {
    Some(session) => {
      component_gallery_harmonyos_session.val = Some(session)
      true
    }
    None => false
  }
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
