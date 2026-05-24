///|
extern "C" fn win32_surface_host_hinstance() -> @wgpu_c.OpaquePtr = "moui_windows_surface_host_hinstance"

///|
extern "C" fn win32_surface_host_hwnd_from_u64(
  hwnd : UInt64,
) -> @wgpu_c.OpaquePtr = "moui_windows_surface_host_hwnd_from_u64"

///|
extern "C" fn windows_clipboard_has_text() -> Int = "moui_windows_clipboard_has_text"

///|
extern "C" fn windows_clipboard_read_text_bytes() -> Bytes = "moui_windows_clipboard_read_text"

///|
#borrow(text)
extern "C" fn windows_clipboard_write_text_bytes(text : Bytes) -> Int = "moui_windows_clipboard_write_text"

///|
#borrow(url)
extern "C" fn windows_open_url_bytes(url : Bytes) -> Int = "moui_windows_open_url"

///|
extern "C" fn windows_system_theme_is_light() -> Int = "moui_windows_system_theme_is_light"

///|
#borrow(title, filters, default_name)
extern "C" fn windows_file_dialog_bytes(
  kind : Int,
  title : Bytes,
  filters : Bytes,
  default_name : Bytes,
) -> Bytes = "moui_windows_file_dialog"

///|
#borrow(commands)
extern "C" fn windows_show_menu_bytes(commands : Bytes) -> Int = "moui_windows_show_menu"

///|
pub(all) struct WindowsAccessibilityBridgeInfo {
  kind : @host.NativeAccessibilityBridgeKind
  contract_ready : Bool
  native_binding_ready : Bool
  action_roundtrip_ready : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WindowsAppOptions {
  text_engine : @wgpu_renderer.NativeTextEngineSetting
} derive(Eq, Debug, ToJson)

///|
struct WindowsApp {
  title : String
  mut window : @win.Window?
  mut renderer : @wgpu_renderer.WgpuRenderer?
  runtime : @core.AppRuntime
  driver : @host.HostRuntimeDriver
  text_input_session : @host.TextInputSession
  text_engine_setting : @wgpu_renderer.NativeTextEngineSetting
  services : @host.HostServiceBridge
  window_requests : @host.HostWindowRequestQueue
  windows : @host.HostWindowRegistry
  mut window_id : @host.HostWindowId?
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
}

///|
pub fn WindowsAppOptions::new(
  text_engine? : @wgpu_renderer.NativeTextEngineSetting = @wgpu_renderer.NativeTextEngineSetting::PlatformDefault,
) -> WindowsAppOptions {
  { text_engine, }
}

///|
pub fn run_app(title : String, runtime : @core.AppRuntime) -> Unit {
  run_app_with_options(
    title,
    runtime,
    options=WindowsAppOptions::new(),
    window_requests=@host.HostWindowRequestQueue::new(),
  )
}

///|
pub fn run_app_with_window_requests(
  title : String,
  runtime : @core.AppRuntime,
  window_requests : @host.HostWindowRequestQueue,
) -> Unit {
  run_app_with_options(
    title,
    runtime,
    options=WindowsAppOptions::new(),
    window_requests~,
  )
}

///|
pub fn run_app_with_options(
  title : String,
  runtime : @core.AppRuntime,
  options~ : WindowsAppOptions,
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  let event_loop = @win.EventLoop::new()
  let services = windows_service_bridge()
  runtime.set_environment(
    services.environment_with_system_theme(runtime.environment()),
  )
  let app = WindowsApp::{
    title,
    window: None,
    renderer: None,
    runtime,
    driver: @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    text_input_session: @host.TextInputSession::new(),
    text_engine_setting: options.text_engine,
    services,
    window_requests,
    windows: @host.HostWindowRegistry::new(),
    window_id: None,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
  }
  app.driver.set_redraw_scheduler(() => app.request_redraw())
  event_loop.run_app(app)
}

///|
fn windows_text_engine(
  setting : @wgpu_renderer.NativeTextEngineSetting,
) -> @wgpu_renderer.NativeTextEngine {
  match setting {
    @wgpu_renderer.NativeTextEngineSetting::MoonCosmic =>
      @wgpu_cosmic_text.cosmic_text_engine()
    @wgpu_renderer.NativeTextEngineSetting::PlatformDefault =>
      @wgpu_renderer.native_platform_text_engine_with_fallback(
        @wgpu_directwrite.directwrite_text_provider(),
        fallback=@wgpu_cosmic_text.cosmic_text_engine(),
      )
  }
}

///|
pub fn windows_accessibility_bridge_info() -> WindowsAccessibilityBridgeInfo {
  {
    kind: @host.NativeAccessibilityBridgeKind::UIAutomation,
    contract_ready: true,
    native_binding_ready: false,
    action_roundtrip_ready: true,
    description: "Windows exposes a UI Automation accessibility bridge contract over the shared semantics tree; real UIA provider binding is still a backend follow-up.",
  }
}

///|
pub fn windows_accessibility_bridge(
  root~ : @core.SemanticsNode,
  dispatch~ : (@core.ElementId, @core.SemanticsAction, String?) -> Bool,
) -> @host.NativeAccessibilityBridge {
  @host.NativeAccessibilityBridge::semantics_action_bridge(
    kind=@host.NativeAccessibilityBridgeKind::UIAutomation,
    root~,
    dispatch~,
  )
}

///|
pub fn windows_system_theme() -> @core.ColorScheme {
  if windows_system_theme_is_light() != 0 {
    @core.ColorScheme::Light
  } else {
    @core.ColorScheme::Dark
  }
}

///|
pub fn windows_service_bridge(
  system_theme? : @core.ColorScheme = windows_system_theme(),
  clipboard? : (@host.HostClipboardRequest) -> @host.HostServiceResponse = dispatch_windows_clipboard,
  open_url? : (String) -> Bool = dispatch_windows_open_url,
  file_dialog? : (@host.HostFileDialogOptions) -> Array[String] = dispatch_windows_file_dialog,
  menu? : (Array[@core.ActionCommand]) -> Int = dispatch_windows_menu,
) -> @host.HostServiceBridge {
  @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      clipboard=true,
      file_dialogs=true,
      menus=true,
      open_url=true,
      system_theme=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::Clipboard(clipboard_request) =>
          clipboard(clipboard_request)
        @host.HostServiceRequest::OpenUrl(url) =>
          if open_url(url) {
            @host.HostServiceResponse::UrlOpened
          } else {
            @host.HostServiceResponse::Unavailable("open URL failed")
          }
        @host.HostServiceRequest::FileDialog(options) =>
          @host.HostServiceResponse::FileDialogSelection(file_dialog(options))
        @host.HostServiceRequest::ShowMenu(commands) =>
          menu_command_response(commands, menu(commands))
        @host.HostServiceRequest::QuerySystemTheme =>
          @host.HostServiceResponse::SystemTheme(system_theme)
      }
    },
  )
}

