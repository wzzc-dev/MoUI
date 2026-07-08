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
  let runtime = ios_counter_runtime(metrics)
  match
    @ios_skia_backend.create_session(
      runtime~,
      view=@ios_host.IosViewHandle::new(raw=view_handle),
      metrics~,
    ) {
    Some(session) => {
      ios_counter_session.val = Some(session)
      true
    }
    None => false
  }
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
pub fn ios_counter_detach_view() -> Unit {
  match ios_counter_session.val {
    Some(session) => session.dispose()
    None => ()
  }
  ios_counter_session.val = None
}

///|
fn main {
  println(@ios_skia_backend.ios_skia_provider_preflight_summary())
}
