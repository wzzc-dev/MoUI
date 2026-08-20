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
#borrow(key)
extern "C" fn windows_settings_has_value(key : Bytes) -> Int = "moui_windows_settings_has_value"

///|
#borrow(key)
extern "C" fn windows_settings_read_bytes(key : Bytes) -> Bytes = "moui_windows_settings_read"

///|
#borrow(key, value)
extern "C" fn windows_settings_write_bytes(key : Bytes, value : Bytes) -> Int = "moui_windows_settings_write"

///|
#borrow(key)
extern "C" fn windows_settings_remove_bytes(key : Bytes) -> Int = "moui_windows_settings_remove"

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
  kind : String
  semantics_bridge_available : Bool
  native_accessibility_bridge_available : Bool
  action_dispatch_available : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub struct WindowsHostAppOptions {
  priv scene_resolver : @runtime.WindowSceneResolver
  priv event_sources : @runtime.HostPlatformEventSources?
  priv platform_view_plugins : Array[@host.PlatformViewPlugin]
}

///|
pub struct WindowsHostSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
}

///|
priv struct WindowsSurfaceBinding {
  create_renderer : (@win.Window, @core.SurfaceMetrics) -> @render.RendererSession?
  sync_surface : (@win.Window, @core.SurfaceMetrics) -> Unit
}

///|
/// Native host backend: owns the Windows host runtime, native windows, and
/// event-loop integration rather than attaching a runtime to an embedder.
/// Shared lifecycle, frame, image, input, and service state is held through
/// its matching backend/common owner.
struct WindowsNativeHostBackend {
  title : String
  runtime : @runtime.AppRuntime
  driver : @runtime.HostRuntimeDriver
  lifecycle : @window_lifecycle.WindowLifecycle
  frames : @window_frame.WindowFrameStates
  images : @window_image.WindowImageTaskStates
  input : @window_input.WindowInputState
  surface_binding : WindowsSurfaceBinding
  services : @window_services.WindowServiceState
  platform_slots : @window_lifecycle.WindowSlotMap[@win.Window, Unit]
  platform_view_plugins : Array[@host.PlatformViewPlugin]
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
  mut first_frame_smoke_auto_exit : Bool
}

///|
pub fn WindowsHostAppOptions::new(
  scene_resolver? : @runtime.WindowSceneResolver = @runtime.WindowSceneResolver::unavailable(),
  event_sources? : @runtime.HostPlatformEventSources? = None,
  platform_view_plugins? : Array[@host.PlatformViewPlugin] = [],
) -> WindowsHostAppOptions {
  { scene_resolver, event_sources, platform_view_plugins }
}

///|
pub fn WindowsHostSmokeOptions::new(
  first_frame_smoke_auto_exit? : Bool = false,
) -> WindowsHostSmokeOptions {
  { first_frame_smoke_auto_exit, }
}

///|
fn WindowsSurfaceBinding::new(
  create_renderer~ : (@win.Window, @core.SurfaceMetrics) -> @render.RendererSession?,
  sync_surface? : (@win.Window, @core.SurfaceMetrics) -> Unit = (
    _window,
    _metrics,
  ) => (),
) -> WindowsSurfaceBinding {
  { create_renderer, sync_surface }
}

///|
/// Renderer-neutral Windows composition entry. Renderer factories are
/// resolved after Win32 has created a window handle.
pub fn entry(
  options? : WindowsHostAppOptions = WindowsHostAppOptions::new(),
  smoke_options? : WindowsHostSmokeOptions = WindowsHostSmokeOptions::new(),
) -> @runtime.PlatformEntry {
  @runtime.PlatformEntry::new(id="windows", launch=request => {
    let providers = request.renderer_providers()
    let image_source = @host_image_native.filesystem_image_source()
    let binding = WindowsSurfaceBinding::new(create_renderer=(window, metrics) => {
      let renderer_metrics = metrics
      let host_present = @render.PresentTarget::new(
        description="Windows host CPU presenter",
        present=frame => {
          windows_present_pixels_to_hwnd(
            window.native_window_handle(),
            frame.width(),
            frame.height(),
            frame.row_bytes(),
            frame.pixels(),
            frame.pixels().length(),
          ) ==
          0
        },
      )
      let native_surface = @render.NativeSurface::new(
        surface_handle=window.native_window_handle(),
        present=_ => true,
      )
      let surface = @render.HostSurface::new(
        metrics=renderer_metrics,
        cpu_present=Some(host_present),
        native_surface~,
        image_source=Some(image_source),
      )
      @render_common.resolve_renderer(providers, surface)
    })
    launch_windows_app(
      request.title(),
      request.runtime(),
      binding~,
      options~,
      smoke_options~,
      window_requests=request.window_requests(),
    )
  })
}

