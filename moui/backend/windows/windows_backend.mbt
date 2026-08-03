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
  kind : @runtime.NativeAccessibilityBridgeKind
  semantics_bridge_available : Bool
  native_platform_bridge_available : Bool
  action_dispatch_available : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub struct WindowsHostAppOptions {
  priv scene_resolver : @runtime.HostWindowSceneResolver
  priv event_sources : @runtime.HostPlatformEventSources?
  priv platform_view_plugins : Array[@host.PlatformViewPlugin]
}

///|
pub struct WindowsHostSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
}

///|
priv struct WindowsSurfaceBinding {
  create_renderer : (@win.Window, @host.HostSurfaceMetrics) -> @render.HostRendererResolution?
  sync_surface : (@win.Window, @host.HostSurfaceMetrics) -> Unit
}

///|
/// Native host backend: owns the Windows host runtime, native windows, and
/// event-loop integration rather than attaching a runtime to an embedder.
/// Platform-neutral window coordination (registry, runtime slots, requests,
/// image resources, IME) lives in `coordinator` (@runtime.WindowHostCoordinator).
struct WindowsNativeHostBackend {
  title : String
  runtime : @runtime.AppRuntime
  driver : @runtime.HostRuntimeDriver
  coordinator : @runtime.WindowHostCoordinator
  surface_binding : WindowsSurfaceBinding
  services : @host.HostServiceBridge
  platform_slots : @platform_bridge.WindowSlotMap[@win.Window, Unit]
  platform_view_plugins : Array[@host.PlatformViewPlugin]
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
  mut first_frame_smoke_auto_exit : Bool
}

