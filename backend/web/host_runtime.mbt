///|
pub(all) struct WebBackendInfo {
  host_info : @host.HostAppInfo
  uses_window_web_backend : Bool
  requires_browser_webgpu_renderer : Bool
  renderer_info : @render.RendererBackendInfo
  surface_contract : @render.WgpuSurfaceContract
  description : String
} derive(Eq, Debug, ToJson)

///|
struct WebApp {
  title : String
  mut window : @window_web.Window?
  runtime : @core.AppRuntime
  driver : @host.HostRuntimeDriver
  text_input_session : @host.TextInputSession
  mut renderer : WebRenderer?
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
}

///|
pub fn backend_info() -> WebBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Web,
      description="canonical Milky2018/window web host for wasm-gc WebGPU",
    ),
    uses_window_web_backend: true,
    requires_browser_webgpu_renderer: true,
    renderer_info: webgpu_renderer_backend_info(),
    surface_contract: webgpu_canvas_surface_contract(),
    description: "Canonical web path: window/web owns canvas events and redraw scheduling on wasm-gc; rendering is provided by the browser WebGPU host import module. No JS target fallback is kept.",
  }
}

///|
pub fn renderer_backend_info() -> @render.RendererBackendInfo {
  webgpu_renderer_backend_info()
}

///|
pub fn wasm_renderer_ready() -> Bool {
  true
}

///|
pub fn canvas_surface_contract() -> @render.WgpuSurfaceContract {
  webgpu_canvas_surface_contract()
}

///|
pub fn run_app(title : String, runtime : @core.AppRuntime) -> Unit {
  let event_loop = @window_web.EventLoop::new()
  event_loop.set_control_flow(@window_core.ControlFlow::Poll)
  let app = WebApp::{
    title,
    window: None,
    runtime,
    driver: @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    text_input_session: @host.TextInputSession::new(),
    renderer: None,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
  }
  app.driver.set_redraw_scheduler(() => app.request_redraw())
  event_loop.spawn_app(app)
}

///|
pub fn window_event_to_host(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
) -> @host.HostEvent? {
  window_event_to_host_with_modifiers(
    event,
    last_pointer,
    @core.KeyModifiers::none(),
  )
}

///|
pub fn window_event_to_host_with_modifiers(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
  modifiers : @core.KeyModifiers,
) -> @host.HostEvent? {
  @host.window_event_to_host_with_modifiers(
    event,
    last_pointer,
    modifiers,
    scale_factor=1.0,
  )
}

///|
fn window_event_to_host_with_scale(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
  modifiers : @core.KeyModifiers,
  scale_factor~ : Double,
) -> @host.HostEvent? {
  @host.window_event_to_host_with_modifiers(
    event,
    last_pointer,
    modifiers,
    scale_factor~,
    blur_to_cancel=true,
  )
}

///|
fn window_web_default_canvas_id(raw_id : Int) -> String {
  "moonbit-window-web-\{raw_id}"
}

///|
pub impl @window_web.ApplicationHandler for WebApp with can_create_surfaces(
  self,
  event_loop,
) {
  let initial_size = @dpi.LogicalSize::new(
    self.runtime.size().width,
    self.runtime.size().height,
  )
  let attributes = @window_core.WindowAttributes::default()
    .with_title(self.title)
    .with_surface_size(initial_size.into_size())
  let window : @window_web.Window? = Some(
    event_loop.try_create_window(attributes),
  ) catch {
    err => {
      let _ = err
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      let metrics = surface_metrics_from_physical(
        window.surface_size(),
        window.scale_factor(),
      )
      let renderer_result = try? WebRenderer::create(
        canvas_id=window_web_default_canvas_id(window.id().into_raw()),
        metrics~,
      )
      match renderer_result {
        Ok(renderer) => {
          ignore(self.driver.dispatch(@host.HostEvent::Resized(metrics)))
          self.renderer = Some(renderer)
          self.window = Some(window)
          window.request_redraw()
        }
        Err(err) => {
          let _ = err
          window.drop()
          event_loop.exit()
        }
      }
    }
    None => ()
  }
}