///|
fn launch_windows_app(
  title : String,
  runtime : @runtime.AppRuntime,
  binding~ : WindowsSurfaceBinding,
  options~ : WindowsHostAppOptions,
  smoke_options~ : WindowsHostSmokeOptions,
  window_requests~ : @host.WindowRequests,
) -> Unit {
  let event_loop = @win.EventLoop::new()
  let services = windows_service_bridge()
  runtime.set_environment(
    services.environment_with_system_theme(runtime.environment()),
  )
  let app = WindowsNativeHostBackend::{
    title,
    runtime,
    driver: @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    lifecycle: @window_lifecycle.WindowLifecycle::new(
      requests=window_requests,
      scene_resolver=options.scene_resolver,
    ),
    frames: @window_frame.WindowFrameStates::new(),
    images: @window_image.WindowImageTaskStates::new(),
    input: @window_input.WindowInputState::new(
      event_sources=options.event_sources,
    ),
    surface_binding: binding,
    services: @window_services.WindowServiceState::new(bridge=services),
    platform_slots: @window_lifecycle.WindowSlotMap::new(),
    platform_view_plugins: options.platform_view_plugins,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
    first_frame_smoke_auto_exit: smoke_options.first_frame_smoke_auto_exit,
  }
  app.driver.set_redraw_scheduler(() => app.request_redraw())
  @runtime.install_platform_view_plugins(options.platform_view_plugins, (
    window_ptr,
    id,
    event,
  ) => app.dispatch_platform_view_event_from_plugin(window_ptr, id, event))
  event_loop.run_app(app)
}

///|
pub fn windows_accessibility_bridge_info() -> WindowsAccessibilityBridgeInfo {
  {
    kind: "uiautomation",
    semantics_bridge_available: true,
    native_accessibility_bridge_available: false,
    action_dispatch_available: true,
    description: "Windows exposes a UI Automation accessibility bridge contract over the shared semantics tree; real UIA provider binding is still a backend follow-up.",
  }
}

