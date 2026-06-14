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
    web_view_commands: options.web_view_commands,
    web_view_events: options.web_view_events,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
    first_frame_smoke_auto_exit: smoke_options.first_frame_smoke_auto_exit,
    native_ime_runtime_smoke: smoke_options.native_ime_runtime_smoke,
    native_ime_runtime_smoke_done: false,
    native_ime_runtime_smoke_phase: 0,
    native_ime_runtime_smoke_wait_redraws: 0,
    native_ime_runtime_smoke_before_commit_text: "",
  }
  app.driver.set_redraw_scheduler(() => app.request_redraw())
  install_macos_webview_event_dispatcher((native_view, id, event) => {
    app.dispatch_web_view_event(native_view, id, event)
  })
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
  if app.first_frame_smoke_auto_exit {
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
