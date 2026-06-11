pub fn run_app_with_renderer_provider(
  title : String,
  runtime : @core.AppRuntime,
  provider~ : LinuxRendererProvider,
  options? : LinuxHostAppOptions = LinuxHostAppOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  let event_loop = @window_linux.EventLoop::new()
  let services = linux_service_bridge(
    system_theme=linux_color_scheme_from_theme(event_loop.system_theme()),
  )
  runtime.set_environment(
    services.environment_with_system_theme(runtime.environment()),
  )
  let app = LinuxApp::{
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
    platform_slots: LinuxWindowPlatformSlots::new(),
    image_repaint_tracker: @host.HostImageResourceRepaintTracker::new(),
    event_sources: options.event_sources,
    web_view_commands: options.web_view_commands,
    web_view_events: options.web_view_events,
    last_pointer: @core.Point::new(x=0.0, y=0.0),
    modifiers: @core.KeyModifiers::none(),
    exit_after_first_present: options.exit_after_first_present,
  }
  app.driver.set_redraw_scheduler(() => app.request_redraw())
  install_linux_webview_event_dispatcher((native_surface, id, event) => {
    app.dispatch_web_view_event(native_surface, id, event)
  })
  event_loop.run_app(app)
}

///|
fn linux_color_scheme_from_theme(
  theme : @window_core.Theme?,
) -> @core.ColorScheme {
  match theme {
    Some(@window_core.Theme::Dark) => @core.ColorScheme::Dark
    _ => @core.ColorScheme::Light
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
pub fn linux_adjust_host_event_for_client_decorations(
  event : @host.HostEvent,
  decorations : LinuxClientDecorationState,
) -> @host.HostEvent? {
  if !decorations.active {
    Some(event)
  } else {
    match event {
      @host.HostEvent::Pointer(pointer) => {
        let y = pointer.position.y - decorations.titlebar_height
        if y < 0.0 {
          None
        } else {
          Some(
            @host.HostEvent::Pointer(
              @core.PointerEvent::new(
                position=@core.Point::new(x=pointer.position.x, y~),
                phase=pointer.phase,
                button=pointer.button,
                wheel_delta=pointer.wheel_delta,
                time_ms=pointer.time_ms,
              ),
            ),
          )
        }
      }
      @host.HostEvent::Scroll(scroll) => {
        let y = scroll.position.y - decorations.titlebar_height
        if y < 0.0 {
          None
        } else {
          Some(
            @host.HostEvent::Scroll(
              @host.HostScrollEvent::new(
                position=@core.Point::new(x=scroll.position.x, y~),
                delta=scroll.delta,
                phase=scroll.phase,
              ),
            ),
          )
        }
      }
      @host.HostEvent::DragDrop(drop) =>
        match drop.position {
          Some(position) => {
            let y = position.y - decorations.titlebar_height
            let paths = drop.paths.copy()
            if y < 0.0 {
              None
            } else {
              Some(
                @host.HostEvent::DragDrop(
                  @core.DragDropEvent::new(
                    phase=drop.phase,
                    paths~,
                    position=Some(@core.Point::new(x=position.x, y~)),
                  ),
                ),
              )
            }
          }
          None => Some(event)
        }
      @host.HostEvent::Resized(metrics) =>
        Some(@host.HostEvent::Resized(metrics))
      _ => Some(event)
    }
  }
}

///|