///|
pub fn windows_accessibility_bridge(
  driver : @runtime.HostRuntimeDriver,
) -> @accesskit_bridge.AccessKitBridge {
  @accesskit_bridge.AccessKitBridge::driver(
    diagnostic_name="uiautomation",
    driver~,
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
  services? : @host.HostServiceCapabilities = windows_service_bridge().capabilities(),
) -> @host.HostCapabilitySummary {
  @host.HostCapabilitySummary::from_contracts(
    info=windows_host_info(),
    services~,
    input=windows_input_capabilities(),
    label="Windows host",
    window_lifecycle=true,
    multi_window=true,
    text_input_available=true,
    ime_available=true,
    drag_drop_available=true,
    async_services=false,
    native_accessibility_available=windows_accessibility_bridge_info().native_accessibility_bridge_available,
    web_view_available=true,
    web_view_description="Windows WebView2 native embedding is available.",
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
fn dispatch_windows_menu(commands : Array[@core.ActionCommand]) -> Int {
  windows_show_menu_bytes(@host_services_desktop.encode_menu_commands(commands))
}

///|
fn dispatch_windows_file_dialog(
  options : @host.HostFileDialogOptions,
) -> Array[String] {
  @host_services_desktop.decode_file_dialog_selection(
    windows_file_dialog_bytes(
      @host_services_desktop.host_file_dialog_kind_code(options.kind),
      @host_services_desktop.encode_host_string(options.title),
      @host_services_desktop.encode_host_filter_list(options.filters),
      @host_services_desktop.encode_host_string(
        options.default_name.unwrap_or(""),
      ),
    ),
  )
}

///|
fn dispatch_windows_open_url(url : String) -> Bool {
  let bytes = @utf8.encode(url[:], bom=false)
  windows_open_url_bytes(bytes) != 0
}

///|
fn dispatch_windows_settings(
  request : @host.HostSettingsRequest,
) -> @host.HostServiceResponse {
  match request {
    Read(key) => {
      let key_bytes = @utf8.encode(key[:], bom=false)
      if windows_settings_has_value(key_bytes) == 0 {
        @host.HostServiceResponse::SettingValue(None)
      } else {
        @host.HostServiceResponse::SettingValue(
          Some(
            @utf8.decode_lossy(
              windows_settings_read_bytes(key_bytes)[:],
              ignore_bom=false,
            ),
          ),
        )
      }
    }
    Write(key, value) => {
      let key_bytes = @utf8.encode(key[:], bom=false)
      let value_bytes = @utf8.encode(value[:], bom=false)
      if windows_settings_write_bytes(key_bytes, value_bytes) != 0 {
        @host.HostServiceResponse::SettingWritten
      } else {
        @host.HostServiceResponse::Unavailable("settings write failed")
      }
    }
    Remove(key) => {
      let key_bytes = @utf8.encode(key[:], bom=false)
      if windows_settings_remove_bytes(key_bytes) != 0 {
        @host.HostServiceResponse::SettingRemoved
      } else {
        @host.HostServiceResponse::Unavailable("settings remove failed")
      }
    }
  }
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
    @host.HostClipboardRequest::ReadImage =>
      @host.HostServiceResponse::Unavailable(
        "clipboard image read is unavailable",
      )
    @host.HostClipboardRequest::WriteImage(_, _) =>
      @host.HostServiceResponse::Unavailable(
        "clipboard image write is unavailable",
      )
  }
}

///|
pub impl @win.ApplicationHandler for WindowsNativeHostBackend with fn can_create_surfaces(
  self,
  event_loop,
) {
  let initial_size = @window_input.core_size_to_window_surface_size(
    self.runtime.size(),
  )
  let attributes = @window_core.WindowAttributes::default()
    .with_title(self.title)
    .with_surface_size(initial_size)
  let window : @win.Window? = Some(event_loop.try_create_window(attributes)) catch {
    err => {
      println("error creating Windows window: \{err}")
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      let metrics = @window_input.make_surface_metrics(
        window.surface_size(),
        scale_factor=window.scale_factor(),
      )
      let window_id = self.lifecycle
        .window_registry()
        .open(title=self.title, metrics~, primary=true)
      ignore(
        self.lifecycle.bind_platform_window(platform_id=window.id(), window_id~),
      )
      self.register_primary_runtime_slot(window_id)
      self.driver.set_redraw_scheduler(() => {
        self.request_redraw_window_if_needed(window_id)
      })
      match (self.surface_binding.create_renderer)(window, metrics) {
        Some(resolution) => {
          let renderer = resolution
          ignore(
            @window_host.attach_window_surface(
              self.lifecycle,
              self.frames,
              self.images,
              window_id,
              renderer,
              self.windows_surface_actions(window, renderer),
            ),
          )
          self.driver.set_text_system(renderer.text_system())
          ignore(self.driver.dispatch(@host.Event::Resized(metrics)))
          ignore(
            self.platform_slots.insert(
              @window_lifecycle.WindowSlot::new(
                host_id=window_id,
                window~,
                extra=(),
              ),
            ),
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
pub impl @win.ApplicationHandler for WindowsNativeHostBackend with fn about_to_wait(
  self,
  event_loop,
) {
  match
    @window_host.platform_view_plugins_next_deadline(self.platform_view_plugins) {
    Some(deadline) =>
      event_loop.set_control_flow(
        @window_core.ControlFlow::wait_until(deadline),
      )
    None => event_loop.set_control_flow(@window_core.ControlFlow::Wait)
  }
  self.drain_window_requests(event_loop)
}

///|
fn WindowsNativeHostBackend::dispatch_pointer_or_context_menu(
  self : WindowsNativeHostBackend,
  window_id : @host.WindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  if @window_input.window_event_is_context_menu_button(event) {
    if @window_input.window_event_is_context_menu_trigger(event) {
      match self.lifecycle.runtime_slots().lookup(window_id) {
        Some(slot) =>
          ignore(slot.driver.show_context_menu(self.services.bridge()))
        None => ()
      }
      self.sync_text_input_session()
    }
  } else {
    self.dispatch_window_event(window_id, event)
  }
}

///|
fn WindowsNativeHostBackend::redraw_window(
  self : WindowsNativeHostBackend,
  window_id : @host.WindowId,
) -> Bool {
  match self.platform_slots.lookup_host(window_id) {
    Some(platform_slot) =>
      @window_host.run_window_redraw(
        self.lifecycle,
        self.frames,
        self.images,
        self.input,
        window_id,
        render=(renderer, _runtime_slot, submission) => {
          let frame = submission.frame()
          platform_slot.window.pre_present_notify()
          let result = renderer.render_frame(submission)
          @runtime.sync_platform_view_plugins(
            self.platform_view_plugins,
            platform_slot.window.native_window_handle(),
            frame,
          )
          result
        },
        finish_presented=runtime_slot => {
          @runtime.finish_first_frame_smoke_auto_exit(
            platform_name="Windows",
            title=runtime_slot.record.title,
            flag=self.first_frame_smoke_auto_exit,
            finish=fn() {
              self.first_frame_smoke_auto_exit = false
              self.dispose_window(window_id)
            },
          )
        },
      )
    None => false
  }
}

///|
/// Handle a decoded platform-view event received from a plugin's native event
/// dispatcher. Routes it into the runtime tree via
/// `HostRuntimeDriver::dispatch_platform_view`, bypassing `Event` entirely.
fn WindowsNativeHostBackend::dispatch_platform_view_event_from_plugin(
  self : WindowsNativeHostBackend,
  window_ptr : UInt64,
  id : String,
  event : @core.PlatformViewEvent,
) -> Unit {
  match self.platform_view_host_id(window_ptr) {
    Some(window_id) => {
      match self.lifecycle.runtime_slots().lookup(window_id) {
        Some(slot) => slot.driver.dispatch_platform_view(id, event)
        None => ()
      }
      self.sync_text_input_session()
      self.request_redraw_window_if_needed(window_id)
    }
    None => ()
  }
}

///|
/// Resolve a native window handle back to its `WindowId` by scanning the
/// live platform slots. Used to route native platform-view events.
fn WindowsNativeHostBackend::platform_view_host_id(
  self : WindowsNativeHostBackend,
  native_window : UInt64,
) -> @host.WindowId? {
  for slot in self.platform_slots.slots {
    if slot.window.native_window_handle() == native_window {
      return Some(slot.host_id)
    }
  }
  None
}

///|
fn WindowsNativeHostBackend::dispatch_window_event(
  self : WindowsNativeHostBackend,
  window_id : @host.WindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  match event {
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      self.modifiers = @window_input.modifiers_to_core(modifiers)
    _ => ()
  }
  let scale_factor = match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.scale_factor()
    None => 1.0
  }
  match
    windows_window_event_to_host(
      event,
      self.last_pointer,
      self.modifiers,
      scale_factor~,
    ) {
    Some(host_event) => self.dispatch_host_event(window_id, host_event)
    None => ()
  }
}

///|
fn windows_window_event_to_host(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
  modifiers : @core.KeyModifiers,
  scale_factor~ : Double,
) -> @host.Event? {
  @window_input.window_event_to_host_with_modifiers(
    event,
    last_pointer,
    modifiers,
    scale_factor~,
  )
}

///|
/// Dispatch an event produced by backend/common without re-decoding the
/// window event. Pointer, keyboard, IME, and drag events still use the native
/// decoder above.
fn WindowsNativeHostBackend::dispatch_host_event(
  self : WindowsNativeHostBackend,
  window_id : @host.WindowId,
  host_event : @host.Event,
) -> Unit {
  @window_host.dispatch_host_event(
    self.lifecycle,
    self.input,
    self.services,
    window_id,
    host_event,
    adjust=event => Some(event),
  )
}

///|
fn WindowsNativeHostBackend::drain_window_requests(
  self : WindowsNativeHostBackend,
  event_loop : @win.ActiveEventLoop,
) -> Unit {
  self.lifecycle.drain_window_requests(request => {
    self.apply_window_request(event_loop, request)
  })
}

///|
fn WindowsNativeHostBackend::apply_window_request(
  self : WindowsNativeHostBackend,
  event_loop : @win.ActiveEventLoop,
  request : @host.WindowRequest,
) -> @host.WindowRequestResult {
  @window_host.apply_window_request(
    self.lifecycle,
    self.input,
    self.services,
    request,
    open_window=open_request => self.open_window(event_loop, open_request),
    dispose_window=id => self.dispose_window(id),
    exit=() => event_loop.exit(),
  )
}

///|
fn WindowsNativeHostBackend::open_window(
  self : WindowsNativeHostBackend,
  event_loop : @win.ActiveEventLoop,
  request : @host.WindowOpenRequest,
) -> @host.WindowRequestResult {
  match self.lifecycle.open_resolution(request) {
    @runtime.WindowOpenResolution::OpenRejected(message) =>
      @host.WindowRequestResult::WindowRejected(message)
    @runtime.WindowOpenResolution::OpenResolved(resolved) =>
      self.create_resolved_window(event_loop, resolved)
  }
}

///|
fn WindowsNativeHostBackend::create_resolved_window(
  self : WindowsNativeHostBackend,
  event_loop : @win.ActiveEventLoop,
  resolved : @runtime.WindowResolvedOpen,
) -> @host.WindowRequestResult {
  let attributes = @window_core.WindowAttributes::default()
    .with_title(resolved.record.title)
    .with_surface_size(
      @window_input.host_metrics_to_dpi_size(resolved.record.metrics),
    )
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
      @host.WindowRequestResult::WindowRejected(
        "failed to create Windows window",
      )
    }
  }
}

///|
fn WindowsNativeHostBackend::attach_resolved_window(
  self : WindowsNativeHostBackend,
  window : @win.Window,
  resolved : @runtime.WindowResolvedOpen,
) -> @host.WindowRequestResult {
  let metrics = @window_input.make_surface_metrics(
    window.surface_size(),
    scale_factor=window.scale_factor(),
  )
  match (self.surface_binding.create_renderer)(window, metrics) {
    Some(resolution) => {
      let renderer = resolution
      ignore(self.lifecycle.window_registry().resize(resolved.id, metrics))
      ignore(
        self.lifecycle
        .runtime_slots()
        .sync_open_from_registry(self.lifecycle.window_registry()),
      )
      let record = match self.lifecycle.window_registry().lookup(resolved.id) {
        Some(record) => record
        None => resolved.record
      }
      let driver = @runtime.HostRuntimeDriver::new(
        runtime=resolved.instance.runtime,
        schedule_redraw=() => (),
      )
      driver.set_redraw_scheduler(() => {
        self.request_redraw_window_if_needed(resolved.id)
      })
      driver.set_environment(
        self.services
        .bridge()
        .environment_with_system_theme(driver.environment()),
      )
      driver.set_text_system(renderer.text_system())
      ignore(driver.dispatch(@host.Event::Resized(metrics)))
      ignore(
        self.lifecycle.register_runtime_slot(
          @window_lifecycle.WindowRuntimeSlot::from_driver(record~, driver~),
        ),
      )
      ignore(
        self.lifecycle.bind_platform_window(
          platform_id=window.id(),
          window_id=resolved.id,
        ),
      )
      ignore(
        self.platform_slots.insert(
          @window_lifecycle.WindowSlot::new(
            host_id=resolved.id,
            window~,
            extra=(),
          ),
        ),
      )
      ignore(
        @window_host.attach_window_surface(
          self.lifecycle,
          self.frames,
          self.images,
          resolved.id,
          renderer,
          self.windows_surface_actions(window, renderer),
        ),
      )
      self.request_platform_redraw(resolved.id)
      @host.WindowRequestResult::WindowOpened(resolved.id)
    }
    None => {
      window.drop()
      self.rollback_window_record(resolved.id)
      @host.WindowRequestResult::WindowRejected(
        "failed to create Windows renderer",
      )
    }
  }
}

///|
fn WindowsNativeHostBackend::register_primary_runtime_slot(
  self : WindowsNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  self.lifecycle.register_primary_runtime_slot(window_id, self.driver)
}

///|
fn WindowsNativeHostBackend::request_redraw(
  self : WindowsNativeHostBackend,
) -> Unit {
  @window_host.request_redraw(self.lifecycle, self.images)
}

///|
fn WindowsNativeHostBackend::request_redraw_window_if_needed(
  self : WindowsNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  @window_host.request_redraw_window_if_needed(
    self.lifecycle,
    self.images,
    window_id,
  )
}

///|
fn WindowsNativeHostBackend::request_platform_redraw(
  self : WindowsNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.request_redraw()
    None => ()
  }
}

///|
fn WindowsNativeHostBackend::dispose_window(
  self : WindowsNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  @window_host.dispose_window(
    self.lifecycle,
    self.frames,
    self.images,
    self.services,
    window_id,
  )
  ignore(self.platform_slots.remove_host(window_id))
}

///|
fn WindowsNativeHostBackend::rollback_window_record(
  self : WindowsNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  self.lifecycle.rollback_window_record(window_id)
}

///|
fn WindowsNativeHostBackend::sync_text_input_session(
  self : WindowsNativeHostBackend,
) -> Unit {
  @window_host.sync_text_input_session(self.lifecycle, self.input)
}

///|
fn WindowsNativeHostBackend::windows_surface_actions(
  self : WindowsNativeHostBackend,
  window : @win.Window,
  renderer : @render.RendererSession,
) -> @window_lifecycle.WindowSurfaceActions {
  @window_lifecycle.WindowSurfaceActions::new(
    focus=fn() { window.focus_window() },
    request_resize=fn(metrics) {
      ignore(
        window.request_surface_size(
          @window_input.host_metrics_to_dpi_size(metrics),
        ),
      )
      (self.surface_binding.sync_surface)(window, metrics)
      renderer.resize(@window_host.to_render_metrics(metrics))
      metrics
    },
    sync_observed_resize=fn(metrics) {
      (self.surface_binding.sync_surface)(window, metrics)
      renderer.resize(@window_host.to_render_metrics(metrics))
      metrics
    },
    set_minimized=fn(minimized) { window.set_minimized(minimized) },
    set_visible=fn(visible) { window.set_visible(visible) },
    request_redraw=fn() { window.request_redraw() },
    request_ime_update=fn(action) {
      match action {
        @window_input.TextInputSessionAction::EnableIme(request)
        | @window_input.TextInputSessionAction::UpdateIme(request)
        | @window_input.TextInputSessionAction::DisableIme(request) =>
          window.request_ime_update(request) catch {
            _ => ()
          }
        @window_input.TextInputSessionAction::NoImeChange => ()
      }
    },
    drop=fn() { window.drop() },
    native_view_handle=fn() { Some(window.native_window_handle()) },
    dispose_platform_views=fn() {
      let handle = window.native_window_handle()
      for plugin in self.platform_view_plugins {
        (plugin.dispose_platform_views)(handle)
      }
    },
  )
}
