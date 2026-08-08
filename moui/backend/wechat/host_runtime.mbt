///|
/// WeChat Mini Program host runtime state. Concrete rendering remains behind
/// the neutral host renderer selected from application-supplied factories.
priv struct WechatState {
  mut driver : @runtime.HostRuntimeDriver?
  mut surface : @render.RendererSession?
  mut renderer_providers : Array[@render.RendererProvider]
  mut surface_id : String
  mut needs_render : Bool
  mut surface_generation : Int
  mut next_sequence : Int
}

///|
let state : WechatState = {
  driver: None,
  surface: None,
  renderer_providers: [],
  surface_id: "",
  needs_render: false,
  surface_generation: 0,
  next_sequence: 1,
}

///|
pub(all) struct WechatAppOptions {
  canvas_id : String
  logical_width : Double
  logical_height : Double
  scale_factor : Double
}

///|
pub fn WechatAppOptions::new(
  canvas_id~ : String,
  logical_width~ : Double,
  logical_height~ : Double,
  scale_factor? : Double = 2.0,
) -> WechatAppOptions {
  { canvas_id, logical_width, logical_height, scale_factor }
}

///|
pub fn entry(options : WechatAppOptions) -> @runtime.PlatformEntry {
  @runtime.PlatformEntry::new(id="wechat", launch=request => {
    run_app_internal(request.runtime(), request.renderer_providers(), options)
  })
}

///|
fn run_app_internal(
  runtime : @runtime.AppRuntime,
  renderer_providers : Array[@render.RendererProvider],
  options : WechatAppOptions,
) -> Unit {
  state.driver = Some(
    @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
      state.needs_render = true
    }),
  )
  state.renderer_providers = renderer_providers
  state.surface_id = options.canvas_id
  state.attach_surface(
    options.logical_width,
    options.logical_height,
    options.scale_factor,
  )
  wechat_render_frame()
}

///|
fn WechatState::attach_surface(
  self : WechatState,
  logical_width : Double,
  logical_height : Double,
  scale_factor : Double,
) -> Unit {
  let metrics = @core.SurfaceMetrics::new(
    logical_size=@core.Size::new(width=logical_width, height=logical_height),
    physical_size=@core.Size::new(
      width=logical_width * scale_factor,
      height=logical_height * scale_factor,
    ),
    scale_factor~,
  )
  let host_surface = @render.HostSurface::new(
    surface_id=self.surface_id,
    metrics~,
  )
  match @render_common.resolve_renderer(self.renderer_providers, host_surface) {
    Some(resolution) => {
      match self.surface {
        Some(surface) => surface.dispose()
        None => ()
      }
      let surface = resolution
      self.surface = Some(surface)
      match self.driver {
        Some(driver) => driver.set_text_system(surface.text_system())
        None => ()
      }
      self.needs_render = true
      self.surface_generation = self.surface_generation + 1
      self.next_sequence = 1
    }
    None => abort("wechat backend: no renderer accepts the host canvas surface")
  }
}

///|
pub fn wechat_dispatch_event(
  _kind : Int,
  _raw_id : Int,
  _arg0 : Int,
  _arg1 : Int,
  _argd : Double,
  _text_id : Int,
) -> Unit {

}

///|
pub fn wechat_dispatch_pointer_input(
  raw_id : Int,
  kind : Int,
  x_px : Double,
  y_px : Double,
  delta_x_px : Double,
  delta_y_px : Double,
  button : Int,
  modifiers : Int,
) -> Int {
  let _ = raw_id
  let _ = modifiers
  match state.driver {
    Some(driver) => {
      let phase = match kind {
        0 => @core.PointerPhase::Move
        1 => @core.PointerPhase::Down
        2 => @core.PointerPhase::Up
        _ => @core.PointerPhase::Cancel
      }
      let result = driver.dispatch(
        @host.Event::Pointer(
          @core.PointerEvent::new(
            position=@core.Point::new(x=x_px, y=y_px),
            phase~,
            button~,
            wheel_delta=@core.Point::new(x=delta_x_px, y=delta_y_px),
          ),
        ),
      )
      if result.needs_redraw {
        state.needs_render = true
      }
      if result.close_requested {
        1
      } else {
        0
      }
    }
    None => 0
  }
}

///|
pub fn wechat_render_frame() -> Unit {
  if !state.needs_render {
    return
  }
  state.needs_render = false
  match (state.driver, state.surface) {
    (Some(driver), Some(surface)) => {
      driver.begin_redraw()
      let draw_frame = driver.draw_frame()
      let token = @render.FrameToken::new(
        surface_generation=state.surface_generation,
        sequence=state.next_sequence,
      )
      state.next_sequence = state.next_sequence + 1
      let result = surface.render_frame(
        @render.RenderFrameSubmission::new(token~, frame=draw_frame),
      )
      ignore(result)
      driver.finish_redraw()
    }
    _ => ()
  }
}

///|
pub fn wechat_surface_created(
  width : Double,
  height : Double,
  scale_factor : Double,
) -> Unit {
  state.attach_surface(width, height, scale_factor)
}

///|
pub fn wechat_surface_destroyed() -> Unit {
  match state.surface {
    Some(surface) => surface.dispose()
    None => ()
  }
  state.surface = None
}

///|
pub fn wechat_app_show() -> Unit {
  state.needs_render = true
}

///|
pub fn wechat_app_hide() -> Unit {
  ()
}
