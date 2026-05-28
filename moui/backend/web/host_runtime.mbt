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
  runtime : @core.AppRuntime
  driver : @host.HostRuntimeDriver
  text_input_session : @host.TextInputSession
  services : @host.HostServiceBridge
  async_services : @host.HostServiceAsyncQueue
  window_requests : @host.HostWindowRequestQueue
  scene_resolver : @host.HostWindowSceneResolver
  windows : @host.HostWindowRegistry
  runtime_slots : @host.HostWindowRuntimeSlots
  platform_windows : @host.HostPlatformWindowMap
  platform_slots : WebWindowPlatformSlots
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
}

///|
priv struct WebWindowPlatformSlot {
  host_id : @host.HostWindowId
  platform_id : @window_core.WindowId
  window : @window_web.Window
  renderer : WebRenderer
}

///|
pub(all) struct WebAppOptions {
  scene_resolver : @host.HostWindowSceneResolver
}

///|
priv struct WebWindowPlatformSlots {
  mut slots : Array[WebWindowPlatformSlot]
}

///|
pub fn backend_info() -> WebBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Web,
      description="canonical wzzc-dev/window web host for wasm-gc WebGPU",
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
  run_app_with_options(
    title,
    runtime,
    options=WebAppOptions::new(),
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
    options=WebAppOptions::new(),
    window_requests~,
  )
}

///|
pub fn run_app_with_options(
  title : String,
  runtime : @core.AppRuntime,
  options~ : WebAppOptions,
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
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
    runtime,
    driver: @host.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    text_input_session: @host.TextInputSession::new(),
    services,
    async_services,
    window_requests,
    scene_resolver: options.scene_resolver,
    windows: @host.HostWindowRegistry::new(),
    runtime_slots: @host.HostWindowRuntimeSlots::new(),
    platform_windows: @host.HostPlatformWindowMap::new(),
    platform_slots: WebWindowPlatformSlots::new(),
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
  }
  app.driver.set_redraw_scheduler(() => app.request_redraw())
  event_loop.spawn_app(app)
}