///|
pub fn WindowsHostAppOptions::new(
  scene_resolver? : @runtime.HostWindowSceneResolver = @runtime.HostWindowSceneResolver::unavailable(),
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
  create_renderer~ : (@win.Window, @host.HostSurfaceMetrics) -> @render.HostRendererResolution?,
  sync_surface? : (@win.Window, @host.HostSurfaceMetrics) -> Unit = (
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
    let factories = request.renderer_factories()
    let image_source = @host_image_source.from_filesystem()
    let binding = WindowsSurfaceBinding::new(create_renderer=(window, metrics) => {
      let renderer_metrics = @platform_bridge.renderer_metrics_from_host(
        metrics,
      )
      let host_present = @render.HostPresentTarget::new(
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
      let gpu_surface = match
        @render.GpuHostSurfaceDescriptor::d3d12_hwnd(
          window.native_window_handle(),
        ) {
        Some(descriptor) =>
          Some(
            @render.HostGpuSurfaceBridge::new(
              descriptor~,
              create_surface=_ => None,
              present=_ => true,
            ),
          )
        None => None
      }
      let kit = @render.HostSurfaceKit::new(
        surface=@render.SurfaceDescriptor::cpu_raster(
          width=renderer_metrics.logical_size.width,
          height=renderer_metrics.logical_size.height,
          scale_factor=renderer_metrics.scale_factor,
        ),
        metrics=renderer_metrics,
        cpu_present=Some(host_present),
        gpu_surface~,
        image_source=Some(image_source),
      )
      @render.resolve_host_renderer(factories, kit)
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
  window_requests~ : @host.HostWindowRequestQueue,
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
    coordinator: @runtime.WindowHostCoordinator::new(
      window_requests~,
      scene_resolver=options.scene_resolver,
      services~,
      event_sources=options.event_sources,
    ),
    surface_binding: binding,
    services,
    platform_slots: @platform_bridge.WindowSlotMap::new(),
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
    kind: @runtime.NativeAccessibilityBridgeKind::UIAutomation,
    semantics_bridge_available: true,
    native_platform_bridge_available: false,
    action_dispatch_available: true,
    description: "Windows exposes a UI Automation accessibility bridge contract over the shared semantics tree; real UIA provider binding is still a backend follow-up.",
  }
}

///|
pub fn windows_accessibility_bridge(
  runtime : @runtime.AppRuntime,
) -> @runtime.NativeAccessibilityBridge {
  @runtime.NativeAccessibilityBridge::runtime(
    kind=@runtime.NativeAccessibilityBridgeKind::UIAutomation,
    runtime~,
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
    native_accessibility_available=windows_accessibility_bridge_info().native_platform_bridge_available,
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
fn dispatch_windows_binary_file(
  request : @host.HostBinaryFileRequest,
) -> @host.HostServiceResponse {
  match request {
    @host.HostBinaryFileRequest::ReadBytes(path) =>
      if @fs.path_exists(path) {
        let bytes = @fs.read_file_to_bytes(path) catch {
          _ => return @host.HostServiceResponse::Unavailable("file read failed")
        }
        @host.HostServiceResponse::BinaryFileContent(path, bytes)
      } else {
        @host.HostServiceResponse::Unavailable("file does not exist")
      }
    @host.HostBinaryFileRequest::WriteBytes(path, bytes) => {
      @fs.write_bytes_to_file(path, bytes) catch {
        _ => return @host.HostServiceResponse::Unavailable("file write failed")
      }
      @host.HostServiceResponse::BinaryFileWritten(path)
    }
  }
}

///|
fn dispatch_windows_menu(commands : Array[@core.ActionCommand]) -> Int {
  windows_show_menu_bytes(@platform_bridge.encode_menu_commands(commands))
}

///|
fn dispatch_windows_file_dialog(
  options : @host.HostFileDialogOptions,
) -> Array[String] {
  @platform_bridge.decode_file_dialog_selection(
    windows_file_dialog_bytes(
      @platform_bridge.host_file_dialog_kind_code(options.kind),
      @platform_bridge.encode_host_string(options.title),
      @platform_bridge.encode_host_filter_list(options.filters),
      @platform_bridge.encode_host_string(options.default_name.unwrap_or("")),
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
      let window_id = self.coordinator.windows.open(
        title=self.title,
        metrics~,
        primary=true,
      )
      ignore(
        self.coordinator.platform_windows.bind(
          platform_id=window.id(),
          host_id=window_id,
        ),
      )
      self.register_primary_runtime_slot(window_id)
      self.driver.set_redraw_scheduler(() => {
        self.request_redraw_window_if_needed(window_id)
      })
      match (self.surface_binding.create_renderer)(window, metrics) {
        Some(resolution) => {
          let renderer = resolution.renderer()
          ignore(
            self.coordinator.attach_surface(
              window_id,
              renderer,
              self.windows_surface_actions(window, renderer),
              image_loader=resolution.image_loader(),
            ),
          )
          self.bind_renderer_image_resource_changes(window_id)
          self.driver.set_text_system(renderer.text_system())
          ignore(self.driver.dispatch(@host.HostEvent::Resized(metrics)))
          ignore(
            self.platform_slots.insert(
              @platform_bridge.WindowSlot::new(
                host_id=window_id,
                platform_id=window.id(),
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
  self.drain_window_requests(event_loop)
}

///|
fn WindowsNativeHostBackend::dispatch_pointer_or_context_menu(
  self : WindowsNativeHostBackend,
  window_id : @host.HostWindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  if @host.window_event_is_context_menu_button(event) {
    if @host.window_event_is_context_menu_trigger(event) {
      match self.coordinator.runtime_slots.lookup(window_id) {
        Some(slot) => ignore(slot.driver.show_context_menu(self.services))
        None => ()
      }
      self.coordinator.sync_text_input_session()
    }
  } else {
    self.dispatch_window_event(window_id, event)
  }
}

///|
fn WindowsNativeHostBackend::redraw_window(
  self : WindowsNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Bool {
  match
    (
      self.platform_slots.lookup_host(window_id),
      self.coordinator.runtime_slots.lookup(window_id),
      self.coordinator.surface_renderer(window_id),
    ) {
    (Some(platform_slot), Some(runtime_slot), Some(renderer)) => {
      let prior_completions = renderer.drain_present_completions()
      let prior_presented = @render.render_present_completions_have_presented(
        prior_completions,
      )
      let prior_terminal = @render.render_present_completions_have_terminal(
        prior_completions,
      )
      let mut frame_pending = self.coordinator.surface_frame_pending(window_id)
      if frame_pending {
        if !prior_terminal {
          platform_slot.window.request_redraw()
          return false
        }
        frame_pending = false
        self.coordinator.set_surface_frame_pending(window_id, frame_pending)
        if prior_presented {
          ignore(
            self.coordinator.image_repaint_tracker.record_presented(
              @runtime.to_render_id(window_id),
              renderer,
            ),
          )
          ignore(
            self.coordinator.schedule_image_resource_loads(
              window_id,
              renderer,
              self.coordinator.image_resource_completion_source(),
            ),
          )
          self.coordinator.sync_text_input_session()
          if @runtime.finish_first_frame_smoke_auto_exit(
              platform_name="Windows",
              title=runtime_slot.record.title,
              flag=self.first_frame_smoke_auto_exit,
              finish=fn() {
                self.first_frame_smoke_auto_exit = false
                self.dispose_window(window_id)
              },
            ) {
            return true
          }
          if !@runtime.runtime_slot_needs_redraw(runtime_slot) {
            return false
          }
        }
      }
      platform_slot.window.pre_present_notify()
      runtime_slot.driver.begin_redraw()
      let frame = runtime_slot.driver.draw_frame()
      let result = renderer.render_frame(frame)
      let present_completions = renderer.drain_present_completions()
      let handle = platform_slot.window.native_window_handle()
      @runtime.sync_platform_view_plugins(
        self.platform_view_plugins,
        handle,
        frame,
      )
      runtime_slot.driver.apply_render_frame_result(result)
      runtime_slot.driver.finish_redraw()
      let completion_presented = @render.render_present_completions_have_presented(
        present_completions,
      )
      let completion_terminal = @render.render_present_completions_have_terminal(
        present_completions,
      )
      frame_pending = result.queued && !completion_terminal
      self.coordinator.set_surface_frame_pending(window_id, frame_pending)
      if completion_presented ||
        (present_completions.is_empty() && result.presented) {
        ignore(
          self.coordinator.image_repaint_tracker.record_presented(
            @runtime.to_render_id(window_id),
            renderer,
          ),
        )
      }
      ignore(
        self.coordinator.schedule_image_resource_loads(
          window_id,
          renderer,
          self.coordinator.image_resource_completion_source(),
        ),
      )
      self.coordinator.sync_text_input_session()
      let presented = completion_presented ||
        (present_completions.is_empty() && result.presented)
      if self.first_frame_smoke_auto_exit && presented {
        println(
          "Windows renderer presented first frame; exiting by request; title=" +
          runtime_slot.record.title,
        )
        self.first_frame_smoke_auto_exit = false
        self.dispose_window(window_id)
        true
      } else {
        if frame_pending ||
          (result.queued && completion_terminal && !completion_presented) {
          platform_slot.window.request_redraw()
        }
        false
      }
    }
    _ => false
  }
}

///|
/// Handle a decoded platform-view event received from a plugin's native event
/// dispatcher. Routes it into the runtime tree via
/// `HostRuntimeDriver::dispatch_platform_view`, bypassing `HostEvent` entirely.
fn WindowsNativeHostBackend::dispatch_platform_view_event_from_plugin(
  self : WindowsNativeHostBackend,
  window_ptr : UInt64,
  id : String,
  event : @core.PlatformViewEvent,
) -> Unit {
  match self.platform_view_host_id(window_ptr) {
    Some(window_id) => {
      match self.coordinator.runtime_slots.lookup(window_id) {
        Some(slot) => slot.driver.dispatch_platform_view(id, event)
        None => ()
      }
      self.coordinator.sync_text_input_session()
      self.request_redraw_window_if_needed(window_id)
    }
    None => ()
  }
}

///|
/// Resolve a native window handle back to its `HostWindowId` by scanning the
/// live platform slots. Used to route native platform-view events.
fn WindowsNativeHostBackend::platform_view_host_id(
  self : WindowsNativeHostBackend,
  native_window : UInt64,
) -> @host.HostWindowId? {
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
  window_id : @host.HostWindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  match event {
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      self.modifiers = @host.modifiers_to_core(modifiers)
    _ => ()
  }
  match
    @host.window_event_to_host_with_modifiers(
      event,
      self.last_pointer,
      self.modifiers,
    ) {
    Some(host_event) => self.dispatch_host_event(window_id, host_event)
    None => ()
  }
}

///|
/// Dispatch an event produced by Platform Bridge without re-decoding the
/// window event. Pointer, keyboard, IME, and drag events still use the native
/// decoder above.
fn WindowsNativeHostBackend::dispatch_host_event(
  self : WindowsNativeHostBackend,
  window_id : @host.HostWindowId,
  host_event : @host.HostEvent,
) -> Unit {
  ignore(
    self.coordinator.runtime_slots.apply_host_event(
      self.coordinator.windows,
      window_id,
      host_event,
    ),
  )
  match self.coordinator.runtime_slots.lookup(window_id) {
    Some(slot) =>
      match host_event {
        @host.HostEvent::Keyboard(event) =>
          ignore(
            slot.driver.dispatch_keyboard_with_services(event, self.services),
          )
        _ => ignore(slot.driver.dispatch(host_event))
      }
    None => ()
  }
  ignore(self.publish_subscription_event(window_id, host_event))
  self.coordinator.sync_text_input_session()
}

///|
fn WindowsNativeHostBackend::publish_subscription_event(
  self : WindowsNativeHostBackend,
  window_id : @host.HostWindowId,
  event : @host.HostEvent,
) -> @runtime.HostPlatformEventPublishResult? {
  match self.coordinator.event_sources {
    Some(sources) => Some(sources.publish(window_id~, event~))
    None => None
  }
}

///|
fn WindowsNativeHostBackend::drain_window_requests(
  self : WindowsNativeHostBackend,
  event_loop : @win.ActiveEventLoop,
) -> Unit {
  ignore(
    self.coordinator.window_requests.drain_with_handler(request => {
      self.apply_window_request(event_loop, request)
    }),
  )
}

///|
fn WindowsNativeHostBackend::apply_window_request(
  self : WindowsNativeHostBackend,
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
        if self.coordinator.runtime_slots_empty() {
          event_loop.exit()
        }
      })
    @host.HostWindowRequest::ResizeWindow(id, metrics) =>
      self.apply_platform_window_request(id, request, window => {
        ignore(
          window.request_surface_size(@host.host_metrics_to_dpi_size(metrics)),
        )
        (self.surface_binding.sync_surface)(window, metrics)
        match self.coordinator.surface_actions(id) {
          Some(actions) =>
            (actions.renderer_resize)(@runtime.to_render_metrics(metrics))
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
fn WindowsNativeHostBackend::apply_platform_window_request(
  self : WindowsNativeHostBackend,
  id : @host.HostWindowId,
  request : @host.HostWindowRequest,
  apply : (@win.Window) -> Unit,
) -> @host.HostWindowRequestResult {
  match self.platform_slots.lookup_host(id) {
    Some(slot) => {
      let result = self.coordinator.runtime_slots.apply_request(
        self.coordinator.windows,
        request,
      )
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
fn WindowsNativeHostBackend::open_window(
  self : WindowsNativeHostBackend,
  event_loop : @win.ActiveEventLoop,
  request : @host.HostWindowOpenRequest,
) -> @host.HostWindowRequestResult {
  match self.coordinator.open_resolution(request) {
    @runtime.HostWindowOpenResolution::OpenRejected(message) =>
      @host.HostWindowRequestResult::WindowRejected(message)
    @runtime.HostWindowOpenResolution::OpenResolved(resolved) =>
      self.create_resolved_window(event_loop, resolved)
  }
}

///|
fn WindowsNativeHostBackend::create_resolved_window(
  self : WindowsNativeHostBackend,
  event_loop : @win.ActiveEventLoop,
  resolved : @runtime.HostWindowResolvedOpen,
) -> @host.HostWindowRequestResult {
  let attributes = @window_core.WindowAttributes::default()
    .with_title(resolved.record.title)
    .with_surface_size(@host.host_metrics_to_dpi_size(resolved.record.metrics))
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
fn WindowsNativeHostBackend::attach_resolved_window(
  self : WindowsNativeHostBackend,
  window : @win.Window,
  resolved : @runtime.HostWindowResolvedOpen,
) -> @host.HostWindowRequestResult {
  let metrics = @host.HostSurfaceMetrics::new(
    logical_size=@host.physical_size_to_core(window.surface_size()),
    physical_size=@host.physical_size_to_core(window.surface_size()),
  )
  match (self.surface_binding.create_renderer)(window, metrics) {
    Some(resolution) => {
      let renderer = resolution.renderer()
      ignore(self.coordinator.windows.resize(resolved.id, metrics))
      ignore(
        self.coordinator.runtime_slots.sync_open_from_registry(
          self.coordinator.windows,
        ),
      )
      let record = match self.coordinator.windows.lookup(resolved.id) {
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
        self.services.environment_with_system_theme(driver.environment()),
      )
      driver.set_text_system(renderer.text_system())
      ignore(driver.dispatch(@host.HostEvent::Resized(metrics)))
      ignore(
        self.coordinator.runtime_slots.insert(
          @runtime.HostWindowRuntimeSlot::from_driver(record~, driver~),
        ),
      )
      ignore(
        self.coordinator.platform_windows.bind(
          platform_id=window.id(),
          host_id=resolved.id,
        ),
      )
      ignore(
        self.platform_slots.insert(
          @platform_bridge.WindowSlot::new(
            host_id=resolved.id,
            platform_id=window.id(),
            window~,
            extra=(),
          ),
        ),
      )
      ignore(
        self.coordinator.attach_surface(
          resolved.id,
          renderer,
          self.windows_surface_actions(window, renderer),
          image_loader=resolution.image_loader(),
        ),
      )
      self.bind_renderer_image_resource_changes(resolved.id)
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
fn WindowsNativeHostBackend::register_primary_runtime_slot(
  self : WindowsNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Unit {
  self.coordinator.register_primary_runtime_slot(window_id, self.driver)
}

///|
fn WindowsNativeHostBackend::request_redraw(
  self : WindowsNativeHostBackend,
) -> Unit {
  match self.coordinator.active_runtime_slot() {
    Some(slot) => self.request_redraw_window_if_needed(slot.id)
    None => ()
  }
}

///|
fn WindowsNativeHostBackend::request_redraw_window_if_needed(
  self : WindowsNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Unit {
  self.coordinator.request_redraw_window_if_needed(window_id)
}

///|
fn WindowsNativeHostBackend::bind_renderer_image_resource_changes(
  self : WindowsNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Unit {
  self.coordinator.bind_renderer_image_resource_changes(window_id)
}

///|
fn WindowsNativeHostBackend::request_platform_redraw(
  self : WindowsNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Unit {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.request_redraw()
    None => ()
  }
}

///|
fn WindowsNativeHostBackend::dispose_window(
  self : WindowsNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Unit {
  self.coordinator.dispose_window(window_id)
  match self.platform_slots.remove_host(window_id) {
    Some(slot) => {
      let handle = slot.window.native_window_handle()
      for plugin in self.platform_view_plugins {
        (plugin.dispose_platform_views)(handle)
      }
      slot.window.drop()
    }
    None => ()
  }
}

///|
fn WindowsNativeHostBackend::rollback_window_record(
  self : WindowsNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Unit {
  self.coordinator.rollback_window_record(window_id)
}

///|
fn WindowsNativeHostBackend::windows_surface_actions(
  self : WindowsNativeHostBackend,
  window : @win.Window,
  renderer : @render.HostWindowRenderer,
) -> @runtime.WindowSurfaceActions {
  @runtime.WindowSurfaceActions::new(
    focus=fn() { window.focus_window() },
    request_surface_size=fn(metrics) {
      ignore(
        window.request_surface_size(@host.host_metrics_to_dpi_size(metrics)),
      )
    },
    sync_surface=fn(metrics) {
      (self.surface_binding.sync_surface)(window, metrics)
    },
    renderer_resize=fn(metrics) { renderer.resize(metrics) },
    set_minimized=fn(minimized) { window.set_minimized(minimized) },
    set_visible=fn(visible) { window.set_visible(visible) },
    request_redraw=fn() { window.request_redraw() },
    request_ime_update=fn(action) {
      match action {
        @host.TextInputSessionAction::EnableIme(request)
        | @host.TextInputSessionAction::UpdateIme(request)
        | @host.TextInputSessionAction::DisableIme(request) =>
          window.request_ime_update(request) catch {
            _ => ()
          }
        @host.TextInputSessionAction::NoImeChange => ()
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

///|
fn size_dim_to_int(value : Double) -> Int {
  if value < 1.0 {
    1
  } else {
    value.to_int()
  }
}
