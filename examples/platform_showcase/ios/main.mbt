///|
let platform_showcase_ios_session : Ref[@ios_host.IosRuntimeSession?] = Ref(
  None,
)

///|
fn platform_showcase_ios_metrics(
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
fn platform_showcase_ios_runtime(
  metrics : @host.HostSurfaceMetrics,
) -> @runtime.AppRuntime {
  @runtime.new_program(
    program=@platform_showcase_app.program(
      active_platform=@platform_showcase_app.PlatformId::IOS,
    ),
    size=metrics.logical_size,
  )
}

///|
fn platform_showcase_ios_pointer_phase(phase : Int) -> @core.PointerPhase? {
  match phase {
    0 => Some(@core.PointerPhase::Down)
    1 => Some(@core.PointerPhase::Move)
    2 => Some(@core.PointerPhase::Up)
    3 => Some(@core.PointerPhase::Cancel)
    _ => None
  }
}

///|
pub fn platform_showcase_ios_attach_view(
  view_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  let metrics = platform_showcase_ios_metrics(width, height, scale_factor)
  let runtime = platform_showcase_ios_runtime(metrics)
  match
    @ios_skia_backend.create_session(
      runtime~,
      view=@ios_host.IosViewHandle::new(raw=view_handle),
      metrics~,
    ) {
    Some(session) => {
      platform_showcase_ios_session.val = Some(session)
      true
    }
    None => false
  }
}

///|
pub fn platform_showcase_ios_resize(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  match platform_showcase_ios_session.val {
    Some(session) => {
      ignore(
        session.resize(
          platform_showcase_ios_metrics(width, height, scale_factor),
        ),
      )
      true
    }
    None => false
  }
}

///|
pub fn platform_showcase_ios_dispatch_pointer(
  phase : Int,
  x : Double,
  y : Double,
  time_ms : Double,
) -> Bool {
  match
    (
      platform_showcase_ios_session.val,
      platform_showcase_ios_pointer_phase(phase),
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
pub fn platform_showcase_ios_dispatch_scroll(
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  phase : Int,
) -> Bool {
  match platform_showcase_ios_session.val {
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
pub fn platform_showcase_ios_render_frame() -> Bool {
  match platform_showcase_ios_session.val {
    Some(session) => {
      ignore(session.render_frame())
      true
    }
    None => false
  }
}

///|
pub fn platform_showcase_ios_detach_view() -> Unit {
  match platform_showcase_ios_session.val {
    Some(session) => session.dispose()
    None => ()
  }
  platform_showcase_ios_session.val = None
}

///|
fn main {
  println(@ios_skia_backend.ios_skia_provider_preflight_summary())
}
