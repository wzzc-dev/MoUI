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
  runtime : @runtime.AppRuntime
  driver : @runtime.HostRuntimeDriver
  text_input_session : @host.TextInputSession
  services : @host.HostServiceBridge
  async_services : @host.HostServiceAsyncQueue
  window_requests : @host.HostWindowRequestQueue
  scene_resolver : @runtime.HostWindowSceneResolver
  windows : @host.HostWindowRegistry
  runtime_slots : @runtime.HostWindowRuntimeSlots
  platform_windows : @host.HostPlatformWindowMap
  platform_slots : WebWindowPlatformSlots
  event_sources : @runtime.HostPlatformEventSources?
  mut last_pointer : @core.Point
  mut modifiers : @core.KeyModifiers
}

///|
/// The wasm export boundary is synchronous, while `window/web` owns a
/// callback-oriented event loop. Keep the active app reachable so pointer
/// inputs can return consumption flags without turning browser input into a
/// deferred synthetic window event.
let web_active_app : Ref[WebApp?] = Ref(None)

///|
pub(all) struct WebAppOptions {
  scene_resolver : @runtime.HostWindowSceneResolver
  event_sources : @runtime.HostPlatformEventSources?
  route_source : @runtime.HostRouteSource?
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
pub fn run_app(title : String, runtime : @runtime.AppRuntime) -> Unit {
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
  runtime : @runtime.AppRuntime,
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
  runtime : @runtime.AppRuntime,
  options~ : WebAppOptions,
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  let event_loop = @window_web.EventLoop::new()
  event_loop.set_control_flow(@window_core.ControlFlow::Poll)
  let async_services = web_async_host_service_queue()
  set_web_async_host_service_queue(Some(async_services))
  set_web_route_source(options.route_source)
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
    file_access=true,
    async_queue=Some(async_services),
  )
  runtime.set_environment(
    services.environment_with_system_theme(runtime.environment()),
  )
  let app = WebApp::{
    title,
    runtime,
    driver: @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    text_input_session: @host.TextInputSession::new(),
    services,
    async_services,
    window_requests,
    scene_resolver: options.scene_resolver,
    windows: @host.HostWindowRegistry::new(),
    runtime_slots: @runtime.HostWindowRuntimeSlots::new(),
    platform_windows: @host.HostPlatformWindowMap::new(),
    platform_slots: WebWindowPlatformSlots::new(),
    event_sources: options.event_sources,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
  }
  web_active_app.val = Some(app)
  app.driver.set_redraw_scheduler(() => app.request_redraw())
  event_loop.spawn_app(app)
}

///|
pub fn WebAppOptions::new(
  scene_resolver? : @runtime.HostWindowSceneResolver = @runtime.HostWindowSceneResolver::unavailable(),
  event_sources? : @runtime.HostPlatformEventSources? = None,
  route_source? : @runtime.HostRouteSource? = None,
) -> WebAppOptions {
  { scene_resolver, event_sources, route_source }
}

///|
pub impl @window_web.ApplicationHandler for WebApp with fn can_create_surfaces(
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
      try
        WebRenderer::create(
          canvas_id=window_web_default_canvas_id(window.id().into_raw()),
          metrics~,
        )
      catch {
        err => {
          let _ = err
          window.drop()
          event_loop.exit()
        }
      } noraise {
        renderer => {
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
          register_web_semantics_runtime(
            window.id().into_raw(),
            window_web_default_canvas_id(window.id().into_raw()),
            self.runtime,
          )
          window.request_redraw()
        }
      }
    }
    None => ()
  }
}

///|
pub impl @window_web.ApplicationHandler for WebApp with fn new_events(
  self,
  event_loop,
  _cause,
) {
  self.drain_window_requests(event_loop)
  if event_loop.exiting() {
    return ()
  }
  web_timer_dispatch_due()
  self.drain_async_host_services()
  sync_all_web_semantics()
  self.redraw_dirty_windows()
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
      let result = platform_slot.renderer.render_frame(
        runtime_slot.driver.draw_frame(),
      )
      runtime_slot.driver.apply_render_frame_result(result)
      runtime_slot.driver.finish_redraw()
    }
    _ => ()
  }
  self.sync_text_input_session()
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
fn WebApp::active_runtime_slot(self : WebApp) -> @runtime.HostWindowRuntimeSlot? {
  match self.runtime_slots.focused_slot() {
    Some(slot) => Some(slot)
    None => self.runtime_slots.primary_slot()
  }
}

///|
fn runtime_slot_needs_redraw(slot : @runtime.HostWindowRuntimeSlot) -> Bool {
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
      unregister_web_semantics_runtime(slot.platform_id.into_raw())
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
