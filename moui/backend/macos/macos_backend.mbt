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
let macos_first_present_pump_limit = 16

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
pub struct MacosHostAppOptions {
  priv scene_resolver : @host.HostWindowSceneResolver
  priv exit_after_first_present : Bool
  priv event_sources : @host.HostPlatformEventSources?
}

///|
pub struct MacosRendererProvider {
  priv create_renderer : (@window_macos.Window, @host.HostSurfaceMetrics) -> @host.HostWindowRenderer?
  priv sync_surface : (@window_macos.Window, @host.HostSurfaceMetrics) -> Unit
  priv image_loader : @host.HostAsyncImageLoader?
}

///|
struct MacosApp {
  title : String
  runtime : @core.AppRuntime
  driver : @host.HostRuntimeDriver
  text_input_session : @host.TextInputSession
  renderer_provider : MacosRendererProvider
  services : @host.HostServiceBridge
  window_requests : @host.HostWindowRequestQueue
  scene_resolver : @host.HostWindowSceneResolver
  windows : @host.HostWindowRegistry
  runtime_slots : @host.HostWindowRuntimeSlots
  platform_windows : @host.HostPlatformWindowMap
  platform_slots : MacosWindowPlatformSlots
  image_repaint_tracker : @host.HostImageResourceRepaintTracker
  event_sources : @host.HostPlatformEventSources?
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
  mut exit_after_first_present : Bool
}

///|
priv struct MacosWindowPlatformSlot {
  host_id : @host.HostWindowId
  platform_id : @window_core.WindowId
  window : @window_macos.Window
  renderer : @host.HostWindowRenderer
}

///|
priv struct MacosWindowPlatformSlots {
  mut slots : Array[MacosWindowPlatformSlot]
}

///|
pub fn MacosHostAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
  exit_after_first_present? : Bool = false,
  event_sources? : @host.HostPlatformEventSources? = None,
) -> MacosHostAppOptions {
  { scene_resolver, exit_after_first_present, event_sources }
}

///|
pub fn MacosRendererProvider::new(
  create_renderer~ : (@window_macos.Window, @host.HostSurfaceMetrics) -> @host.HostWindowRenderer?,
  sync_surface? : (@window_macos.Window, @host.HostSurfaceMetrics) -> Unit = (
    _window,
    _metrics,
  ) => (),
  image_loader? : @host.HostAsyncImageLoader? = None,
) -> MacosRendererProvider {
  { create_renderer, sync_surface, image_loader }
}

///|
pub fn backend_info() -> MacosBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="macOS AppKit window host with renderer providers",
    ),
    renderer_ready: true,
    accessibility: macos_accessibility_bridge_info(),
    description: "macOS backend uses wzzc-dev/window/macos for AppKit events and delegates concrete rendering to platform renderer provider packages.",
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
pub fn macos_input_capabilities() -> @host.HostInputCapabilities {
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
pub fn macos_capability_summary(
  services? : @host.HostServiceCapabilities = macos_service_bridge().capabilities,
) -> @host.HostCapabilitySummary {
  @host.HostCapabilitySummary::from_contracts(
    info=backend_info().host_info,
    services~,
    input=macos_input_capabilities(),
    label="macOS host",
    window_lifecycle=true,
    multi_window=true,
    text_input_ready=true,
    ime_ready=true,
    drag_drop_ready=true,
    async_services=false,
    native_accessibility_ready=backend_info().accessibility.native_binding_ready,
    description="AppKit host with clipboard, file dialog, URL, system theme, native context menu, text input, and file-drop contracts.",
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
  text_file? : (@host.HostTextFileRequest) -> @host.HostServiceResponse = dispatch_macos_text_file,
  menu? : (Array[@core.ActionCommand]) -> Int = dispatch_macos_menu,
) -> @host.HostServiceBridge {
  @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      clipboard=true,
      file_dialogs=true,
      file_access=true,
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
        @host.HostServiceRequest::TextFile(text_file_request) =>
          text_file(text_file_request)
        @host.HostServiceRequest::ShowMenu(commands) =>
          menu_command_response(commands, menu(commands))
        @host.HostServiceRequest::QuerySystemTheme =>
          @host.HostServiceResponse::SystemTheme(system_theme)
      }
    },
  )
}

