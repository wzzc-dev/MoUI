///|
extern "C" fn win32_surface_host_hinstance() -> @wgpu_c.OpaquePtr = "moui_windows_surface_host_hinstance"

///|
extern "C" fn win32_surface_host_hwnd_from_u64(
  hwnd : UInt64,
) -> @wgpu_c.OpaquePtr = "moui_windows_surface_host_hwnd_from_u64"

///|
struct WindowsApp {
  title : String
  mut window : @win.Window?
  mut renderer : @wgpu_renderer.WgpuRenderer?
  runtime : @core.AppRuntime
  driver : @host.HostRuntimeDriver
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
}

///|
pub fn run_app(title : String, runtime : @core.AppRuntime) -> Unit {
  let event_loop = @win.EventLoop::new()
  let app = WindowsApp::{
    title,
    window: None,
    renderer: None,
    runtime,
    driver: @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
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
  @common.window_event_to_core(event, last_pointer)
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
  @common.window_event_to_host(event, last_pointer)
}

///|
pub fn window_event_to_host_with_modifiers(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
  modifiers : @core.KeyModifiers,
) -> @host.HostEvent? {
  @common.window_event_to_host_with_modifiers(event, last_pointer, modifiers)
}

///|
pub fn create_windows_host_surface(
  hwnd : UInt64,
) -> @wgpu_renderer.HostWgpuSurface raise @wgpu.WgpuError {
  let instance = @wgpu.Instance::create()
  let surface = instance.create_surface_windows_hwnd(
    win32_surface_host_hinstance(),
    win32_surface_host_hwnd_from_u64(hwnd),
  )
  @wgpu_renderer.HostWgpuSurface::new(instance~, surface~)
}

///|
pub fn windows_surface_host_info() -> @wgpu_renderer.SurfaceHostInfo {
  {
    platform: "windows",
    owns_instance: true,
    description: "Windows backend owns HWND surface creation and passes HostWgpuSurface to render/wgpu.",
  }
}

///|
pub impl @win.ApplicationHandler for WindowsApp with can_create_surfaces(
  self,
  event_loop,
) {
  let initial_size = @dpi.PhysicalSize::new(
    size_dim_to_int(self.runtime.size().width),
    size_dim_to_int(self.runtime.size().height),
  )
  let attributes = @window_core.WindowAttributes::default()
    .with_title(self.title)
    .with_surface_size(initial_size.into_size())
  let window : @win.Window? = Some(event_loop.try_create_window(attributes)) catch {
    err => {
      println("error creating Windows window: \{err}")
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      let size = @common.physical_size_to_core(window.surface_size())
      ignore(
        self.driver.dispatch(
          @host.HostEvent::Resized(
            @host.HostSurfaceMetrics::new(logical_size=size, physical_size=size),
          ),
        ),
      )
      let renderer : @wgpu_renderer.WgpuRenderer? = Some(
        @wgpu_renderer.create_with_host_surface(
          size,
          create_windows_host_surface(window.window_handle()),
        ),
      ) catch {
        err => {
          println("error creating Windows WGPU renderer: \{err.message()}")
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
pub impl @win.ApplicationHandler for WindowsApp with window_event(
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
          renderer.resize(self.runtime.size())
          window.request_redraw()
        }
        _ => ()
      }
    }
    @window_core.WindowEvent::PointerMoved(_, position, _, _) => {
      self.last_pointer = @common.physical_position_to_core(position)
      self.dispatch_window_event(event)
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = @common.physical_position_to_core(position)
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
        }
        _ => ()
      }
    _ => self.dispatch_window_event(event)
  }
}

///|
fn WindowsApp::dispatch_window_event(
  self : WindowsApp,
  event : @window_core.WindowEvent,
) -> Unit {
  match event {
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      self.modifiers = @common.modifiers_to_core(modifiers)
    _ => ()
  }
  match
    window_event_to_host_with_modifiers(
      event,
      self.last_pointer,
      self.modifiers,
    ) {
    Some(host_event) => ignore(self.driver.dispatch(host_event))
    None => ()
  }
}

///|
fn WindowsApp::request_redraw(self : WindowsApp) -> Unit {
  if self.runtime.needs_redraw() {
    match self.window {
      Some(window) => window.request_redraw()
      None => ()
    }
  }
}

///|
fn WindowsApp::dispose(self : WindowsApp) -> Unit {
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
