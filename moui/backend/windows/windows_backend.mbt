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
pub struct WindowsHostAppOptions {
  priv scene_resolver : @host.HostWindowSceneResolver
  priv exit_after_first_present : Bool
  priv event_sources : @host.HostPlatformEventSources?
}

///|
pub struct WindowsRendererProvider {
  priv create_renderer : (@win.Window, @host.HostSurfaceMetrics) -> @host.HostWindowRenderer?
  priv sync_surface : (@win.Window, @host.HostSurfaceMetrics) -> Unit
  priv image_loader : @host.HostAsyncImageLoader?
}

///|
struct WindowsApp {
  title : String
  runtime : @core.AppRuntime
  driver : @host.HostRuntimeDriver
  text_input_session : @host.TextInputSession
  renderer_provider : WindowsRendererProvider
  services : @host.HostServiceBridge
  window_requests : @host.HostWindowRequestQueue
  scene_resolver : @host.HostWindowSceneResolver
  windows : @host.HostWindowRegistry
  runtime_slots : @host.HostWindowRuntimeSlots
  platform_windows : @host.HostPlatformWindowMap
  platform_slots : WindowsWindowPlatformSlots
  image_repaint_tracker : @host.HostImageResourceRepaintTracker
  event_sources : @host.HostPlatformEventSources?
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
  mut exit_after_first_present : Bool
}

///|
priv struct WindowsWindowPlatformSlot {
  host_id : @host.HostWindowId
  platform_id : @window_core.WindowId
  window : @win.Window
  renderer : @host.HostWindowRenderer
}

///|
priv struct WindowsWindowPlatformSlots {
  mut slots : Array[WindowsWindowPlatformSlot]
}

///|
pub fn WindowsHostAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
  exit_after_first_present? : Bool = false,
  event_sources? : @host.HostPlatformEventSources? = None,
) -> WindowsHostAppOptions {
  { scene_resolver, exit_after_first_present, event_sources }
}

///|
pub fn WindowsRendererProvider::new(
  create_renderer~ : (@win.Window, @host.HostSurfaceMetrics) -> @host.HostWindowRenderer?,
  sync_surface? : (@win.Window, @host.HostSurfaceMetrics) -> Unit = (
    _window,
    _metrics,
  ) => (),
  image_loader? : @host.HostAsyncImageLoader? = None,
) -> WindowsRendererProvider {
  { create_renderer, sync_surface, image_loader }
}

///|
fn WindowsRendererProvider::schedule_image_resource_loads(
  self : WindowsRendererProvider,
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
fn WindowsRendererProvider::cancel_image_resource_loads(
  self : WindowsRendererProvider,
  window_id : @host.HostWindowId,
) -> Int {
  match self.image_loader {
    Some(loader) => loader.cancel_window(window_id)
    None => 0
  }
}

///|
pub fn run_app_with_renderer_provider(
  title : String,
  runtime : @core.AppRuntime,
  provider~ : WindowsRendererProvider,
  options? : WindowsHostAppOptions = WindowsHostAppOptions::new(),
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
    renderer_provider: provider,
    services,
    window_requests,
    scene_resolver: options.scene_resolver,
    windows: @host.HostWindowRegistry::new(),
    runtime_slots: @host.HostWindowRuntimeSlots::new(),
    platform_windows: @host.HostPlatformWindowMap::new(),
    platform_slots: WindowsWindowPlatformSlots::new(),
    image_repaint_tracker: @host.HostImageResourceRepaintTracker::new(),
    event_sources: options.event_sources,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
    exit_after_first_present: options.exit_after_first_present,
  }
  app.driver.set_redraw_scheduler(() => app.request_redraw())
  event_loop.run_app(app)
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
    description="Windows Win32 window host with renderer providers",
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
  text_file? : (@host.HostTextFileRequest) -> @host.HostServiceResponse = dispatch_windows_text_file,
  menu? : (Array[@core.ActionCommand]) -> Int = dispatch_windows_menu,
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
fn dispatch_windows_text_file(
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
          (self.renderer_provider.sync_surface)(slot.window, metrics)
          slot.renderer.resize(metrics)
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
    @window_core.WindowEvent::RedrawRequested =>
      if self.redraw_window(window_id) {
        event_loop.exit()
      }
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
        println("Windows renderer presented first frame; exiting by request")
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
      ignore(self.publish_subscription_event(window_id, host_event))
      self.sync_text_input_session()
    }
    None => ()
  }
}

///|
fn WindowsApp::publish_subscription_event(
  self : WindowsApp,
  window_id : @host.HostWindowId,
  event : @host.HostEvent,
) -> @host.HostPlatformEventPublishResult? {
  match self.event_sources {
    Some(sources) => Some(sources.publish(window_id~, event~))
    None => None
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
fn WindowsApp::request_image_resource_redraw_if_changed(
  self : WindowsApp,
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
fn WindowsApp::bind_renderer_image_resource_changes(
  self : WindowsApp,
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
fn WindowsApp::image_resource_completion_source(
  self : WindowsApp,
) -> @host.HostImageResourceCompletionSource {
  @host.HostImageResourceCompletionSource::new(
    tracker=self.image_repaint_tracker,
    window_open=id => self.image_resource_window_open(id),
    request_redraw=id => self.request_platform_redraw(id),
  )
}

///|
fn WindowsApp::image_resource_window_open(
  self : WindowsApp,
  window_id : @host.HostWindowId,
) -> Bool {
  match self.runtime_slots.lookup(window_id) {
    Some(slot) =>
      slot.record.phase != @host.HostWindowLifecyclePhase::WindowClosed
    None => false
  }
}

///|
fn WindowsApp::dispose_window(
  self : WindowsApp,
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
