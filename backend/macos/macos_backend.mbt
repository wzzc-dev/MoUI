///|
extern "C" fn macos_surface_host_layer_from_view(
  raw_view_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> @wgpu_c.OpaquePtr = "moui_macos_surface_host_layer_from_view"

///|
pub(all) struct MacosBackendInfo {
  host_info : @host.HostAppInfo
  renderer_ready : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
struct MacosApp {
  title : String
  mut window : @window_macos.Window?
  mut renderer : @wgpu_renderer.WgpuRenderer?
  runtime : @core.AppRuntime
  driver : @host.HostRuntimeDriver
  text_input_session : @host.TextInputSession
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
}

///|
pub fn backend_info() -> MacosBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="macOS AppKit window host with CAMetalLayer wgpu surface",
    ),
    renderer_ready: true,
    description: "macOS backend uses Milky2018/window/macos for AppKit events and installs a CAMetalLayer on the window NSView for render/wgpu.",
  }
}

///|
pub fn run_app(title : String, runtime : @core.AppRuntime) -> Unit {
  let event_loop = @window_macos.EventLoop::new()
  let app = MacosApp::{
    title,
    window: None,
    renderer: None,
    runtime,
    driver: @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    text_input_session: @host.TextInputSession::new(),
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
  }
  app.driver.set_redraw_scheduler(() => app.request_redraw())
  event_loop.run_app(app)
}

///|
pub fn window_event_to_core(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
) -> @core.AppEvent? {
  @host.window_event_to_core(event, last_pointer)
}

///|
pub fn window_event_to_core_with_modifiers(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
  modifiers : @core.KeyModifiers,
) -> @core.AppEvent? {
  match window_event_to_host_with_modifiers(event, last_pointer, modifiers) {
    Some(host_event) => host_event.to_core()
    None => None
  }
}

///|
pub fn window_event_to_host(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
) -> @host.HostEvent? {
  @host.window_event_to_host(event, last_pointer)
}

///|
pub fn window_event_to_host_with_modifiers(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
  modifiers : @core.KeyModifiers,
  scale_factor? : Double = 1.0,
) -> @host.HostEvent? {
  @host.window_event_to_host_with_modifiers(
    event,
    last_pointer,
    modifiers,
    scale_factor~,
  )
}

///|
pub fn create_macos_host_surface(
  raw_view_handle : UInt64,
  size : @core.Size,
  scale_factor? : Double = 1.0,
) -> @wgpu_renderer.HostWgpuSurface raise @wgpu.WgpuError {
  let instance = @wgpu.Instance::create()
  let layer = macos_surface_host_layer_from_view(
    raw_view_handle,
    size_dim_to_int(size.width),
    size_dim_to_int(size.height),
    scale_factor,
  )
  let desc = @wgpu.surface_descriptor_metal_layer_new(layer)
  let surface = instance.create_surface(desc)
  @wgpu.surface_descriptor_free(desc)
  @wgpu_renderer.HostWgpuSurface::new(instance~, surface~)
}

///|
pub fn macos_surface_host_info() -> @wgpu_renderer.SurfaceHostInfo {
  {
    platform: "macos",
    owns_instance: true,
    description: "macOS backend installs a CAMetalLayer on the window NSView and passes HostWgpuSurface to render/wgpu.",
  }
}

///|
fn runtime_size_to_window_surface_size(size : @core.Size) -> @dpi.Size {
  @dpi.LogicalSize::new(size.width, size.height).into_size()
}

///|
pub impl @window_macos.ApplicationHandler for MacosApp with can_create_surfaces(
  self,
  event_loop,
) {
  let attributes = @window_core.WindowAttributes::default()
    .with_title(self.title)
    .with_surface_size(runtime_size_to_window_surface_size(self.runtime.size()))
  let window : @window_macos.Window? = Some(
    event_loop.try_create_window(attributes),
  ) catch {
    err => {
      println("error creating macOS window: \{err}")
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      let metrics = @host.surface_metrics_from_physical(
        window.surface_size(),
        scale_factor=window.scale_factor(),
      )
      ignore(self.driver.dispatch(@host.HostEvent::Resized(metrics)))
      let renderer : @wgpu_renderer.WgpuRenderer? = Some(
        @wgpu_renderer.create_with_host_surface(
          renderer_metrics_from_host(metrics),
          create_macos_host_surface(
            window.window_handle(),
            metrics.physical_size,
            scale_factor=metrics.scale_factor,
          ),
        ),
      ) catch {
        err => {
          println("error creating macOS WGPU renderer: \{err.message()}")
          event_loop.exit()
          None
        }
      }
      self.renderer = renderer
      self.window = Some(window)
      window.request_redraw()
    }
    None => ()
  }
}

