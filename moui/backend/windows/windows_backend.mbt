///|
extern "C" fn win32_surface_host_hinstance() -> @wgpu_c.OpaquePtr = "moui_windows_surface_host_hinstance"

///|
extern "C" fn win32_surface_host_hwnd_from_u64(
  hwnd : UInt64,
) -> @wgpu_c.OpaquePtr = "moui_windows_surface_host_hwnd_from_u64"

///|
#borrow(pixels)
extern "C" fn windows_present_skia_pixels_to_hwnd(
  hwnd : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pixels_len : Int,
) -> Int = "moui_windows_present_skia_pixels_to_hwnd"

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
  renderer : @render.RendererSelection
  scene_resolver : @host.HostWindowSceneResolver
}

///|
struct WindowsApp {
  title : String
  runtime : @core.AppRuntime
  driver : @host.HostRuntimeDriver
  text_input_session : @host.TextInputSession
  text_engine_setting : @wgpu_renderer.NativeTextEngineSetting
  renderer_selection : @render.RendererSelection
  services : @host.HostServiceBridge
  window_requests : @host.HostWindowRequestQueue
  scene_resolver : @host.HostWindowSceneResolver
  windows : @host.HostWindowRegistry
  runtime_slots : @host.HostWindowRuntimeSlots
  platform_windows : @host.HostPlatformWindowMap
  platform_slots : WindowsWindowPlatformSlots
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
}

///|
priv struct WindowsWindowPlatformSlot {
  host_id : @host.HostWindowId
  platform_id : @window_core.WindowId
  window : @win.Window
  renderer : WindowsWindowRenderer
}

///|
priv enum WindowsWindowRenderer {
  Wgpu(@wgpu_renderer.WgpuRenderer)
  Skia(@skia_renderer.SkiaRasterRenderer)
}

///|
priv struct WindowsWindowPlatformSlots {
  mut slots : Array[WindowsWindowPlatformSlot]
}