///|
fn dispatch_macos_text_file(
  request : @host.HostTextFileRequest,
) -> @host.HostServiceResponse {
  match request {
    @host.HostTextFileRequest::ReadText(path) =>
      if @fs.path_exists(path) {
        let bytes = @fs.read_file_to_bytes(path) catch {
          _ => return @host.HostServiceResponse::Unavailable("file read failed")
        }
        @host.HostServiceResponse::TextFileContent(
          path,
          @utf8.decode_lossy(bytes[:], ignore_bom=true),
        )
      } else {
        @host.HostServiceResponse::Unavailable("file does not exist")
      }
    @host.HostTextFileRequest::WriteText(path, text) => {
      let bytes = @utf8.encode(text[:], bom=false)
      @fs.write_bytes_to_file(path, bytes) catch {
        _ => return @host.HostServiceResponse::Unavailable("file write failed")
      }
      @host.HostServiceResponse::TextFileWritten(path)
    }
  }
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
pub fn run_app_with_renderer_provider(
  title : String,
  runtime : @core.AppRuntime,
  provider~ : MacosRendererProvider,
  options? : MacosHostAppOptions = MacosHostAppOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  let (event_loop, app) = create_macos_app(
    title,
    runtime,
    provider~,
    options~,
    window_requests~,
  )
  if options.exit_after_first_present {
    run_app_until_first_present(event_loop, app)
  } else {
    event_loop.run_app(app)
  }
}

///|
pub async fn run_app_with_renderer_provider_async_pump(
  title : String,
  runtime : @core.AppRuntime,
  provider~ : MacosRendererProvider,
  options? : MacosHostAppOptions = MacosHostAppOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
  frame_interval_ms? : Int = 8,
) -> Unit {
  let (event_loop, app) = create_macos_app(
    title,
    runtime,
    provider~,
    options~,
    window_requests~,
  )
  if options.exit_after_first_present {
    run_app_until_first_present(event_loop, app)
  } else {
    while !event_loop.exiting() {
      match event_loop.pump_app_events(Some(0), app) {
        @window_core.PumpStatus::Exit(_) => return ()
        @window_core.PumpStatus::Continue => ()
      }
      @async.sleep(frame_interval_ms)
    }
  }
}

///|
fn create_macos_app(
  title : String,
  runtime : @core.AppRuntime,
  provider~ : MacosRendererProvider,
  options~ : MacosHostAppOptions,
  window_requests~ : @host.HostWindowRequestQueue,
) -> (@window_macos.EventLoop, MacosApp) {
  let event_loop = @window_macos.EventLoop::EventLoop()
  let services = macos_service_bridge()
  runtime.set_environment(
    services.environment_with_system_theme(runtime.environment()),
  )
  let app = MacosApp::{
    title,
    runtime,
    driver: @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    text_input_session: @host.TextInputSession::new(),
    renderer_provider: provider,
    services,
    window_requests,
    scene_resolver: options.scene_resolver,
    windows: @host.HostWindowRegistry::new(),
    runtime_slots: @host.HostWindowRuntimeSlots::new(),
    platform_windows: @host.HostPlatformWindowMap::new(),
    platform_slots: MacosWindowPlatformSlots::new(),
    image_repaint_tracker: @host.HostImageResourceRepaintTracker::new(),
    event_sources: options.event_sources,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
    exit_after_first_present: options.exit_after_first_present,
  }
  app.driver.set_redraw_scheduler(() => app.request_redraw())
  (event_loop, app)
}

///|
fn run_app_until_first_present(
  event_loop : @window_macos.EventLoop,
  app : MacosApp,
) -> Unit {
  let mut remaining = macos_first_present_pump_limit
  while remaining > 0 && !event_loop.exiting() {
    match event_loop.pump_app_events(Some(0), app) {
      @window_core.PumpStatus::Exit(_) => return ()
      @window_core.PumpStatus::Continue => ()
    }
    remaining = remaining - 1
  }
  if app.exit_after_first_present {
    println(
      "macOS renderer first-frame smoke did not present before pump limit",
    )
    event_loop.exit()
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
fn runtime_size_to_window_surface_size(size : @core.Size) -> @dpi.Size {
  @dpi.LogicalSize::LogicalSize(size.width, size.height).into_size()
}

///|
fn MacosWindowPlatformSlots::new() -> MacosWindowPlatformSlots {
  { slots: [] }
}

///|
fn MacosWindowPlatformSlots::insert(
  self : MacosWindowPlatformSlots,
  slot : MacosWindowPlatformSlot,
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
fn MacosWindowPlatformSlots::lookup_host(
  self : MacosWindowPlatformSlots,
  host_id : @host.HostWindowId,
) -> MacosWindowPlatformSlot? {
  for slot in self.slots {
    if slot.host_id == host_id {
      return Some(slot)
    }
  }
  None
}

///|
fn MacosWindowPlatformSlots::lookup_platform(
  self : MacosWindowPlatformSlots,
  platform_id : @window_core.WindowId,
) -> MacosWindowPlatformSlot? {
  for slot in self.slots {
    if slot.platform_id == platform_id {
      return Some(slot)
    }
  }
  None
}

///|
fn MacosWindowPlatformSlots::remove_host(
  self : MacosWindowPlatformSlots,
  host_id : @host.HostWindowId,
) -> MacosWindowPlatformSlot? {
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
pub impl @window_macos.ApplicationHandler for MacosApp with fn can_create_surfaces(
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
      ignore(
        self.platform_windows.bind(platform_id=window.id(), host_id=window_id),
      )
      self.register_primary_runtime_slot(window_id)
      self.driver.set_redraw_scheduler(() => {
        self.request_redraw_window_if_needed(window_id)
      })
      match (self.renderer_provider.create_renderer)(window, metrics) {
        Some(renderer) => {
          self.bind_renderer_image_resource_changes(window_id, renderer)
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
pub impl @window_macos.ApplicationHandler for MacosApp with fn window_event(
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
          let metrics = @host.surface_metrics_from_physical(
            slot.window.surface_size(),
            scale_factor=slot.window.scale_factor(),
          )
          (self.renderer_provider.sync_surface)(slot.window, metrics)
          slot.renderer.resize(metrics)
          slot.window.request_redraw()
        }
        None => ()
      }
    }
    @window_core.WindowEvent::ScaleFactorChanged(_, _) => {
      self.dispatch_window_event(window_id, event)
      match self.platform_slots.lookup_host(window_id) {
        Some(slot) => {
          let metrics = @host.surface_metrics_from_physical(
            slot.window.surface_size(),
            scale_factor=slot.window.scale_factor(),
          )
          (self.renderer_provider.sync_surface)(slot.window, metrics)
          slot.renderer.resize(metrics)
          slot.window.request_redraw()
        }
        None => ()
      }
    }
    @window_core.WindowEvent::PointerMoved(_, position, _, _) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_pointer_or_context_menu(window_id, event)
    }
    @window_core.WindowEvent::DragEntered(_, position)
    | @window_core.WindowEvent::DragMoved(position)
    | @window_core.WindowEvent::DragDropped(_, position) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::DragLeft(Some(position)) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(window_id),
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
      if self.redraw_window(window_id) {
        event_loop.exit()
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
fn MacosApp::redraw_window(
  self : MacosApp,
  window_id : @host.HostWindowId,
) -> Bool {
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
      ignore(
        self.image_repaint_tracker.record_presented(
          window_id,
          platform_slot.renderer,
        ),
      )
      ignore(
        self.renderer_provider.schedule_image_resource_loads(
          window_id,
          platform_slot.renderer,
          self.image_resource_completion_source(),
        ),
      )
      self.sync_text_input_session()
      if self.exit_after_first_present &&
        platform_slot.renderer.present_count() > 0 {
        println(
          "macOS renderer presented first frame; exiting by request; title=" +
          runtime_slot.record.title,
        )
        self.exit_after_first_present = false
        self.dispose_window(window_id)
        true
      } else {
        false
      }
    }
    _ => false
  }
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
  let scale_factor = self.current_scale_factor(window_id)
  match
    window_event_to_host_with_modifiers(
      event,
      self.last_pointer,
      self.modifiers,
      scale_factor~,
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
      ignore(self.publish_subscription_event(window_id, host_event))
      self.sync_text_input_session()
    }
    None => ()
  }
}

///|
fn MacosApp::publish_subscription_event(
  self : MacosApp,
  window_id : @host.HostWindowId,
  event : @host.HostEvent,
) -> @host.HostPlatformEventPublishResult? {
  match self.event_sources {
    Some(sources) => Some(sources.publish(window_id~, event~))
    None => None
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
        (self.renderer_provider.sync_surface)(window, metrics)
        match self.platform_slots.lookup_host(id) {
          Some(slot) => slot.renderer.resize(metrics)
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
fn MacosApp::apply_platform_window_request(
  self : MacosApp,
  id : @host.HostWindowId,
  request : @host.HostWindowRequest,
  apply : (@window_macos.Window) -> Unit,
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
        "window request has no active macOS window",
      )
  }
}

///|
fn MacosApp::open_window(
  self : MacosApp,
  event_loop : @window_macos.ActiveEventLoop,
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
fn MacosApp::create_resolved_window(
  self : MacosApp,
  event_loop : @window_macos.ActiveEventLoop,
  resolved : @host.HostWindowResolvedOpen,
) -> @host.HostWindowRequestResult {
  let attributes = @window_core.WindowAttributes::default()
    .with_title(resolved.record.title)
    .with_surface_size(host_metrics_to_dpi_size(resolved.record.metrics))
  let window : @window_macos.Window? = Some(
    event_loop.try_create_window(attributes),
  ) catch {
    err => {
      println("error creating macOS window: \{err}")
      None
    }
  }
  match window {
    Some(window) => self.attach_resolved_window(window, resolved)
    None => {
      self.rollback_window_record(resolved.id)
      @host.HostWindowRequestResult::WindowRejected(
        "failed to create macOS window",
      )
    }
  }
}

///|
fn MacosApp::attach_resolved_window(
  self : MacosApp,
  window : @window_macos.Window,
  resolved : @host.HostWindowResolvedOpen,
) -> @host.HostWindowRequestResult {
  let metrics = @host.surface_metrics_from_physical(
    window.surface_size(),
    scale_factor=window.scale_factor(),
  )
  match (self.renderer_provider.create_renderer)(window, metrics) {
    Some(renderer) => {
      self.bind_renderer_image_resource_changes(resolved.id, renderer)
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
        "failed to create macOS renderer",
      )
    }
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
fn MacosApp::sync_runtime_slots(self : MacosApp) -> Unit {
  ignore(self.runtime_slots.sync_open_from_registry(self.windows))
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
fn MacosApp::active_runtime_slot(
  self : MacosApp,
) -> @host.HostWindowRuntimeSlot? {
  match self.runtime_slots.focused_slot() {
    Some(slot) => Some(slot)
    None => self.runtime_slots.primary_slot()
  }
}

///|
fn MacosApp::sync_text_input_session(self : MacosApp) -> Unit {
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
fn MacosApp::current_scale_factor(
  self : MacosApp,
  window_id : @host.HostWindowId,
) -> Double {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.scale_factor()
    None => 1.0
  }
}

///|
fn runtime_slot_needs_redraw(slot : @host.HostWindowRuntimeSlot) -> Bool {
  let result = slot.driver.event_result()
  result.needs_redraw || result.redraw_requested
}

///|
fn MacosApp::request_redraw(self : MacosApp) -> Unit {
  match self.active_runtime_slot() {
    Some(slot) => self.request_redraw_window_if_needed(slot.id)
    None => ()
  }
}

///|
fn MacosApp::request_redraw_window_if_needed(
  self : MacosApp,
  window_id : @host.HostWindowId,
) -> Unit {
  match self.runtime_slots.lookup(window_id) {
    Some(slot) => {
      let image_redraw_requested = self.request_image_resource_redraw_if_changed(
        window_id,
      )
      if runtime_slot_needs_redraw(slot) && !image_redraw_requested {
        self.request_platform_redraw(window_id)
      }
    }
    None => ()
  }
}

///|
fn MacosApp::request_image_resource_redraw_if_changed(
  self : MacosApp,
  window_id : @host.HostWindowId,
) -> Bool {
  match
    (
      self.platform_slots.lookup_host(window_id),
      self.runtime_slots.lookup(window_id),
    ) {
    (Some(platform_slot), Some(runtime_slot)) => {
      let result = self.image_repaint_tracker.request_redraw_if_changed(
        window_id,
        platform_slot.renderer,
        window_open=runtime_slot.record.phase !=
          @host.HostWindowLifecyclePhase::WindowClosed,
        request_redraw=id => self.request_platform_redraw(id),
      )
      result.status ==
      @host.HostImageResourceRepaintStatus::ImageRepaintRequested
    }
    (Some(platform_slot), None) => {
      ignore(
        self.image_repaint_tracker.request_redraw_if_changed(
          window_id,
          platform_slot.renderer,
          window_open=false,
          request_redraw=_id => (),
        ),
      )
      false
    }
    _ => false
  }
}

///|
fn MacosApp::bind_renderer_image_resource_changes(
  self : MacosApp,
  window_id : @host.HostWindowId,
  renderer : @host.HostWindowRenderer,
) -> Unit {
  renderer.set_image_resource_change_callback(
    Some(snapshot => {
      match self.image_repaint_tracker.revision_for(window_id) {
        Some(_) =>
          match
            (
              self.platform_slots.lookup_host(window_id),
              self.runtime_slots.lookup(window_id),
            ) {
            (Some(_platform_slot), Some(runtime_slot)) =>
              ignore(
                self.image_repaint_tracker.request_redraw_for_snapshot_if_changed(
                  window_id,
                  snapshot,
                  window_open=runtime_slot.record.phase !=
                    @host.HostWindowLifecyclePhase::WindowClosed,
                  request_redraw=id => self.request_platform_redraw(id),
                ),
              )
            (Some(_platform_slot), None) =>
              ignore(
                self.image_repaint_tracker.request_redraw_for_snapshot_if_changed(
                  window_id,
                  snapshot,
                  window_open=false,
                  request_redraw=_id => (),
                ),
              )
            _ => ()
          }
        None => ()
      }
    }),
  )
}

///|
fn MacosApp::request_platform_redraw(
  self : MacosApp,
  window_id : @host.HostWindowId,
) -> Unit {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.request_redraw()
    None => ()
  }
}

///|
fn MacosApp::image_resource_completion_source(
  self : MacosApp,
) -> @host.HostImageResourceCompletionSource {
  @host.HostImageResourceCompletionSource::new(
    tracker=self.image_repaint_tracker,
    window_open=id => self.image_resource_window_open(id),
    request_redraw=id => self.request_platform_redraw(id),
  )
}

///|
fn MacosApp::image_resource_window_open(
  self : MacosApp,
  window_id : @host.HostWindowId,
) -> Bool {
  match self.runtime_slots.lookup(window_id) {
    Some(slot) =>
      slot.record.phase != @host.HostWindowLifecyclePhase::WindowClosed
    None => false
  }
}

///|
fn MacosRendererProvider::schedule_image_resource_loads(
  self : MacosRendererProvider,
  window_id : @host.HostWindowId,
  renderer : @host.HostWindowRenderer,
  completion_source : @host.HostImageResourceCompletionSource,
) -> @host.HostAsyncImageLoadScheduleResult? {
  match self.image_loader {
    Some(loader) =>
      Some(
        loader.schedule_loading_resources(
          window_id, renderer, completion_source,
        ),
      )
    None => None
  }
}

///|
fn MacosRendererProvider::cancel_image_resource_loads(
  self : MacosRendererProvider,
  window_id : @host.HostWindowId,
) -> Int {
  match self.image_loader {
    Some(loader) => loader.cancel_window(window_id)
    None => 0
  }
}

///|
fn MacosApp::dispose_window(
  self : MacosApp,
  window_id : @host.HostWindowId,
) -> Unit {
  ignore(self.windows.close(window_id))
  self.sync_runtime_slot(window_id)
  ignore(self.image_repaint_tracker.remove_window(window_id))
  ignore(self.renderer_provider.cancel_image_resource_loads(window_id))
  ignore(self.runtime_slots.remove(window_id))
  ignore(self.platform_windows.remove_host(window_id))
  match self.platform_slots.remove_host(window_id) {
    Some(slot) => {
      slot.renderer.set_image_resource_change_callback(None)
      slot.renderer.dispose()
      slot.window.drop()
    }
    None => ()
  }
  ignore(self.windows.remove_closed())
  self.sync_runtime_slots()
}

///|
fn MacosApp::rollback_window_record(
  self : MacosApp,
  window_id : @host.HostWindowId,
) -> Unit {
  ignore(self.windows.close(window_id))
  ignore(self.windows.remove_closed())
  self.sync_runtime_slots()
}

///|
fn host_metrics_to_dpi_size(metrics : @host.HostSurfaceMetrics) -> @dpi.Size {
  @dpi.LogicalSize::LogicalSize(
    metrics.logical_size.width,
    metrics.logical_size.height,
  ).into_size()
}
