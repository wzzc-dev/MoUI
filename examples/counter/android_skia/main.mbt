///|
let android_counter_session : Ref[@android_host.AndroidRuntimeSession?] = Ref(
  None,
)

///|
fn android_counter_metrics(
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
fn android_counter_runtime(
  metrics : @host.HostSurfaceMetrics,
) -> @runtime.AppRuntime {
  @runtime.new_program(
    program=@counter_app.program(),
    size=metrics.logical_size,
  )
}

///|
fn android_counter_pointer_phase(phase : Int) -> @core.PointerPhase? {
  match phase {
    0 => Some(@core.PointerPhase::Down)
    1 => Some(@core.PointerPhase::Move)
    2 => Some(@core.PointerPhase::Up)
    3 => Some(@core.PointerPhase::Cancel)
    _ => None
  }
}

///|
pub fn android_counter_attach_surface(
  surface_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  let metrics = android_counter_metrics(width, height, scale_factor)
  let runtime = android_counter_runtime(metrics)
  match
    @android_skia_backend.create_session(
      runtime~,
      surface=@android_host.AndroidSurfaceHandle::new(raw=surface_handle),
      metrics~,
    ) {
    Some(session) => {
      android_counter_session.val = Some(session)
      true
    }
    None => false
  }
}

///|
pub fn android_counter_resize(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  match android_counter_session.val {
    Some(session) => {
      ignore(
        session.resize(android_counter_metrics(width, height, scale_factor)),
      )
      true
    }
    None => false
  }
}

///|
pub fn android_counter_dispatch_pointer(
  phase : Int,
  x : Double,
  y : Double,
  time_ms : Double,
) -> Bool {
  match (android_counter_session.val, android_counter_pointer_phase(phase)) {
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
pub fn android_counter_render_frame() -> Bool {
  match android_counter_session.val {
    Some(session) => {
      ignore(session.render_frame())
      true
    }
    None => false
  }
}

///|
pub fn android_counter_detach_surface() -> Unit {
  match android_counter_session.val {
    Some(session) => session.dispose()
    None => ()
  }
  android_counter_session.val = None
}

///|
fn main {
  println(@android_skia_backend.android_skia_provider_preflight_summary())
}