///|
pub fn WindowsAppOptions::new(
  text_engine? : @wgpu_renderer.NativeTextEngineSetting = @wgpu_renderer.NativeTextEngineSetting::PlatformDefault,
  renderer? : @render.RendererSelection = @render.RendererSelection::Default,
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
) -> WindowsAppOptions {
  { text_engine, renderer, scene_resolver }
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
    runtime,
    driver: @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    text_input_session: @host.TextInputSession::new(),
    text_engine_setting: options.text_engine,
    renderer_selection: options.renderer,
    services,
    window_requests,
    scene_resolver: options.scene_resolver,
    windows: @host.HostWindowRegistry::new(),
    runtime_slots: @host.HostWindowRuntimeSlots::new(),
    platform_windows: @host.HostPlatformWindowMap::new(),
    platform_slots: WindowsWindowPlatformSlots::new(),
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
pub fn windows_host_info() -> @host.HostAppInfo {
  @host.HostAppInfo::new(
    backend=@host.HostBackendKind::Native,
    description="Windows Win32 window host with wgpu-native surface",
  )
}

///|
pub fn windows_input_capabilities() -> @host.HostInputCapabilities {
  @host.HostInputCapabilities::new(
    pointer=true,
    scroll=true,
    keyboard=true,
    focus=true,
    text_input=true,
    ime=true,
    clipboard=true,
    drag_drop=true,
  )
}

///|
pub fn windows_capability_summary(
  services? : @host.HostServiceCapabilities = windows_service_bridge().capabilities,
) -> @host.HostCapabilitySummary {
  @host.HostCapabilitySummary::from_contracts(
    info=windows_host_info(),
    services~,
    input=windows_input_capabilities(),
    label="Windows host",
    window_lifecycle=true,
    multi_window=true,
    text_input_ready=true,
    ime_ready=true,
    drag_drop_ready=true,
    async_services=false,
    native_accessibility_ready=windows_accessibility_bridge_info().native_binding_ready,
    description="Win32 host with clipboard, file dialog, URL, system theme, native context menu, text input, and file-drop contracts.",
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
fn WindowsWindowPlatformSlots::new() -> WindowsWindowPlatformSlots {
  { slots: [] }
}

///|
fn WindowsWindowPlatformSlots::insert(
  self : WindowsWindowPlatformSlots,
  slot : WindowsWindowPlatformSlot,
) -> Bool {
  match
    (self.lookup_host(slot.host_id), self.lookup_platform(slot.platform_id)) {
    (None, None) => {
      self.slots.push(slot)
      true
    }
    _ => false
  }
}

///|
fn WindowsWindowPlatformSlots::lookup_host(
  self : WindowsWindowPlatformSlots,
  host_id : @host.HostWindowId,
) -> WindowsWindowPlatformSlot? {
  for slot in self.slots {
    if slot.host_id == host_id {
      return Some(slot)
    }
  }
  None
}

///|
fn WindowsWindowPlatformSlots::lookup_platform(
  self : WindowsWindowPlatformSlots,
  platform_id : @window_core.WindowId,
) -> WindowsWindowPlatformSlot? {
  for slot in self.slots {
    if slot.platform_id == platform_id {
      return Some(slot)
    }
  }
  None
}

///|
fn WindowsWindowPlatformSlots::remove_host(
  self : WindowsWindowPlatformSlots,
  host_id : @host.HostWindowId,
) -> WindowsWindowPlatformSlot? {
  let mut removed = None
  let kept = []
  for slot in self.slots {
    if slot.host_id == host_id {
      removed = Some(slot)
    } else {
      kept.push(slot)
    }
  }
  self.slots = kept
  removed
}

///|
fn WindowsWindowRenderer::resize(
  self : WindowsWindowRenderer,
  metrics : @render.RendererSurfaceMetrics,
) -> Unit {
  match self {
    Wgpu(renderer) => renderer.resize(metrics)
    Skia(renderer) =>
      renderer.resize(metrics) catch {
        err => println("error resizing Windows Skia renderer: \{err.message()}")
      }
  }
}

///|
fn WindowsWindowRenderer::render(
  self : WindowsWindowRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit {
  match self {
    Wgpu(renderer) => renderer.render(commands)
    Skia(renderer) =>
      renderer.render(commands) catch {
        err => println("error rendering Windows Skia frame: \{err.message()}")
      }
  }
}

///|
fn WindowsWindowRenderer::text_system(
  self : WindowsWindowRenderer,
) -> @core.TextSystem {
  match self {
    Wgpu(renderer) => renderer.text_system()
    Skia(renderer) => renderer.text_system()
  }
}

///|
fn WindowsWindowRenderer::dispose(self : WindowsWindowRenderer) -> Unit {
  match self {
    Wgpu(renderer) => renderer.dispose()
    Skia(renderer) => renderer.dispose()
  }
}

///|
pub impl @win.ApplicationHandler for WindowsApp with fn can_create_surfaces(
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
      ignore(
        self.platform_windows.bind(platform_id=window.id(), host_id=window_id),
      )
      self.register_primary_runtime_slot(window_id)
      self.driver.set_redraw_scheduler(() => {
        self.request_redraw_window_if_needed(window_id)
      })
      match self.create_renderer_for_window(window, metrics) {
        Some(renderer) => {
          self.driver.set_text_system(renderer.text_system())
          ignore(self.driver.dispatch(@host.HostEvent::Resized(metrics)))
          ignore(
            self.platform_slots.insert({
              host_id: window_id,
              platform_id: window.id(),
              window,
              renderer,
            }),
          )
          window.request_redraw()
          self.drain_window_requests(event_loop)
        }
        None => {
          self.rollback_window_record(window_id)
          window.drop()
          event_loop.exit()
        }
      }
    }
    None => ()
  }
}

///|
pub impl @win.ApplicationHandler for WindowsApp with fn window_event(
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
      self.dispose_window(window_id)
      if self.runtime_slots.is_empty() {
        event_loop.exit()
      }
    }
    @window_core.WindowEvent::SurfaceResized(_) => {
      self.dispatch_window_event(window_id, event)
      match self.platform_slots.lookup_host(window_id) {
        Some(slot) => {
          let metrics = @host.HostSurfaceMetrics::new(
            logical_size=@host.physical_size_to_core(slot.window.surface_size()),
            physical_size=@host.physical_size_to_core(
              slot.window.surface_size(),
            ),
          )
          slot.renderer.resize(renderer_metrics_from_host(metrics))
          slot.window.request_redraw()
        }
        None => ()
      }
    }
    @window_core.WindowEvent::PointerMoved(_, position, _, _) => {
      self.last_pointer = @host.physical_position_to_core(position)
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = @host.physical_position_to_core(position)
      self.dispatch_pointer_or_context_menu(window_id, event)
    }
    @window_core.WindowEvent::DragEntered(_, position)
    | @window_core.WindowEvent::DragMoved(position)
    | @window_core.WindowEvent::DragDropped(_, position) => {
      self.last_pointer = @host.physical_position_to_core(position)
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::DragLeft(Some(position)) => {
      self.last_pointer = @host.physical_position_to_core(position)
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::KeyboardInput(_, _, _) =>
      self.dispatch_window_event(window_id, event)
    @window_core.WindowEvent::Ime(_) =>
      self.dispatch_window_event(window_id, event)
    @window_core.WindowEvent::ModifiersChanged(_) =>
      self.dispatch_window_event(window_id, event)
    @window_core.WindowEvent::RedrawRequested => self.redraw_window(window_id)
    _ => self.dispatch_window_event(window_id, event)
  }
}

///|
fn WindowsApp::dispatch_pointer_or_context_menu(
  self : WindowsApp,
  window_id : @host.HostWindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  if @host.window_event_is_context_menu_button(event) {
    if @host.window_event_is_context_menu_trigger(event) {
      match self.runtime_slots.lookup(window_id) {
        Some(slot) => ignore(slot.driver.show_context_menu(self.services))
        None => ()
      }
      self.sync_text_input_session()
    }
  } else {
    self.dispatch_window_event(window_id, event)
  }
}

///|
fn WindowsApp::redraw_window(
  self : WindowsApp,
  window_id : @host.HostWindowId,
) -> Unit {
  match
    (
      self.platform_slots.lookup_host(window_id),
      self.runtime_slots.lookup(window_id),
    ) {
    (Some(platform_slot), Some(runtime_slot)) => {
      platform_slot.window.pre_present_notify()
      runtime_slot.driver.begin_redraw()
      platform_slot.renderer.render(runtime_slot.driver.draw_commands())
      runtime_slot.driver.finish_redraw()
      self.sync_text_input_session()
    }
    _ => ()
  }
}

///|
fn WindowsApp::create_renderer_for_window(
  self : WindowsApp,
  window : @win.Window,
  metrics : @host.HostSurfaceMetrics,
) -> WindowsWindowRenderer? {
  match self.resolve_renderer_selection() {
    @render.RendererBackendKind::NativeWgpu =>
      self.create_wgpu_renderer_for_window(window, metrics)
    @render.RendererBackendKind::SkiaRasterNative =>
      self.create_skia_renderer_for_window(window, metrics)
    backend => {
      println(
        "Windows renderer selection \{backend.label()} is not supported by this platform backend",
      )
      None
    }
  }
}

///|
fn WindowsApp::resolve_renderer_selection(
  self : WindowsApp,
) -> @render.RendererBackendKind {
  match self.renderer_selection {
    @render.RendererSelection::Default =>
      @render.RendererBackendKind::NativeWgpu
    @render.RendererSelection::Backend(backend) => backend
    @render.RendererSelection::Family(@render.RendererFamily::Skia) =>
      @render.RendererBackendKind::SkiaRasterNative
    @render.RendererSelection::Family(@render.RendererFamily::Wgpu) =>
      @render.RendererBackendKind::NativeWgpu
    @render.RendererSelection::Family(@render.RendererFamily::WebGpu) =>
      @render.RendererBackendKind::WebGpuWasm
  }
}

///|
fn WindowsApp::create_wgpu_renderer_for_window(
  self : WindowsApp,
  window : @win.Window,
  metrics : @host.HostSurfaceMetrics,
) -> WindowsWindowRenderer? {
  Some(
    WindowsWindowRenderer::Wgpu(
      @wgpu_renderer.create_with_host_surface_and_text_engine(
        renderer_metrics_from_host(metrics),
        create_windows_host_surface(window.window_handle()),
        text_engine=windows_text_engine(self.text_engine_setting),
      ),
    ),
  ) catch {
    err => {
      println("error creating Windows WGPU renderer: \{err.message()}")
      None
    }
  }
}

///|
fn WindowsApp::create_skia_renderer_for_window(
  self : WindowsApp,
  window : @win.Window,
  metrics : @host.HostSurfaceMetrics,
) -> WindowsWindowRenderer? {
  let _ = self
  if !@skia_renderer.skia_available() {
    println(
      "Windows Skia renderer selected, but skia_mbt/native is unavailable; configure real Skia link flags before selecting SkiaRasterNative",
    )
    return None
  }
  Some(
    WindowsWindowRenderer::Skia(
      @skia_renderer.create_with_present_target(
        renderer_metrics_from_host(metrics),
        windows_skia_present_target(window.window_handle()),
      ),
    ),
  ) catch {
    err => {
      println("error creating Windows Skia renderer: \{err.message()}")
      None
    }
  }
}

///|
fn windows_skia_present_target(
  hwnd : UInt64,
) -> @skia_renderer.SkiaPresentTarget {
  @skia_renderer.SkiaPresentTarget::new(
    description="Windows GDI Skia pixel presenter",
    present=frame => {
      windows_present_skia_pixels_to_hwnd(
        hwnd,
        frame.width,
        frame.height,
        frame.row_bytes,
        frame.pixels,
        frame.pixels.length(),
      ) ==
      0
    },
  )
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
  window_id : @host.HostWindowId,
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
      self.apply_window_lifecycle(window_id, host_event)
      match self.runtime_slots.lookup(window_id) {
        Some(slot) =>
          match host_event {
            @host.HostEvent::Keyboard(event) =>
              ignore(
                slot.driver.dispatch_keyboard_with_services(
                  event,
                  self.services,
                ),
              )
            _ => ignore(slot.driver.dispatch(host_event))
          }
        None => ()
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
  ignore(
    self.window_requests.drain_with_handler(request => {
      self.apply_window_request(event_loop, request)
    }),
  )
}

///|
fn WindowsApp::apply_window_request(
  self : WindowsApp,
  event_loop : @win.ActiveEventLoop,
  request : @host.HostWindowRequest,
) -> @host.HostWindowRequestResult {
  match request {
    @host.HostWindowRequest::OpenWindow(open_request) =>
      self.open_window(event_loop, open_request)
    @host.HostWindowRequest::FocusWindow(id) =>
      self.apply_platform_window_request(id, request, window => {
        window.focus_window()
      })
    @host.HostWindowRequest::CloseWindow(id) =>
      self.apply_platform_window_request(id, request, _window => {
        self.dispose_window(id)
        if self.runtime_slots.is_empty() {
          event_loop.exit()
        }
      })
    @host.HostWindowRequest::ResizeWindow(id, metrics) =>
      self.apply_platform_window_request(id, request, window => {
        ignore(window.request_surface_size(host_metrics_to_dpi_size(metrics)))
        match self.platform_slots.lookup_host(id) {
          Some(slot) =>
            slot.renderer.resize(renderer_metrics_from_host(metrics))
          None => ()
        }
        window.request_redraw()
      })
    @host.HostWindowRequest::MinimizeWindow(id) =>
      self.apply_platform_window_request(id, request, window => {
        window.set_minimized(true)
      })
    @host.HostWindowRequest::ShowWindow(id) =>
      self.apply_platform_window_request(id, request, window => {
        window.set_minimized(false)
        window.set_visible(true)
      })
    @host.HostWindowRequest::SetPrimaryWindow(id) =>
      self.apply_platform_window_request(id, request, _window => ())
  }
}

///|
fn WindowsApp::apply_platform_window_request(
  self : WindowsApp,
  id : @host.HostWindowId,
  request : @host.HostWindowRequest,
  apply : (@win.Window) -> Unit,
) -> @host.HostWindowRequestResult {
  match self.platform_slots.lookup_host(id) {
    Some(slot) => {
      let result = self.runtime_slots.apply_request(self.windows, request)
      match result {
        @host.HostWindowRequestResult::WindowRejected(_) => ()
        _ => apply(slot.window)
      }
      result
    }
    None =>
      @host.HostWindowRequestResult::WindowRejected(
        "window request has no active Windows window",
      )
  }
}

///|
fn WindowsApp::open_window(
  self : WindowsApp,
  event_loop : @win.ActiveEventLoop,
  request : @host.HostWindowOpenRequest,
) -> @host.HostWindowRequestResult {
  match self.windows.resolve_open_request(request, self.scene_resolver) {
    @host.HostWindowOpenResolution::OpenRejected(message) =>
      @host.HostWindowRequestResult::WindowRejected(message)
    @host.HostWindowOpenResolution::OpenResolved(resolved) =>
      self.create_resolved_window(event_loop, resolved)
  }
}

///|
fn WindowsApp::create_resolved_window(
  self : WindowsApp,
  event_loop : @win.ActiveEventLoop,
  resolved : @host.HostWindowResolvedOpen,
) -> @host.HostWindowRequestResult {
  let attributes = @window_core.WindowAttributes::default()
    .with_title(resolved.record.title)
    .with_surface_size(host_metrics_to_dpi_size(resolved.record.metrics))
  let window : @win.Window? = Some(event_loop.try_create_window(attributes)) catch {
    err => {
      println("error creating Windows window: \{err}")
      None
    }
  }
  match window {
    Some(window) => self.attach_resolved_window(window, resolved)
    None => {
      self.rollback_window_record(resolved.id)
      @host.HostWindowRequestResult::WindowRejected(
        "failed to create Windows window",
      )
    }
  }
}

///|
fn WindowsApp::attach_resolved_window(
  self : WindowsApp,
  window : @win.Window,
  resolved : @host.HostWindowResolvedOpen,
) -> @host.HostWindowRequestResult {
  let metrics = @host.HostSurfaceMetrics::new(
    logical_size=@host.physical_size_to_core(window.surface_size()),
    physical_size=@host.physical_size_to_core(window.surface_size()),
  )
  match self.create_renderer_for_window(window, metrics) {
    Some(renderer) => {
      ignore(self.windows.resize(resolved.id, metrics))
      ignore(self.runtime_slots.sync_open_from_registry(self.windows))
      let record = match self.windows.lookup(resolved.id) {
        Some(record) => record
        None => resolved.record
      }
      let driver = @host.HostRuntimeDriver::new(
        runtime=resolved.instance.runtime,
        schedule_redraw=() => (),
      )
      driver.set_redraw_scheduler(() => {
        self.request_redraw_window_if_needed(resolved.id)
      })
      driver.set_environment(
        self.services.environment_with_system_theme(driver.environment()),
      )
      driver.set_text_system(renderer.text_system())
      ignore(driver.dispatch(@host.HostEvent::Resized(metrics)))
      ignore(
        self.runtime_slots.insert(
          @host.HostWindowRuntimeSlot::from_driver(record~, driver~),
        ),
      )
      ignore(
        self.platform_windows.bind(platform_id=window.id(), host_id=resolved.id),
      )
      ignore(
        self.platform_slots.insert({
          host_id: resolved.id,
          platform_id: window.id(),
          window,
          renderer,
        }),
      )
      self.request_platform_redraw(resolved.id)
      @host.HostWindowRequestResult::WindowOpened(resolved.id)
    }
    None => {
      window.drop()
      self.rollback_window_record(resolved.id)
      @host.HostWindowRequestResult::WindowRejected(
        "failed to create Windows renderer",
      )
    }
  }
}

///|
fn WindowsApp::register_primary_runtime_slot(
  self : WindowsApp,
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
fn WindowsApp::sync_runtime_slot(
  self : WindowsApp,
  window_id : @host.HostWindowId,
) -> Unit {
  ignore(self.runtime_slots.sync_from_registry(self.windows, window_id))
}

///|
fn WindowsApp::sync_runtime_slots(self : WindowsApp) -> Unit {
  ignore(self.runtime_slots.sync_open_from_registry(self.windows))
}

///|
fn WindowsApp::apply_window_lifecycle(
  self : WindowsApp,
  window_id : @host.HostWindowId,
  host_event : @host.HostEvent,
) -> Unit {
  ignore(
    self.runtime_slots.apply_host_event(self.windows, window_id, host_event),
  )
}

///|
fn WindowsApp::active_runtime_slot(
  self : WindowsApp,
) -> @host.HostWindowRuntimeSlot? {
  match self.runtime_slots.focused_slot() {
    Some(slot) => Some(slot)
    None => self.runtime_slots.primary_slot()
  }
}

///|
fn WindowsApp::sync_text_input_session(self : WindowsApp) -> Unit {
  match self.active_runtime_slot() {
    Some(runtime_slot) =>
      match self.platform_slots.lookup_host(runtime_slot.id) {
        Some(platform_slot) =>
          match
            self.text_input_session.sync(
              runtime_slot.driver.focused_text_input(),
            ) {
            @host.TextInputSessionAction::EnableIme(request)
            | @host.TextInputSessionAction::UpdateIme(request)
            | @host.TextInputSessionAction::DisableIme(request) =>
              platform_slot.window.request_ime_update(request) catch {
                _ => ()
              }
            @host.TextInputSessionAction::NoImeChange => ()
          }
        None => ()
      }
    None => ()
  }
}

///|
fn runtime_slot_needs_redraw(slot : @host.HostWindowRuntimeSlot) -> Bool {
  let result = slot.driver.event_result()
  result.needs_redraw || result.redraw_requested
}

///|
fn WindowsApp::request_redraw(self : WindowsApp) -> Unit {
  match self.active_runtime_slot() {
    Some(slot) => self.request_redraw_window_if_needed(slot.id)
    None => ()
  }
}

///|
fn WindowsApp::request_redraw_window_if_needed(
  self : WindowsApp,
  window_id : @host.HostWindowId,
) -> Unit {
  match self.runtime_slots.lookup(window_id) {
    Some(slot) =>
      if runtime_slot_needs_redraw(slot) {
        self.request_platform_redraw(window_id)
      }
    None => ()
  }
}

///|
fn WindowsApp::request_platform_redraw(
  self : WindowsApp,
  window_id : @host.HostWindowId,
) -> Unit {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.request_redraw()
    None => ()
  }
}

///|
fn WindowsApp::dispose_window(
  self : WindowsApp,
  window_id : @host.HostWindowId,
) -> Unit {
  ignore(self.windows.close(window_id))
  self.sync_runtime_slot(window_id)
  ignore(self.runtime_slots.remove(window_id))
  ignore(self.platform_windows.remove_host(window_id))
  match self.platform_slots.remove_host(window_id) {
    Some(slot) => {
      slot.renderer.dispose()
      slot.window.drop()
    }
    None => ()
  }
  ignore(self.windows.remove_closed())
  self.sync_runtime_slots()
}

///|
fn WindowsApp::rollback_window_record(
  self : WindowsApp,
  window_id : @host.HostWindowId,
) -> Unit {
  ignore(self.windows.close(window_id))
  ignore(self.windows.remove_closed())
  self.sync_runtime_slots()
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