///|
pub impl @window_macos.ApplicationHandler for MacosApp with window_event(
  self,
  event_loop,
  _window_id,
  event,
) {
  match event {
    @window_core.WindowEvent::CloseRequested => {
      self.dispatch_window_event(event)
      self.dispose()
      event_loop.exit()
    }
    @window_core.WindowEvent::SurfaceResized(_) => {
      self.dispatch_window_event(event)
      match (self.window, self.renderer) {
        (Some(window), Some(renderer)) => {
          let metrics = @host.surface_metrics_from_physical(
            window.surface_size(),
            scale_factor=window.scale_factor(),
          )
          renderer.resize(renderer_metrics_from_host(metrics))
          window.request_redraw()
        }
        _ => ()
      }
    }
    @window_core.WindowEvent::ScaleFactorChanged(_, _) => {
      self.dispatch_window_event(event)
      match (self.window, self.renderer) {
        (Some(window), Some(renderer)) => {
          let metrics = @host.surface_metrics_from_physical(
            window.surface_size(),
            scale_factor=window.scale_factor(),
          )
          renderer.resize(renderer_metrics_from_host(metrics))
          window.request_redraw()
        }
        _ => ()
      }
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
    @window_core.WindowEvent::KeyboardInput(_, _, _) =>
      self.dispatch_window_event(event)
    @window_core.WindowEvent::Ime(_) => self.dispatch_window_event(event)
    @window_core.WindowEvent::ModifiersChanged(_) =>
      self.dispatch_window_event(event)
    @window_core.WindowEvent::RedrawRequested =>
      match (self.window, self.renderer) {
        (Some(window), Some(renderer)) => {
          window.pre_present_notify()
          self.driver.begin_redraw()
          renderer.render(self.driver.draw_commands())
          self.driver.finish_redraw()
          self.sync_text_input_session()
        }
        _ => ()
      }
    _ => self.dispatch_window_event(event)
  }
}

///|
fn renderer_metrics_from_host(
  metrics : @host.HostSurfaceMetrics,
) -> @render.RendererSurfaceMetrics {
  @render.RendererSurfaceMetrics::new(
    logical_size=metrics.logical_size,
    physical_size=metrics.physical_size,
    scale_factor=metrics.scale_factor,
  )
}

///|
fn MacosApp::dispatch_window_event(
  self : MacosApp,
  event : @window_core.WindowEvent,
) -> Unit {
  match event {
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      self.modifiers = @host.modifiers_to_core(modifiers)
    _ => ()
  }
  let scale_factor = self.current_scale_factor()
  match
    window_event_to_host_with_modifiers(
      event,
      self.last_pointer,
      self.modifiers,
      scale_factor~,
    ) {
    Some(host_event) => {
      ignore(self.driver.dispatch(host_event))
      self.sync_text_input_session()
    }
    None => ()
  }
}

///|
fn MacosApp::sync_text_input_session(self : MacosApp) -> Unit {
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
fn MacosApp::current_scale_factor(self : MacosApp) -> Double {
  match self.window {
    Some(window) => window.scale_factor()
    None => 1.0
  }
}

///|
fn MacosApp::request_redraw(self : MacosApp) -> Unit {
  if self.runtime.needs_redraw() {
    match self.window {
      Some(window) => window.request_redraw()
      None => ()
    }
  }
}

///|
fn MacosApp::dispose(self : MacosApp) -> Unit {
  match self.renderer {
    Some(renderer) => renderer.dispose()
    None => ()
  }
  match self.window {
    Some(window) => window.drop()
    None => ()
  }
  self.renderer = None
  self.window = None
}

///|
fn size_dim_to_int(value : Double) -> Int {
  if value < 1.0 {
    1
  } else {
    value.to_int()
  }
}