///|
pub impl @window_web.ApplicationHandler for WebApp with new_events(
  self,
  _event_loop,
  _cause,
) {
  match self.renderer {
    Some(_) => if self.runtime.needs_redraw() { self.redraw() }
    None => ()
  }
}

///|
pub impl @window_web.ApplicationHandler for WebApp with window_event(
  self,
  event_loop,
  _window_id,
  event,
) {
  match event {
    @window_core.WindowEvent::CloseRequested => {
      self.dispatch_window_event(event)
      match self.renderer {
        Some(renderer) => renderer.dispose()
        None => ()
      }
      self.renderer = None
      match self.window {
        Some(window) => window.drop()
        None => ()
      }
      self.window = None
      event_loop.exit()
    }
    @window_core.WindowEvent::SurfaceResized(_) => {
      self.dispatch_window_event(event)
      self.request_redraw()
    }
    @window_core.WindowEvent::ScaleFactorChanged(_, _) => {
      self.dispatch_window_event(event)
      self.request_redraw()
    }
    @window_core.WindowEvent::PointerMoved(_, position, _, _) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(),
      )
      self.dispatch_window_event(event)
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(),
      )
      self.dispatch_window_event(event)
    }
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      self.modifiers = @host.modifiers_to_core(modifiers)
    @window_core.WindowEvent::RedrawRequested => self.redraw()
    _ => self.dispatch_window_event(event)
  }
}

///|
fn WebApp::redraw(self : WebApp) -> Unit {
  self.driver.begin_redraw()
  match self.renderer {
    Some(renderer) =>
      renderer.render(self.driver.draw_commands()) catch {
        err => {
          let _ = err
        }
      }
    None => ()
  }
  self.driver.finish_redraw()
  self.sync_text_input_session()
}

///|
fn WebApp::dispatch_window_event(
  self : WebApp,
  event : @window_core.WindowEvent,
) -> Unit {
  match
    window_event_to_host_with_scale(
      event,
      self.last_pointer,
      self.modifiers,
      scale_factor=self.current_scale_factor(),
    ) {
    Some(host_event) => {
      match host_event {
        @host.HostEvent::Resized(metrics) => self.resize_renderer(metrics)
        _ => ()
      }
      ignore(self.driver.dispatch(host_event))
      self.sync_text_input_session()
    }
    None => ()
  }
}

///|
fn WebApp::sync_text_input_session(self : WebApp) -> Unit {
  match self.window {
    Some(window) =>
      match self.text_input_session.sync(self.runtime.focused_text_input()) {
        @host.TextInputSessionAction::EnableIme(request)
        | @host.TextInputSessionAction::UpdateIme(request)
        | @host.TextInputSessionAction::DisableIme(request) =>
          window.request_ime_update(request) catch {
            _ => ()
          }
        @host.TextInputSessionAction::NoImeChange => ()
      }
    None => ()
  }
}

///|
fn WebApp::current_scale_factor(self : WebApp) -> Double {
  match self.window {
    Some(window) => window.scale_factor()
    None => 1.0
  }
}

///|
fn WebApp::resize_renderer(
  self : WebApp,
  metrics : @host.HostSurfaceMetrics,
) -> Unit {
  match self.renderer {
    Some(renderer) =>
      renderer.resize(metrics) catch {
        err => {
          let _ = err
        }
      }
    None => ()
  }
}

///|
fn WebApp::request_redraw(self : WebApp) -> Unit {
  if self.runtime.needs_redraw() {
    match self.window {
      Some(window) => window.request_redraw()
      None => ()
    }
  }
}

///|
fn surface_metrics_from_physical(
  size : @dpi.PhysicalSize,
  scale_factor : Double,
) -> @host.HostSurfaceMetrics {
  @host.surface_metrics_from_physical(size, scale_factor~)
}

///|
pub fn web_dispatch_event(
  kind : Int,
  raw_id : Int,
  arg0 : Int,
  arg1 : Int,
  argd : Double,
  text_id : Int,
) -> Unit {
  @window_web.web_dispatch_event_by_id(kind, raw_id, arg0, arg1, argd, text_id)
}
