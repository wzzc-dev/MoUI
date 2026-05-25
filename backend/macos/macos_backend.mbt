///|
extern "C" fn macos_surface_host_layer_from_view(
  raw_content_view_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> @wgpu_c.OpaquePtr = "moui_macos_surface_host_layer_from_view"

///|
extern "C" fn macos_clipboard_has_text() -> Int = "moui_macos_clipboard_has_text"

///|
extern "C" fn macos_clipboard_read_text_bytes() -> Bytes = "moui_macos_clipboard_read_text"

///|
#borrow(text)
extern "C" fn macos_clipboard_write_text_bytes(text : Bytes) -> Int = "moui_macos_clipboard_write_text"

///|
#borrow(url)
extern "C" fn macos_open_url_bytes(url : Bytes) -> Int = "moui_macos_open_url"

///|
extern "C" fn macos_system_theme_is_dark() -> Int = "moui_macos_system_theme_is_dark"

///|
#borrow(title, filters, default_name)
extern "C" fn macos_file_dialog_bytes(
  kind : Int,
  title : Bytes,
  filters : Bytes,
  default_name : Bytes,
) -> Bytes = "moui_macos_file_dialog"

///|
#borrow(commands)
extern "C" fn macos_show_menu_bytes(commands : Bytes) -> Int = "moui_macos_show_menu"

///|
pub(all) suberror MacosSurfaceHostError {
  MacosSurfaceHostLayerUnavailable(String)
}

///|
pub(all) struct MacosBackendInfo {
  host_info : @host.HostAppInfo
  renderer_ready : Bool
  accessibility : MacosAccessibilityBridgeInfo
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MacosAccessibilityBridgeInfo {
  kind : @host.NativeAccessibilityBridgeKind
  contract_ready : Bool
  native_binding_ready : Bool
  action_roundtrip_ready : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MacosAppOptions {
  text_engine : @wgpu_renderer.NativeTextEngineSetting
} derive(Eq, Debug, ToJson)

///|
struct MacosApp {
  title : String
  mut window : @window_macos.Window?
  mut renderer : @wgpu_renderer.WgpuRenderer?
  runtime : @core.AppRuntime
  driver : @host.HostRuntimeDriver
  text_input_session : @host.TextInputSession
  text_engine_setting : @wgpu_renderer.NativeTextEngineSetting
  services : @host.HostServiceBridge
  window_requests : @host.HostWindowRequestQueue
  windows : @host.HostWindowRegistry
  runtime_slots : @host.HostWindowRuntimeSlots
  platform_windows : @host.HostPlatformWindowMap
  mut window_id : @host.HostWindowId?
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
}

///|
pub fn MacosAppOptions::new(
  text_engine? : @wgpu_renderer.NativeTextEngineSetting = @wgpu_renderer.NativeTextEngineSetting::PlatformDefault,
) -> MacosAppOptions {
  { text_engine, }
}

///|
pub fn backend_info() -> MacosBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="macOS AppKit window host with CAMetalLayer wgpu surface",
    ),
    renderer_ready: true,
    accessibility: macos_accessibility_bridge_info(),
    description: "macOS backend uses Milky2018/window/macos for AppKit events and installs a CAMetalLayer on the window NSView for render/wgpu.",
  }
}

///|
pub fn macos_accessibility_bridge_info() -> MacosAccessibilityBridgeInfo {
  {
    kind: @host.NativeAccessibilityBridgeKind::AppKit,
    contract_ready: true,
    native_binding_ready: false,
    action_roundtrip_ready: true,
    description: "macOS exposes an AppKit accessibility bridge contract over the shared semantics tree; real NSAccessibility object binding is still a backend follow-up.",
  }
}

///|
pub fn macos_accessibility_bridge(
  root~ : @core.SemanticsNode,
  dispatch~ : (@core.ElementId, @core.SemanticsAction, String?) -> Bool,
) -> @host.NativeAccessibilityBridge {
  @host.NativeAccessibilityBridge::semantics_action_bridge(
    kind=@host.NativeAccessibilityBridgeKind::AppKit,
    root~,
    dispatch~,
  )
}

