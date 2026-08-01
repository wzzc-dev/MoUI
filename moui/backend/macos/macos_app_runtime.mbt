///|
let macos_first_present_pump_limit = 16

///|
pub fn run_app_with_renderer_provider(
  title : String,
  runtime : @runtime.AppRuntime,
  provider~ : MacosRendererProvider,
  options? : MacosHostAppOptions = MacosHostAppOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  let (event_loop, app) = create_macos_app(
    title,
    runtime,
    provider~,
    options~,
    smoke_options=MacosHostSmokeOptions::new(),
    window_requests~,
  )
  event_loop.run_app(app)
}

///|
pub fn run_app_with_renderer_provider_smoke(
  title : String,
  runtime : @runtime.AppRuntime,
  provider~ : MacosRendererProvider,
  options? : MacosHostAppOptions = MacosHostAppOptions::new(),
  smoke_options? : MacosHostSmokeOptions = MacosHostSmokeOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  let (event_loop, app) = create_macos_app(
    title,
    runtime,
    provider~,
    options~,
    smoke_options~,
    window_requests~,
  )
  if smoke_options.first_frame_smoke_auto_exit {
    run_app_until_first_present(event_loop, app)
  } else {
    // Performance smoke uses the normal event loop so platform VSync / redraw
    // pacing can produce a continuous present stream. Completion still exits
    // from finish_presented_window once duration + samples are met.
    event_loop.run_app(app)
  }
}

///|
pub async fn run_app_with_renderer_provider_async_pump(
  title : String,
  runtime : @runtime.AppRuntime,
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
    smoke_options=MacosHostSmokeOptions::new(),
    window_requests~,
  )
  while !event_loop.exiting() {
    match event_loop.pump_app_events(Some(0), app) {
      @window_core.PumpStatus::Exit(_) => return ()
      @window_core.PumpStatus::Continue => ()
    }
    @async.sleep(frame_interval_ms)
  }
}

///|
fn create_macos_app(
  title : String,
  runtime : @runtime.AppRuntime,
  provider~ : MacosRendererProvider,
  options~ : MacosHostAppOptions,
  smoke_options~ : MacosHostSmokeOptions,
  window_requests~ : @host.HostWindowRequestQueue,
) -> (@window_macos.EventLoop, MacosNativeHostBackend) {
  let event_loop = @window_macos.EventLoop::EventLoop()
  let services = macos_service_bridge()
  runtime.set_environment(
    services.environment_with_system_theme(runtime.environment()),
  )
  let app = MacosNativeHostBackend::{
    title,
    runtime,
    driver: @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => ()),
    coordinator: @runtime.WindowHostCoordinator::new(
      window_requests~,
      scene_resolver=options.scene_resolver,
      services~,
      event_sources=options.event_sources,
      image_loader=provider.image_loader,
    ),
    renderer_provider: provider,
    services,
    platform_slots: @platform_bridge.WindowSlotMap::new(),
    platform_view_plugins: options.platform_view_plugins,
    transparent_titlebar: options.transparent_titlebar,
    platform_attributes: options.platform_attributes,
    on_ready: options.on_ready,
    min_window_size: options.min_window_size,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
    first_frame_smoke_auto_exit: smoke_options.first_frame_smoke_auto_exit,
    native_ime_runtime_smoke: smoke_options.native_ime_runtime_smoke,
    native_ime_runtime_smoke_done: false,
    native_ime_runtime_smoke_phase: 0,
    native_ime_runtime_smoke_wait_redraws: 0,
    native_ime_runtime_smoke_before_commit_text: "",
    performance_smoke_duration_ms: smoke_options.performance_smoke_duration_ms,
    performance_smoke_warm_up_presents: smoke_options.performance_smoke_warm_up_presents,
    performance_smoke_refresh_hz: smoke_options.performance_smoke_refresh_hz,
    performance_smoke_active: smoke_options.performance_enabled() &&
    !smoke_options.first_frame_smoke_auto_exit,
    performance_smoke_presented: 0,
    performance_smoke_started_ms: 0.0,
    performance_smoke_measure_started_ms: 0.0,
    performance_smoke_last_present_ms: 0.0,
    performance_smoke_last_checkpoint_ms: 0.0,
    performance_smoke_intervals_ms: [],
    promotion_lifecycle_enabled: smoke_options.promotion_lifecycle_enabled &&
    smoke_options.performance_enabled() &&
    !smoke_options.first_frame_smoke_auto_exit,
    promotion_surface_cycles_target: smoke_options.promotion_surface_cycles,
    promotion_fg_bg_cycles_target: smoke_options.promotion_fg_bg_cycles,
    promotion_context_loss_target: smoke_options.promotion_context_loss_count,
    promotion_phase: 0,
    promotion_surface_cycles_done: 0,
    promotion_fg_bg_cycles_done: 0,
    promotion_context_loss_done: 0,
    promotion_context_loss_injected: 0,
    promotion_wait_presents: 0,
    promotion_mailbox_ok: false,
    promotion_readback_eliminated: false,
    promotion_runtime_preserved: true,
    promotion_automatic_fallback: false,
    promotion_recovered_within_vsyncs: 0,
    promotion_recovery_count_before: 0,
    promotion_fallback_count: 0,
  }
  app.driver.set_redraw_scheduler(() => app.request_redraw())
  @runtime.install_platform_view_plugins(
    options.platform_view_plugins,
    (window_ptr, id, event) => {
      app.dispatch_platform_view_event_from_plugin(window_ptr, id, event)
    },
  )
  (event_loop, app)
}

///|
fn run_app_until_first_present(
  event_loop : @window_macos.EventLoop,
  app : MacosNativeHostBackend,
) -> Unit {
  let mut remaining = macos_first_present_pump_limit
  while remaining > 0 && !event_loop.exiting() {
    match event_loop.pump_app_events(Some(1), app) {
      @window_core.PumpStatus::Exit(_) => return ()
      @window_core.PumpStatus::Continue => ()
    }
    remaining = remaining - 1
  }
  if app.first_frame_smoke_auto_exit {
    println(
      "macOS renderer first-frame smoke did not present before pump limit",
    )
    event_loop.exit()
  }
}
