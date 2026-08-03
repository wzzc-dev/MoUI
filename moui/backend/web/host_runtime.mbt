///|
pub(all) struct WebBackendInfo {
  host_info : @host.HostAppInfo
  uses_window_web_backend : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
struct WebApp {
  title : String
  runtime : @runtime.AppRuntime
  driver : @runtime.HostRuntimeDriver
  services : @host.HostServiceBridge
  async_services : @host.HostServiceAsyncQueue
  coordinator : @runtime.WindowHostCoordinator
  renderer_factories : Array[@render.RendererBindingFactory]
  platform_slots : WebWindowPlatformSlots
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
      description="canonical wzzc-dev/window browser host for wasm-gc",
    ),
    uses_window_web_backend: true,
    description: "Canonical web path: window/web owns canvas events, canvas surface identifiers, and redraw scheduling on wasm-gc; the application supplies renderer factories.",
  }
}

///|
fn run_app_internal(
  title : String,
  runtime : @runtime.AppRuntime,
  renderer_factories : Array[@render.RendererBindingFactory],
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
  let coordinator = @runtime.WindowHostCoordinator::new(
    window_requests~,
    scene_resolver=options.scene_resolver,
    services~,
    event_sources=options.event_sources,
  )
  let app = WebApp::{
    title,
    runtime,
    driver: @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    services,
    async_services,
    coordinator,
    renderer_factories,
    platform_slots: WebWindowPlatformSlots::new(),
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
  }
  web_active_app.val = Some(app)
  app.driver.set_redraw_scheduler(() => ())
  event_loop.spawn_app(app)
}

///|
pub fn entry(
  options? : WebAppOptions = WebAppOptions::new(),
) -> @runtime.PlatformEntry {
  @runtime.PlatformEntry::new(id="web", launch=request => {
    run_app_internal(
      request.title(),
      request.runtime(),
      request.renderer_factories(),
      options~,
      window_requests=request.window_requests(),
    )
  })
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
      self.coordinator.register_primary_runtime_slot(window_id, self.driver)
      self.driver.set_redraw_scheduler(() => {
        self.coordinator.request_redraw_window_if_needed(window_id)
      })
      match
        resolve_web_renderer(
          self.renderer_factories,
          window_web_default_canvas_id(window.id().into_raw()),
          metrics,
        ) {
        None => {
          window.drop()
          event_loop.exit()
        }
        Some(resolution) => {
          let renderer = resolution.renderer()
          self.driver.set_text_system(renderer.text_system())
          match self.coordinator.runtime_slot_lookup(window_id) {
            Some(slot) =>
              ignore(slot.driver.dispatch(@host.HostEvent::Resized(metrics)))
            None => ()
          }
          ignore(
            self.coordinator.attach_surface(
              window_id,
              renderer,
              self.web_surface_actions(window, renderer),
              image_loader=resolution.image_loader(),
            ),
          )
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
      self.coordinator.runtime_slots.lookup(window_id),
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
  self.coordinator.sync_text_input_session()
}

///|
fn WebApp::drain_async_host_services(self : WebApp) -> Unit {
  for request in drain_web_async_host_service_requests(self.async_services) {
    dispatch_web_async_host_service_request(request)
  }
  for completion in self.async_services.drain_completed() {
    match self.coordinator.active_runtime_slot() {
      Some(slot) =>
        ignore(
          slot.driver.dispatch_service_completion(completion, self.services),
        )
      None => ()
    }
  }
}

///|
fn runtime_slot_needs_redraw(slot : @runtime.HostWindowRuntimeSlot) -> Bool {
  let result = slot.driver.event_result()
  result.needs_redraw || result.redraw_requested
}

///|
fn WebApp::redraw_dirty_windows(self : WebApp) -> Unit {
  for slot in self.coordinator.runtime_slots.open_slots() {
    if runtime_slot_needs_redraw(slot) {
      self.redraw_window(slot.id)
    }
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
      slot.renderer.resize(
        @render.RendererSurfaceMetrics::new(
          logical_size=metrics.logical_size,
          physical_size=metrics.physical_size,
          scale_factor=metrics.scale_factor,
        ),
      )
    None => ()
  }
}

///|
/// Platform window actions for the coordinator. Closures capture only the
/// native window and its renderer; web-specific semantics teardown happens
/// in `dispose_platform_views`.
fn WebApp::web_surface_actions(
  _self : WebApp,
  window : @window_web.Window,
  renderer : @render.HostWindowRenderer,
) -> @runtime.WindowSurfaceActions {
  @runtime.WindowSurfaceActions::new(
    focus=fn() { window.focus_window() },
    request_surface_size=fn(metrics) {
      ignore(
        window.request_surface_size(@host.host_metrics_to_dpi_size(metrics)),
      )
    },
    sync_surface=fn(_metrics) { () },
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
    native_view_handle=fn() { None },
    dispose_platform_views=fn() {
      unregister_web_semantics_runtime(window.id().into_raw())
    },
  )
}

///|
fn resolve_web_renderer(
  factories : Array[@render.RendererBindingFactory],
  surface_id : String,
  metrics : @host.HostSurfaceMetrics,
) -> @render.HostRendererResolution? {
  let renderer_metrics = @render.RendererSurfaceMetrics::new(
    logical_size=metrics.logical_size,
    physical_size=metrics.physical_size,
    scale_factor=metrics.scale_factor,
  )
  let kit = @render.HostSurfaceKit::new(
    surface=@render.SurfaceDescriptor::cpu_raster(
      width=metrics.logical_size.width,
      height=metrics.logical_size.height,
      scale_factor=metrics.scale_factor,
    ),
    surface_id~,
    metrics=renderer_metrics,
  )
  @render.resolve_host_renderer(factories, kit)
}

///|
fn WebApp::dispose_window(
  self : WebApp,
  window_id : @host.HostWindowId,
) -> Unit {
  self.coordinator.dispose_window(window_id)
  ignore(self.platform_slots.remove_host(window_id))
  if self.coordinator.runtime_slots_empty() {
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
