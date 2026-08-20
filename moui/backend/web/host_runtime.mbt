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
  services : @window_services.WindowServiceState
  async_services : @window_services.ServiceAsyncQueue
  lifecycle : @window_lifecycle.WindowLifecycle
  frames : @window_frame.WindowFrameStates
  images : @window_image.WindowImageTaskStates
  input : @window_input.WindowInputState
  renderer_providers : Array[@render.RendererProvider]
  platform_view_plugins : Array[@host.PlatformViewPlugin]
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
  scene_resolver : @runtime.WindowSceneResolver
  event_sources : @runtime.HostPlatformEventSources?
  route_source : @services.RouteSource?
  platform_view_plugins : Array[@host.PlatformViewPlugin]
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
  renderer_providers : Array[@render.RendererProvider],
  options~ : WebAppOptions,
  window_requests? : @host.WindowRequests = @window_lifecycle.WindowRequestQueue::new().requests(),
) -> Unit {
  let event_loop = @window_web.EventLoop::new()
  event_loop.set_control_flow(@window_core.ControlFlow::Poll)
  let async_services = web_async_host_service_queue()
  set_web_async_host_service_queue(Some(async_services))
  set_web_route_source(options.route_source)
  let services = web_service_bridge(
    system_theme=match event_loop.system_theme() {
      Some(theme) => @window_input.window_theme_to_color_scheme(theme)
      None => @core.ColorScheme::Light
    },
    open_url=dispatch_web_open_url,
    clipboard=true,
    clipboard_read=true,
    clipboard_write=dispatch_web_clipboard_write_text,
    file_dialog=true,
    file_access=true,
    settings_available=true,
    settings=dispatch_web_settings,
    async_queue=Some(async_services),
  )
  runtime.set_environment(
    services.environment_with_system_theme(runtime.environment()),
  )
  let lifecycle = @window_lifecycle.WindowLifecycle::new(
    requests=window_requests,
    scene_resolver=options.scene_resolver,
  )
  let app = WebApp::{
    title,
    runtime,
    driver: @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    services: @window_services.WindowServiceState::new(bridge=services),
    async_services,
    lifecycle,
    frames: @window_frame.WindowFrameStates::new(),
    images: @window_image.WindowImageTaskStates::new(),
    input: @window_input.WindowInputState::new(
      event_sources=options.event_sources,
    ),
    renderer_providers,
    platform_view_plugins: options.platform_view_plugins,
    platform_slots: WebWindowPlatformSlots::new(),
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
  }
  web_active_app.val = Some(app)
  @runtime.install_platform_view_plugins(options.platform_view_plugins, (
    _window_ptr,
    id,
    event,
  ) => {
    match app.lifecycle.active_runtime_slot() {
      Some(slot) => slot.driver.dispatch_platform_view(id, event)
      None => ()
    }
  })
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
      request.renderer_providers(),
      options~,
      window_requests=request.window_requests(),
    )
  })
}