///|
pub fn WebAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
) -> WebAppOptions {
  { scene_resolver, }
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
fn WebWindowPlatformSlots::new() -> WebWindowPlatformSlots {
  { slots: [] }
}

///|
fn WebWindowPlatformSlots::insert(
  self : WebWindowPlatformSlots,
  slot : WebWindowPlatformSlot,
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
fn WebWindowPlatformSlots::lookup_host(
  self : WebWindowPlatformSlots,
  host_id : @host.HostWindowId,
) -> WebWindowPlatformSlot? {
  for slot in self.slots {
    if slot.host_id == host_id {
      return Some(slot)
    }
  }
  None
}

///|
fn WebWindowPlatformSlots::lookup_platform(
  self : WebWindowPlatformSlots,
  platform_id : @window_core.WindowId,
) -> WebWindowPlatformSlot? {
  for slot in self.slots {
    if slot.platform_id == platform_id {
      return Some(slot)
    }
  }
  None
}

///|
fn WebWindowPlatformSlots::remove_host(
  self : WebWindowPlatformSlots,
  host_id : @host.HostWindowId,
) -> WebWindowPlatformSlot? {
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
      ignore(
        self.platform_windows.bind(platform_id=window.id(), host_id=window_id),
      )
      self.register_primary_runtime_slot(window_id)
      self.driver.set_redraw_scheduler(() => {
        self.request_redraw_window_if_needed(window_id)
      })
      let renderer_result = try? WebRenderer::create(
        canvas_id=window_web_default_canvas_id(window.id().into_raw()),
        metrics~,
      )
      match renderer_result {
        Ok(renderer) => {
          self.driver.set_text_system(renderer.text_system())
          match self.runtime_slots.lookup(window_id) {
            Some(slot) =>
              ignore(slot.driver.dispatch(@host.HostEvent::Resized(metrics)))
            None => ()
          }
          ignore(
            self.platform_slots.insert({
              host_id: window_id,
              platform_id: window.id(),
              window,
              renderer,
            }),
          )
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
  self.redraw_dirty_windows()
}

///|
pub impl @window_web.ApplicationHandler for WebApp with window_event(
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
      self.request_platform_redraw(window_id)
    }
    @window_core.WindowEvent::ScaleFactorChanged(_, _) => {
      self.dispatch_window_event(window_id, event)
      self.request_platform_redraw(window_id)
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
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      self.modifiers = @host.modifiers_to_core(modifiers)
    @window_core.WindowEvent::RedrawRequested => self.redraw_window(window_id)
    _ => self.dispatch_window_event(window_id, event)
  }
}

///|
fn WebApp::dispatch_pointer_or_context_menu(
  self : WebApp,
  window_id : @host.HostWindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  if @host.window_event_is_context_menu_button(event) {
    if @host.window_event_is_context_menu_trigger(event) {
      match self.runtime_slots.lookup(window_id) {
        Some(slot) => ignore(slot.driver.show_context_menu(self.services))
        None => ()
      }
      self.drain_async_host_services()
      self.sync_text_input_session()
    }
  } else {
    self.dispatch_window_event(window_id, event)
  }
}

///|
fn WebApp::redraw_window(self : WebApp, window_id : @host.HostWindowId) -> Unit {
  match
    (
      self.platform_slots.lookup_host(window_id),
      self.runtime_slots.lookup(window_id),
    ) {
    (Some(platform_slot), Some(runtime_slot)) => {
      runtime_slot.driver.begin_redraw()
      platform_slot.renderer.render(runtime_slot.driver.draw_commands()) catch {
        err => {
          let _ = err
        }
      }
      runtime_slot.driver.finish_redraw()
    }
    _ => ()
  }
  self.sync_text_input_session()
}

///|
fn WebApp::dispatch_window_event(
  self : WebApp,
  window_id : @host.HostWindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  self.modifiers = web_modifiers_after_window_event(self.modifiers, event)
  match
    window_event_to_host_with_scale(
      event,
      self.last_pointer,
      self.modifiers,
      scale_factor=self.current_scale_factor(window_id),
    ) {
    Some(host_event) => {
      self.apply_window_lifecycle(window_id, host_event)
      match self.runtime_slots.lookup(window_id) {
        Some(slot) =>
          match host_event {
            @host.HostEvent::Resized(metrics) => {
              self.resize_renderer(window_id, metrics)
              ignore(slot.driver.dispatch(host_event))
            }
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
    match self.active_runtime_slot() {
      Some(slot) =>
        ignore(
          slot.driver.dispatch_service_completion(completion, self.services),
        )
      None => ()
    }
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
        self.resize_renderer(id, metrics)
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
fn WebApp::apply_platform_window_request(
  self : WebApp,
  id : @host.HostWindowId,
  request : @host.HostWindowRequest,
  apply : (@window_web.Window) -> Unit,
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
        "window request has no active Web window",
      )
  }
}

///|
fn WebApp::open_window(
  self : WebApp,
  event_loop : @window_web.ActiveEventLoop,
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
fn WebApp::create_resolved_window(
  self : WebApp,
  event_loop : @window_web.ActiveEventLoop,
  resolved : @host.HostWindowResolvedOpen,
) -> @host.HostWindowRequestResult {
  let attributes = @window_core.WindowAttributes::default()
    .with_title(resolved.record.title)
    .with_surface_size(host_metrics_to_dpi_size(resolved.record.metrics))
  let window : @window_web.Window? = Some(
    event_loop.try_create_window(attributes),
  ) catch {
    _ => None
  }
  match window {
    Some(window) => self.attach_resolved_window(window, resolved)
    None => {
      self.rollback_resolved_window(resolved.id)
      @host.HostWindowRequestResult::WindowRejected(
        "failed to create Web window",
      )
    }
  }
}

///|
fn WebApp::attach_resolved_window(
  self : WebApp,
  window : @window_web.Window,
  resolved : @host.HostWindowResolvedOpen,
) -> @host.HostWindowRequestResult {
  let metrics = surface_metrics_from_physical(
    window.surface_size(),
    window.scale_factor(),
  )
  let renderer_result = try? WebRenderer::create(
    canvas_id=window_web_default_canvas_id(window.id().into_raw()),
    metrics~,
  )
  match renderer_result {
    Ok(renderer) => {
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
    Err(_) => {
      window.drop()
      self.rollback_resolved_window(resolved.id)
      @host.HostWindowRequestResult::WindowRejected(
        "failed to create Web renderer",
      )
    }
  }
}

///|
fn WebApp::rollback_resolved_window(
  self : WebApp,
  id : @host.HostWindowId,
) -> Unit {
  ignore(self.windows.close(id))
  ignore(self.windows.remove_closed())
  ignore(self.runtime_slots.sync_open_from_registry(self.windows))
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
fn WebApp::sync_runtime_slots(self : WebApp) -> Unit {
  ignore(self.runtime_slots.sync_open_from_registry(self.windows))
}

///|
fn WebApp::active_runtime_slot(self : WebApp) -> @host.HostWindowRuntimeSlot? {
  match self.runtime_slots.focused_slot() {
    Some(slot) => Some(slot)
    None => self.runtime_slots.primary_slot()
  }
}

///|
fn runtime_slot_needs_redraw(slot : @host.HostWindowRuntimeSlot) -> Bool {
  let result = slot.driver.event_result()
  result.needs_redraw || result.redraw_requested
}

///|
fn WebApp::redraw_dirty_windows(self : WebApp) -> Unit {
  for slot in self.runtime_slots.open_slots() {
    if runtime_slot_needs_redraw(slot) {
      self.redraw_window(slot.id)
    }
  }
}

///|
fn WebApp::apply_window_lifecycle(
  self : WebApp,
  window_id : @host.HostWindowId,
  host_event : @host.HostEvent,
) -> Unit {
  ignore(
    self.runtime_slots.apply_host_event(self.windows, window_id, host_event),
  )
}

///|
fn WebApp::sync_text_input_session(self : WebApp) -> Unit {
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
fn WebApp::current_scale_factor(
  self : WebApp,
  window_id : @host.HostWindowId,
) -> Double {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.scale_factor()
    None => 1.0
  }
}

///|
fn WebApp::resize_renderer(
  self : WebApp,
  window_id : @host.HostWindowId,
  metrics : @host.HostSurfaceMetrics,
) -> Unit {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) =>
      slot.renderer.resize(metrics) catch {
        err => {
          let _ = err
        }
      }
    None => ()
  }
}

///|
fn WebApp::request_redraw(self : WebApp) -> Unit {
  match self.active_runtime_slot() {
    Some(slot) => self.request_redraw_window_if_needed(slot.id)
    None => ()
  }
}

///|
fn WebApp::request_redraw_window_if_needed(
  self : WebApp,
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
fn WebApp::request_platform_redraw(
  self : WebApp,
  window_id : @host.HostWindowId,
) -> Unit {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.request_redraw()
    None => ()
  }
}

///|
fn WebApp::dispose_window(
  self : WebApp,
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
  if self.runtime_slots.is_empty() {
    set_web_async_host_service_queue(None)
  }
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
