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
  services : @host.HostServiceBridge
  async_services : @host.HostServiceAsyncQueue
  window_requests : @host.HostWindowRequestQueue
  windows : @host.HostWindowRegistry
  runtime_slots : @host.HostWindowRuntimeSlots
  mut window_id : @host.HostWindowId?
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
  run_app_with_window_requests(
    title,
    runtime,
    @host.HostWindowRequestQueue::new(),
  )
}

///|
pub fn run_app_with_window_requests(
  title : String,
  runtime : @core.AppRuntime,
  window_requests : @host.HostWindowRequestQueue,
) -> Unit {
  let event_loop = @window_web.EventLoop::new()
  event_loop.set_control_flow(@window_core.ControlFlow::Poll)
  let async_services = @host.HostServiceAsyncQueue::new()
  set_web_async_host_service_queue(Some(async_services))
  let services = web_service_bridge(
    system_theme=match event_loop.system_theme() {
      Some(theme) => @host.window_theme_to_color_scheme(theme)
      None => @core.ColorScheme::Light
    },
    open_url=dispatch_web_open_url,
    clipboard=true,
    clipboard_read=true,
    clipboard_write=dispatch_web_clipboard_write_text,
    file_dialog=true,
    async_queue=Some(async_services),
  )
  runtime.set_environment(
    services.environment_with_system_theme(runtime.environment()),
  )
  let app = WebApp::{
    title,
    window: None,
    runtime,
    driver: @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    text_input_session: @host.TextInputSession::new(),
    services,
    async_services,
    window_requests,
    windows: @host.HostWindowRegistry::new(),
    runtime_slots: @host.HostWindowRuntimeSlots::new(),
    window_id: None,
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
  let initial_size = @dpi.LogicalSize::LogicalSize(
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
      let window_id = self.windows.open(
        title=self.title,
        metrics~,
        primary=true,
      )
      self.window_id = Some(window_id)
      self.register_primary_runtime_slot(window_id)
      let renderer_result = try? WebRenderer::create(
        canvas_id=window_web_default_canvas_id(window.id().into_raw()),
        metrics~,
      )
      match renderer_result {
        Ok(renderer) => {
          self.runtime.set_text_system(renderer.text_system())
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
  event_loop,
  _cause,
) {
  self.drain_window_requests(event_loop)
  if event_loop.exiting() {
    return ()
  }
  self.drain_async_host_services()
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
  self.drain_window_requests(event_loop)
  if event_loop.exiting() {
    return ()
  }
  match event {
    @window_core.WindowEvent::CloseRequested => {
      self.dispatch_window_event(event)
      self.dispose()
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
      self.dispatch_pointer_or_context_menu(event)
    }
    @window_core.WindowEvent::DragEntered(_, position)
    | @window_core.WindowEvent::DragMoved(position)
    | @window_core.WindowEvent::DragDropped(_, position) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(),
      )
      self.dispatch_window_event(event)
    }
    @window_core.WindowEvent::DragLeft(Some(position)) => {
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
fn WebApp::dispatch_pointer_or_context_menu(
  self : WebApp,
  event : @window_core.WindowEvent,
) -> Unit {
  if @host.window_event_is_context_menu_button(event) {
    if @host.window_event_is_context_menu_trigger(event) {
      ignore(self.driver.show_context_menu(self.services))
      self.drain_async_host_services()
      self.sync_text_input_session()
    }
  } else {
    self.dispatch_window_event(event)
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
  self.modifiers = web_modifiers_after_window_event(self.modifiers, event)
  match
    window_event_to_host_with_scale(
      event,
      self.last_pointer,
      self.modifiers,
      scale_factor=self.current_scale_factor(),
    ) {
    Some(host_event) => {
      self.apply_window_lifecycle(host_event)
      match host_event {
        @host.HostEvent::Resized(metrics) => {
          self.resize_renderer(metrics)
          ignore(self.driver.dispatch(host_event))
        }
        @host.HostEvent::Keyboard(event) =>
          ignore(
            self.driver.dispatch_keyboard_with_services(event, self.services),
          )
        _ => ignore(self.driver.dispatch(host_event))
      }
      self.drain_async_host_services()
      self.sync_text_input_session()
    }
    None => ()
  }
}

///|
fn WebApp::drain_async_host_services(self : WebApp) -> Unit {
  for request in drain_web_async_host_service_requests(self.async_services) {
    dispatch_web_async_host_service_request(request)
  }
  for completion in self.async_services.drain_completed() {
    ignore(self.driver.dispatch_service_completion(completion, self.services))
  }
}

///|
fn WebApp::drain_window_requests(
  self : WebApp,
  event_loop : @window_web.ActiveEventLoop,
) -> Unit {
  ignore(
    self.window_requests.drain_with_handler(request => {
      self.apply_window_request(event_loop, request)
    }),
  )
}

///|
fn WebApp::apply_window_request(
  self : WebApp,
  event_loop : @window_web.ActiveEventLoop,
  request : @host.HostWindowRequest,
) -> @host.HostWindowRequestResult {
  match request {
    @host.HostWindowRequest::OpenWindow(_) =>
      @host.HostWindowRequestResult::WindowRejected(
        "open window requests require multi-window Web host support",
      )
    @host.HostWindowRequest::FocusWindow(id) =>
      self.apply_current_window_request(id, request, window => {
        window.focus_window()
      })
    @host.HostWindowRequest::CloseWindow(id) =>
      self.apply_current_window_request(id, request, _window => {
        self.dispose()
        event_loop.exit()
      })
    @host.HostWindowRequest::ResizeWindow(id, metrics) =>
      self.apply_current_window_request(id, request, window => {
        ignore(window.request_surface_size(host_metrics_to_dpi_size(metrics)))
        self.resize_renderer(metrics)
        window.request_redraw()
      })
    @host.HostWindowRequest::MinimizeWindow(id) =>
      self.apply_current_window_request(id, request, window => {
        window.set_minimized(true)
      })
    @host.HostWindowRequest::ShowWindow(id) =>
      self.apply_current_window_request(id, request, window => {
        window.set_minimized(false)
        window.set_visible(true)
      })
    @host.HostWindowRequest::SetPrimaryWindow(id) =>
      self.apply_current_window_request(id, request, _window => ())
  }
}

///|
fn WebApp::apply_current_window_request(
  self : WebApp,
  id : @host.HostWindowId,
  request : @host.HostWindowRequest,
  apply : (@window_web.Window) -> Unit,
) -> @host.HostWindowRequestResult {
  match (self.window_id, self.window) {
    (Some(current), Some(window)) =>
      if current == id {
        let result = self.windows.apply_request(request)
        match result {
          @host.HostWindowRequestResult::WindowRejected(_) => ()
          _ => {
            self.sync_runtime_slot(id)
            apply(window)
          }
        }
        result
      } else {
        self.windows.apply_request(request)
      }
    _ =>
      @host.HostWindowRequestResult::WindowRejected(
        "window request has no active Web window",
      )
  }
}

///|
fn web_modifiers_after_window_event(
  current : @core.KeyModifiers,
  event : @window_core.WindowEvent,
) -> @core.KeyModifiers {
  match event {
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      @host.modifiers_to_core(modifiers)
    @window_core.WindowEvent::KeyboardInput(_, key_event, false) =>
      web_modifiers_after_key_event(current, key_event)
    _ => current
  }
}

///|
fn web_modifiers_after_key_event(
  current : @core.KeyModifiers,
  event : @window_core.KeyEvent,
) -> @core.KeyModifiers {
  let pressed = @host.element_state_pressed(event.state())
  match event.logical_key() {
    @window_core.Key::Named(@window_core.NamedKey::Shift) =>
      { ..current, shift: pressed }
    @window_core.Key::Named(@window_core.NamedKey::Control) =>
      { ..current, control: pressed }
    @window_core.Key::Named(@window_core.NamedKey::Alt) =>
      { ..current, alt: pressed }
    @window_core.Key::Named(@window_core.NamedKey::Meta) =>
      { ..current, meta: pressed }
    _ => current
  }
}

///|
fn WebApp::register_primary_runtime_slot(
  self : WebApp,
  window_id : @host.HostWindowId,
) -> Unit {
  ignore(
    self.runtime_slots.insert_from_registry(
      self.windows,
      window_id,
      driver=self.driver,
    ),
  )
}

///|
fn WebApp::sync_runtime_slot(
  self : WebApp,
  window_id : @host.HostWindowId,
) -> Unit {
  ignore(self.runtime_slots.sync_from_registry(self.windows, window_id))
}

///|
fn WebApp::apply_window_lifecycle(
  self : WebApp,
  host_event : @host.HostEvent,
) -> Unit {
  match self.window_id {
    Some(window_id) =>
      if self.windows.apply_host_event(window_id, host_event) {
        self.sync_runtime_slot(window_id)
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
fn WebApp::dispose(self : WebApp) -> Unit {
  match self.window_id {
    Some(window_id) => {
      ignore(self.windows.close(window_id))
      self.sync_runtime_slot(window_id)
      ignore(self.runtime_slots.remove(window_id))
      ignore(self.windows.remove_closed())
      self.window_id = None
    }
    None => ()
  }
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
  set_web_async_host_service_queue(None)
}

///|
fn surface_metrics_from_physical(
  size : @dpi.PhysicalSize,
  scale_factor : Double,
) -> @host.HostSurfaceMetrics {
  @host.surface_metrics_from_physical(size, scale_factor~)
}

///|
fn host_metrics_to_dpi_size(metrics : @host.HostSurfaceMetrics) -> @dpi.Size {
  @dpi.LogicalSize::LogicalSize(
    metrics.logical_size.width,
    metrics.logical_size.height,
  ).into_size()
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