///|
pub fn WebAppOptions::new(
  scene_resolver? : @runtime.WindowSceneResolver = @runtime.WindowSceneResolver::unavailable(),
  event_sources? : @runtime.HostPlatformEventSources? = None,
  route_source? : @services.RouteSource? = None,
  platform_view_plugins? : Array[@host.PlatformViewPlugin] = [],
) -> WebAppOptions {
  { scene_resolver, event_sources, route_source, platform_view_plugins }
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
      let window_id = self.lifecycle
        .window_registry()
        .open(title=self.title, metrics~, primary=true)
      ignore(
        self.lifecycle.bind_platform_window(platform_id=window.id(), window_id~),
      )
      self.lifecycle.register_primary_runtime_slot(window_id, self.driver)
      self.driver.set_redraw_scheduler(() => {
        @window_host.request_redraw_window_if_needed(
          self.lifecycle,
          self.images,
          window_id,
        )
      })
      match
        resolve_web_renderer(
          self.renderer_providers,
          window_web_default_canvas_id(window.id().into_raw()),
          metrics,
        ) {
        None => {
          window.drop()
          event_loop.exit()
        }
        Some(resolution) => {
          let renderer = resolution
          self.driver.set_text_system(renderer.text_system())
          match self.lifecycle.runtime_slot_lookup(window_id) {
            Some(slot) =>
              ignore(slot.driver.dispatch(@host.Event::Resized(metrics)))
            None => ()
          }
          ignore(
            @window_host.attach_window_surface(
              self.lifecycle,
              self.frames,
              self.images,
              window_id,
              renderer,
              self.web_surface_actions(window, renderer),
            ),
          )
          ignore(self.platform_slots.insert({ host_id: window_id, window }))
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
fn WebApp::redraw_window(self : WebApp, window_id : @host.WindowId) -> Unit {
  ignore(
    @window_host.run_window_redraw(
      self.lifecycle,
      self.frames,
      self.images,
      self.input,
      window_id,
      render=(renderer, _runtime_slot, submission) => {
        @runtime.sync_platform_view_plugins(
          self.platform_view_plugins,
          window_id.value.to_uint64(),
          submission.frame(),
        )
        renderer.render_frame(submission)
      },
    ),
  )
}

///|
fn WebApp::drain_async_host_services(self : WebApp) -> Unit {
  for request in drain_web_async_host_service_requests(self.async_services) {
    dispatch_web_async_host_service_request(request)
  }
  for completion in self.async_services.drain_completed() {
    match self.lifecycle.active_runtime_slot() {
      Some(slot) =>
        ignore(
          slot.driver.dispatch_service_completion(
            completion,
            self.services.bridge(),
          ),
        )
      None => ()
    }
  }
}

///|
fn runtime_slot_needs_redraw(
  slot : @window_lifecycle.WindowRuntimeSlot,
) -> Bool {
  let result = slot.driver.event_result()
  result.needs_redraw || result.redraw_requested
}

///|
fn WebApp::redraw_dirty_windows(self : WebApp) -> Unit {
  for slot in self.lifecycle.runtime_slots().open_slots() {
    if runtime_slot_needs_redraw(slot) {
      self.redraw_window(slot.id)
    }
  }
}

///|
fn WebApp::current_scale_factor(
  self : WebApp,
  window_id : @host.WindowId,
) -> Double {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.scale_factor()
    None => 1.0
  }
}

///|
fn WebApp::resize_renderer(
  self : WebApp,
  window_id : @host.WindowId,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  match self.frames.renderer(window_id) {
    Some(renderer) =>
      renderer.resize(
        @core.SurfaceMetrics::new(
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
      renderer.resize(@window_host.to_render_metrics(metrics))
      metrics
    },
    sync_observed_resize=fn(metrics) {
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
    native_view_handle=fn() { None },
    dispose_platform_views=fn() {
      for plugin in _self.platform_view_plugins {
        (plugin.dispose_platform_views)(window.id().into_raw().to_uint64())
      }
      unregister_web_semantics_runtime(window.id().into_raw())
    },
  )
}

///|
fn resolve_web_renderer(
  providers : Array[@render.RendererProvider],
  surface_id : String,
  metrics : @core.SurfaceMetrics,
) -> @render.RendererSession? {
  let renderer_metrics = @core.SurfaceMetrics::new(
    logical_size=metrics.logical_size,
    physical_size=metrics.physical_size,
    scale_factor=metrics.scale_factor,
  )
  let surface = @render.HostSurface::new(surface_id~, metrics=renderer_metrics)
  @render_common.resolve_renderer(providers, surface)
}

///|
fn WebApp::dispose_window(self : WebApp, window_id : @host.WindowId) -> Unit {
  @window_host.dispose_window(
    self.lifecycle,
    self.frames,
    self.images,
    self.services,
    window_id,
  )
  ignore(self.platform_slots.remove_host(window_id))
  if self.lifecycle.runtime_slots_empty() {
    set_web_async_host_service_queue(None)
  }
}

///|
fn WebApp::sync_text_input_session(self : WebApp) -> Unit {
  @window_host.sync_text_input_session(self.lifecycle, self.input)
}

///|
fn surface_metrics_from_physical(
  size : @dpi.PhysicalSize,
  scale_factor : Double,
) -> @core.SurfaceMetrics {
  @window_input.surface_metrics_from_physical(size, scale_factor~)
}
