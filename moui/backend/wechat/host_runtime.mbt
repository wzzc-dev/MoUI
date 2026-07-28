///|
/// WeChat Mini Program host runtime.
/// Provides the run_app entry point for WeChat Mini Program applications.

///|
/// Module-level state for FFI access.
/// After run_app() initializes the runtime, the driver and renderer
/// are stored here so that JS-to-wasm FFI calls can dispatch events
/// and trigger re-renders.
priv struct WechatState {
  mut driver : @runtime.HostRuntimeDriver?
  mut renderer : @canvas2d.Canvas2DRenderer?
  mut needs_render : Bool
}

///|
let state : WechatState = { driver: None, renderer: None, needs_render: false }

///|
pub fn run_app(
  canvas_id~ : String,
  runtime~ : @runtime.AppRuntime,
  logical_width~ : Double,
  logical_height~ : Double,
  scale_factor? : Double = 2.0,
) -> Unit {
  let d = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())

  let renderer_metrics = @render.RendererSurfaceMetrics::new(
    logical_size=@core.Size::new(width=logical_width, height=logical_height),
    physical_size=@core.Size::new(
      width=logical_width * scale_factor,
      height=logical_height * scale_factor,
    ),
    scale_factor~,
  )
  let r = @canvas2d.Canvas2DRenderer::new(canvas_id~)
  r.resize(renderer_metrics)
  d.set_text_system(r.text_system())

  state.driver = Some(d)
  state.renderer = Some(r)
  state.needs_render = true

  // Initial render
  wechat_render_frame()
}

///|
/// WeChat FFI dispatch stubs — called from JS runtime.
/// Maps Mini Program events to MoUI runtime events.
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
/// Dispatch a pointer/touch event from the Mini Program.
/// JS maps touch types: start→Down(1), move→Move(0), end→Up(2).
/// Returns 1 if the app should close, 0 otherwise.
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
    Some(d) => {
      let phase = match kind {
        0 => @core.PointerPhase::Move
        1 => @core.PointerPhase::Down
        2 => @core.PointerPhase::Up
        _ => @core.PointerPhase::Cancel
      }
      let event = @core.PointerEvent::new(
        position=@core.Point::new(x=x_px, y=y_px),
        phase~,
        button~,
        wheel_delta=@core.Point::new(x=delta_x_px, y=delta_y_px),
      )
      let result = d.dispatch(@host.HostEvent::Pointer(event))
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
/// Render a single frame. Called from the JS requestAnimationFrame loop.
/// Only renders when the needs_render flag is set (e.g. after touch/scroll).
pub fn wechat_render_frame() -> Unit {
  if not(state.needs_render) {
    return
  }
  state.needs_render = false
  match state.driver {
    Some(d) => {
      d.begin_redraw()
      d.finish_redraw()
      let commands = d.draw_commands()
      match state.renderer {
        Some(r) => r.render(commands)
        None => ()
      }
    }
    None => ()
  }
}

///|
pub fn wechat_surface_created(
  _width : Double,
  _height : Double,
  _scale_factor : Double,
) -> Unit {

}

///|
pub fn wechat_surface_destroyed() -> Unit {

}

///|
pub fn wechat_app_show() -> Unit {

}

///|
pub fn wechat_app_hide() -> Unit {

}