///|
fn dispatch_windows_menu(commands : Array[@core.ActionCommand]) -> Int {
  windows_show_menu_bytes(encode_menu_commands(commands))
}

///|
fn dispatch_windows_file_dialog(
  options : @host.HostFileDialogOptions,
) -> Array[String] {
  decode_file_dialog_selection(
    windows_file_dialog_bytes(
      host_file_dialog_kind_code(options.kind),
      encode_host_string(options.title),
      encode_host_filter_list(options.filters),
      encode_host_string(options.default_name.unwrap_or("")),
    ),
  )
}

///|
fn dispatch_windows_open_url(url : String) -> Bool {
  let bytes = @utf8.encode(url[:], bom=false)
  windows_open_url_bytes(bytes) != 0
}

///|
fn dispatch_windows_clipboard(
  request : @host.HostClipboardRequest,
) -> @host.HostServiceResponse {
  match request {
    @host.HostClipboardRequest::ReadText =>
      if windows_clipboard_has_text() != 0 {
        @host.HostServiceResponse::ClipboardText(
          @utf8.decode_lossy(
            windows_clipboard_read_text_bytes()[:],
            ignore_bom=false,
          ),
        )
      } else {
        @host.HostServiceResponse::Unavailable(
          "clipboard does not contain text",
        )
      }
    @host.HostClipboardRequest::WriteText(text) => {
      let bytes = @utf8.encode(text[:], bom=false)
      if windows_clipboard_write_text_bytes(bytes) != 0 {
        @host.HostServiceResponse::ClipboardWritten
      } else {
        @host.HostServiceResponse::Unavailable("clipboard write failed")
      }
    }
  }
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
) -> @host.HostEvent? {
  @host.window_event_to_host_with_modifiers(event, last_pointer, modifiers)
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
  let initial_size = @dpi.PhysicalSize::PhysicalSize(
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
      let metrics = @host.HostSurfaceMetrics::new(
        logical_size=@host.physical_size_to_core(window.surface_size()),
        physical_size=@host.physical_size_to_core(window.surface_size()),
      )
      let window_id = self.windows.open(
        title=self.title,
        metrics~,
        primary=true,
      )
      self.window_id = Some(window_id)
      ignore(self.driver.dispatch(@host.HostEvent::Resized(metrics)))
      let renderer : @wgpu_renderer.WgpuRenderer? = Some(
        @wgpu_renderer.create_with_host_surface_and_text_engine(
          renderer_metrics_from_host(metrics),
          create_windows_host_surface(window.window_handle()),
          text_engine=windows_text_engine(self.text_engine_setting),
        ),
      ) catch {
        err => {
          println("error creating Windows WGPU renderer: \{err.message()}")
          event_loop.exit()
          None
        }
      }
      match renderer {
        Some(renderer) => self.runtime.set_text_system(renderer.text_system())
        None => ()
      }
      self.renderer = renderer
      self.window = Some(window)
      window.request_redraw()
      self.drain_window_requests(event_loop)
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
      match (self.window, self.renderer) {
        (Some(window), Some(renderer)) => {
          let metrics = @host.HostSurfaceMetrics::new(
            logical_size=@host.physical_size_to_core(window.surface_size()),
            physical_size=@host.physical_size_to_core(window.surface_size()),
          )
          renderer.resize(renderer_metrics_from_host(metrics))
          window.request_redraw()
        }
        _ => ()
      }
    }
    @window_core.WindowEvent::PointerMoved(_, position, _, _) => {
      self.last_pointer = @host.physical_position_to_core(position)
      self.dispatch_window_event(event)
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = @host.physical_position_to_core(position)
      self.dispatch_pointer_or_context_menu(event)
    }
    @window_core.WindowEvent::DragEntered(_, position)
    | @window_core.WindowEvent::DragMoved(position)
    | @window_core.WindowEvent::DragDropped(_, position) => {
      self.last_pointer = @host.physical_position_to_core(position)
      self.dispatch_window_event(event)
    }
    @window_core.WindowEvent::DragLeft(Some(position)) => {
      self.last_pointer = @host.physical_position_to_core(position)
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
fn WindowsApp::dispatch_pointer_or_context_menu(
  self : WindowsApp,
  event : @window_core.WindowEvent,
) -> Unit {
  if @host.window_event_is_context_menu_button(event) {
    if @host.window_event_is_context_menu_trigger(event) {
      ignore(self.driver.show_context_menu(self.services))
      self.sync_text_input_session()
    }
  } else {
    self.dispatch_window_event(event)
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
fn WindowsApp::dispatch_window_event(
  self : WindowsApp,
  event : @window_core.WindowEvent,
) -> Unit {
  match event {
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      self.modifiers = @host.modifiers_to_core(modifiers)
    _ => ()
  }
  match
    window_event_to_host_with_modifiers(
      event,
      self.last_pointer,
      self.modifiers,
    ) {
    Some(host_event) => {
      self.apply_window_lifecycle(host_event)
      match host_event {
        @host.HostEvent::Keyboard(event) =>
          ignore(
            self.driver.dispatch_keyboard_with_services(event, self.services),
          )
        _ => ignore(self.driver.dispatch(host_event))
      }
      self.sync_text_input_session()
    }
    None => ()
  }
}

///|
fn WindowsApp::drain_window_requests(
  self : WindowsApp,
  event_loop : @win.ActiveEventLoop,
) -> Unit {
  for request in self.window_requests.drain() {
    let result = self.apply_window_request(event_loop, request)
    self.window_requests.record_result(request, result)
  }
}

///|
fn WindowsApp::apply_window_request(
  self : WindowsApp,
  event_loop : @win.ActiveEventLoop,
  request : @host.HostWindowRequest,
) -> @host.HostWindowRequestResult {
  match request {
    @host.HostWindowRequest::OpenWindow(_) =>
      @host.HostWindowRequestResult::WindowRejected(
        "open window requests require multi-window Windows host support",
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
        match self.renderer {
          Some(renderer) => renderer.resize(renderer_metrics_from_host(metrics))
          None => ()
        }
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
fn WindowsApp::apply_current_window_request(
  self : WindowsApp,
  id : @host.HostWindowId,
  request : @host.HostWindowRequest,
  apply : (@win.Window) -> Unit,
) -> @host.HostWindowRequestResult {
  match (self.window_id, self.window) {
    (Some(current), Some(window)) =>
      if current == id {
        let result = self.windows.apply_request(request)
        match result {
          @host.HostWindowRequestResult::WindowRejected(_) => ()
          _ => apply(window)
        }
        result
      } else {
        self.windows.apply_request(request)
      }
    _ =>
      @host.HostWindowRequestResult::WindowRejected(
        "window request has no active Windows window",
      )
  }
}

///|
fn WindowsApp::apply_window_lifecycle(
  self : WindowsApp,
  host_event : @host.HostEvent,
) -> Unit {
  match self.window_id {
    Some(window_id) =>
      ignore(self.windows.apply_host_event(window_id, host_event))
    None => ()
  }
}

///|
fn WindowsApp::sync_text_input_session(self : WindowsApp) -> Unit {
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
  match self.window_id {
    Some(window_id) => {
      ignore(self.windows.close(window_id))
      ignore(self.windows.remove_closed())
      self.window_id = None
    }
    None => ()
  }
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

///|
fn host_metrics_to_dpi_size(metrics : @host.HostSurfaceMetrics) -> @dpi.Size {
  @dpi.LogicalSize::LogicalSize(
    metrics.logical_size.width,
    metrics.logical_size.height,
  ).into_size()
}