///|
pub fn macos_system_theme() -> @core.ColorScheme {
  if macos_system_theme_is_dark() != 0 {
    @core.ColorScheme::Dark
  } else {
    @core.ColorScheme::Light
  }
}

///|
pub fn macos_service_bridge(
  system_theme? : @core.ColorScheme = macos_system_theme(),
  clipboard? : (@host.HostClipboardRequest) -> @host.HostServiceResponse = dispatch_macos_clipboard,
  open_url? : (String) -> Bool = dispatch_macos_open_url,
  file_dialog? : (@host.HostFileDialogOptions) -> Array[String] = dispatch_macos_file_dialog,
  menu? : (Array[@core.ActionCommand]) -> Int = dispatch_macos_menu,
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
fn dispatch_macos_menu(commands : Array[@core.ActionCommand]) -> Int {
  macos_show_menu_bytes(encode_menu_commands(commands))
}

///|
fn dispatch_macos_file_dialog(
  options : @host.HostFileDialogOptions,
) -> Array[String] {
  decode_file_dialog_selection(
    macos_file_dialog_bytes(
      host_file_dialog_kind_code(options.kind),
      encode_host_string(options.title),
      encode_host_filter_list(options.filters),
      encode_host_string(options.default_name.unwrap_or("")),
    ),
  )
}

///|
fn dispatch_macos_open_url(url : String) -> Bool {
  let bytes = @utf8.encode(url[:], bom=false)
  macos_open_url_bytes(bytes) != 0
}

///|
fn dispatch_macos_clipboard(
  request : @host.HostClipboardRequest,
) -> @host.HostServiceResponse {
  match request {
    @host.HostClipboardRequest::ReadText =>
      if macos_clipboard_has_text() != 0 {
        @host.HostServiceResponse::ClipboardText(
          @utf8.decode_lossy(
            macos_clipboard_read_text_bytes()[:],
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
      if macos_clipboard_write_text_bytes(bytes) != 0 {
        @host.HostServiceResponse::ClipboardWritten
      } else {
        @host.HostServiceResponse::Unavailable("clipboard write failed")
      }
    }
  }
}

///|
pub fn run_app(title : String, runtime : @core.AppRuntime) -> Unit {
  run_app_with_options(
    title,
    runtime,
    options=MacosAppOptions::new(),
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
    options=MacosAppOptions::new(),
    window_requests~,
  )
}

///|
pub fn run_app_with_options(
  title : String,
  runtime : @core.AppRuntime,
  options~ : MacosAppOptions,
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  let event_loop = @window_macos.EventLoop::EventLoop()
  let services = macos_service_bridge()
  runtime.set_environment(
    services.environment_with_system_theme(runtime.environment()),
  )
  let app = MacosApp::{
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
    runtime_slots: @host.HostWindowRuntimeSlots::new(),
    platform_windows: @host.HostPlatformWindowMap::new(),
    window_id: None,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
  }
  app.driver.set_redraw_scheduler(() => app.request_redraw())
  event_loop.run_app(app)
}

///|
fn macos_text_engine(
  setting : @wgpu_renderer.NativeTextEngineSetting,
) -> @wgpu_renderer.NativeTextEngine {
  match setting {
    @wgpu_renderer.NativeTextEngineSetting::MoonCosmic =>
      @wgpu_cosmic_text.cosmic_text_engine()
    @wgpu_renderer.NativeTextEngineSetting::PlatformDefault =>
      @wgpu_renderer.native_platform_text_engine_with_fallback(
        @wgpu_coretext.coretext_text_provider(),
        fallback=@wgpu_cosmic_text.cosmic_text_engine(),
      )
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
  raw_content_view_handle : UInt64,
  size : @core.Size,
  scale_factor? : Double = 1.0,
) -> @wgpu_renderer.HostWgpuSurface raise Error {
  let instance = @wgpu.Instance::create()
  let layer = macos_surface_host_layer_from_content_view(
    raw_content_view_handle,
    size,
    scale_factor~,
  )
  let desc = @wgpu.surface_descriptor_metal_layer_new(layer)
  let surface = instance.create_surface(desc)
  @wgpu.surface_descriptor_free(desc)
  @wgpu_renderer.HostWgpuSurface::new(instance~, surface~)
}

///|
fn sync_macos_host_surface(
  raw_content_view_handle : UInt64,
  size : @core.Size,
  scale_factor? : Double = 1.0,
) -> Unit raise Error {
  ignore(
    macos_surface_host_layer_from_content_view(
      raw_content_view_handle,
      size,
      scale_factor~,
    ),
  )
}

///|
fn macos_surface_host_layer_from_content_view(
  raw_content_view_handle : UInt64,
  size : @core.Size,
  scale_factor~ : Double,
) -> @wgpu_c.OpaquePtr raise MacosSurfaceHostError {
  let layer = macos_surface_host_layer_from_view(
    raw_content_view_handle,
    size_dim_to_int(size.width),
    size_dim_to_int(size.height),
    scale_factor,
  )
  guard !@wgpu_c.opaque_ptr_is_null(layer) else {
    raise MacosSurfaceHostError::MacosSurfaceHostLayerUnavailable(
      "macOS CAMetalLayer bridge returned a null layer",
    )
  }
  layer
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
  @dpi.LogicalSize::LogicalSize(size.width, size.height).into_size()
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
      let window_id = self.windows.open(
        title=self.title,
        metrics~,
        primary=true,
      )
      self.window_id = Some(window_id)
      ignore(
        self.platform_windows.bind(platform_id=window.id(), host_id=window_id),
      )
      self.register_primary_runtime_slot(window_id)
      ignore(self.driver.dispatch(@host.HostEvent::Resized(metrics)))
      let raw_content_view_handle : UInt64? = Some(window.content_view_handle()) catch {
        err => {
          println("error resolving macOS content view handle: \{err}")
          event_loop.exit()
          None
        }
      }
      let renderer : @wgpu_renderer.WgpuRenderer? = match
        raw_content_view_handle {
        Some(raw_content_view_handle) =>
          Some(
            @wgpu_renderer.create_with_host_surface_and_text_engine(
              renderer_metrics_from_host(metrics),
              create_macos_host_surface(
                raw_content_view_handle,
                metrics.physical_size,
                scale_factor=metrics.scale_factor,
              ),
              text_engine=macos_text_engine(self.text_engine_setting),
            ),
          ) catch {
            err => {
              println("error creating macOS WGPU renderer: \{err}")
              event_loop.exit()
              None
            }
          }
        None => None
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
pub impl @window_macos.ApplicationHandler for MacosApp with window_event(
  self,
  event_loop,
  platform_window_id,
  event,
) {
  self.drain_window_requests(event_loop)
  if event_loop.exiting() {
    return ()
  }
  let window_id = match self.platform_windows.lookup_host(platform_window_id) {
    Some(window_id) => window_id
    None => return ()
  }
  match event {
    @window_core.WindowEvent::CloseRequested => {
      self.dispatch_window_event(window_id, event)
      self.dispose()
      event_loop.exit()
    }
    @window_core.WindowEvent::SurfaceResized(_) => {
      self.dispatch_window_event(window_id, event)
      match (self.window, self.renderer) {
        (Some(window), Some(renderer)) => {
          let metrics = @host.surface_metrics_from_physical(
            window.surface_size(),
            scale_factor=window.scale_factor(),
          )
          self.sync_macos_surface_layer(window, metrics)
          renderer.resize(renderer_metrics_from_host(metrics))
          window.request_redraw()
        }
        _ => ()
      }
    }
    @window_core.WindowEvent::ScaleFactorChanged(_, _) => {
      self.dispatch_window_event(window_id, event)
      match (self.window, self.renderer) {
        (Some(window), Some(renderer)) => {
          let metrics = @host.surface_metrics_from_physical(
            window.surface_size(),
            scale_factor=window.scale_factor(),
          )
          self.sync_macos_surface_layer(window, metrics)
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
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(),
      )
      self.dispatch_pointer_or_context_menu(window_id, event)
    }
    @window_core.WindowEvent::DragEntered(_, position)
    | @window_core.WindowEvent::DragMoved(position)
    | @window_core.WindowEvent::DragDropped(_, position) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::DragLeft(Some(position)) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::KeyboardInput(_, _, _) =>
      self.dispatch_window_event(window_id, event)
    @window_core.WindowEvent::Ime(_) =>
      self.dispatch_window_event(window_id, event)
    @window_core.WindowEvent::ModifiersChanged(_) =>
      self.dispatch_window_event(window_id, event)
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
    _ => self.dispatch_window_event(window_id, event)
  }
}

///|
fn MacosApp::dispatch_pointer_or_context_menu(
  self : MacosApp,
  window_id : @host.HostWindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  if @host.window_event_is_context_menu_button(event) {
    if @host.window_event_is_context_menu_trigger(event) {
      ignore(self.driver.show_context_menu(self.services))
      self.sync_text_input_session()
    }
  } else {
    self.dispatch_window_event(window_id, event)
  }
}

///|
fn MacosApp::sync_macos_surface_layer(
  self : MacosApp,
  window : @window_macos.Window,
  metrics : @host.HostSurfaceMetrics,
) -> Unit {
  let _ = self
  let raw_content_view_handle : UInt64? = Some(window.content_view_handle()) catch {
    err => {
      println("error resolving macOS content view handle: \{err}")
      None
    }
  }
  match raw_content_view_handle {
    Some(raw_content_view_handle) =>
      sync_macos_host_surface(
        raw_content_view_handle,
        metrics.physical_size,
        scale_factor=metrics.scale_factor,
      ) catch {
        err => println("error syncing macOS CAMetalLayer: \{err}")
      }
    None => ()
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
  window_id : @host.HostWindowId,
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
      self.apply_window_lifecycle(window_id, host_event)
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
fn MacosApp::drain_window_requests(
  self : MacosApp,
  event_loop : @window_macos.ActiveEventLoop,
) -> Unit {
  ignore(
    self.window_requests.drain_with_handler(request => {
      self.apply_window_request(event_loop, request)
    }),
  )
}

///|
fn MacosApp::apply_window_request(
  self : MacosApp,
  event_loop : @window_macos.ActiveEventLoop,
  request : @host.HostWindowRequest,
) -> @host.HostWindowRequestResult {
  match request {
    @host.HostWindowRequest::OpenWindow(_) =>
      @host.HostWindowRequestResult::WindowRejected(
        "open window requests require multi-window macOS host support",
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
        self.sync_macos_surface_layer(window, metrics)
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
fn MacosApp::apply_current_window_request(
  self : MacosApp,
  id : @host.HostWindowId,
  request : @host.HostWindowRequest,
  apply : (@window_macos.Window) -> Unit,
) -> @host.HostWindowRequestResult {
  match (self.window_id, self.window) {
    (Some(current), Some(window)) =>
      if current == id {
        let result = self.runtime_slots.apply_request(self.windows, request)
        match result {
          @host.HostWindowRequestResult::WindowRejected(_) => ()
          _ => apply(window)
        }
        result
      } else {
        self.runtime_slots.apply_request(self.windows, request)
      }
    _ =>
      @host.HostWindowRequestResult::WindowRejected(
        "window request has no active macOS window",
      )
  }
}

///|
fn MacosApp::register_primary_runtime_slot(
  self : MacosApp,
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
fn MacosApp::sync_runtime_slot(
  self : MacosApp,
  window_id : @host.HostWindowId,
) -> Unit {
  ignore(self.runtime_slots.sync_from_registry(self.windows, window_id))
}

///|
fn MacosApp::apply_window_lifecycle(
  self : MacosApp,
  window_id : @host.HostWindowId,
  host_event : @host.HostEvent,
) -> Unit {
  ignore(
    self.runtime_slots.apply_host_event(self.windows, window_id, host_event),
  )
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
  match self.window_id {
    Some(window_id) => {
      ignore(self.windows.close(window_id))
      self.sync_runtime_slot(window_id)
      ignore(self.runtime_slots.remove(window_id))
      ignore(self.platform_windows.remove_host(window_id))
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
