///|
/// Renderer-neutral Linux composition entry. Concrete renderer factories are
/// supplied by the application and are resolved only after a native window
/// exists and can provide its host surface kit.
pub fn entry(
  options? : LinuxHostAppOptions = LinuxHostAppOptions::new(),
  smoke_options? : LinuxHostSmokeOptions = LinuxHostSmokeOptions::new(),
) -> @runtime.PlatformEntry {
  @runtime.PlatformEntry::new(id="linux", launch=request => {
    let providers = request.renderer_providers()
    let image_source = @host_image_native.filesystem_image_source()
    let binding = LinuxSurfaceBinding::new(create_renderer=(window, metrics) => {
      let renderer_metrics = metrics
      let host_present = @render.PresentTarget::new(
        description="Linux host CPU presenter",
        present=frame => {
          window.present_rgba_pixels(
            frame.width(),
            frame.height(),
            frame.row_bytes(),
            frame.pixels(),
          ) ==
          0
        },
      )
      let native_surface = @render.NativeSurface::new(
        surface_handle=window.wl_surface(),
        display_handle=Some(window.wl_display()),
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
    launch_linux_app(
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
fn launch_linux_app(
  title : String,
  runtime : @runtime.AppRuntime,
  binding~ : LinuxSurfaceBinding,
  options~ : LinuxHostAppOptions,
  smoke_options~ : LinuxHostSmokeOptions,
  window_requests~ : @host.WindowRequests,
) -> Unit {
  let event_loop = @window_linux.EventLoop::new()
  let services = linux_service_bridge(
    system_theme=linux_color_scheme_from_theme(event_loop.system_theme()),
  )
  runtime.set_environment(
    linux_environment_with_accessibility_settings(
      services.environment_with_system_theme(runtime.environment()),
    ),
  )
  let app = LinuxNativeHostBackend::{
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
    atspi_state: LinuxAtspiHostState::new(),
    platform_slots: @window_lifecycle.WindowSlotMap::new(),
    platform_view_plugins: options.platform_view_plugins,
    transparent_titlebar: options.transparent_titlebar,
    platform_attributes: options.platform_attributes,
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
fn linux_color_scheme_from_theme(
  theme : @window_core.Theme?,
) -> @core.ColorScheme {
  match theme {
    Some(@window_core.Theme::Dark) => @core.ColorScheme::Dark
    _ => @core.ColorScheme::Light
  }
}

///|
pub fn linux_adjust_host_event_for_client_decorations(
  event : @host.Event,
  decorations : LinuxClientDecorationState,
) -> @host.Event? {
  if !decorations.active {
    Some(event)
  } else {
    match event {
      @host.Event::Pointer(pointer) => {
        let y = pointer.position.y - decorations.titlebar_height
        if y < 0.0 {
          None
        } else {
          Some(
            @host.Event::Pointer(
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
      @host.Event::Scroll(scroll) => {
        let y = scroll.position.y - decorations.titlebar_height
        if y < 0.0 {
          None
        } else {
          Some(
            @host.Event::Scroll(
              @host.HostScrollEvent::new(
                position=@core.Point::new(x=scroll.position.x, y~),
                delta=scroll.delta,
                phase=scroll.phase,
              ),
            ),
          )
        }
      }
      @host.Event::DragDrop(drop) =>
        match drop.position {
          Some(position) => {
            let y = position.y - decorations.titlebar_height
            let paths = drop.paths.copy()
            if y < 0.0 {
              None
            } else {
              Some(
                @host.Event::DragDrop(
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
      @host.Event::Resized(metrics) => Some(@host.Event::Resized(metrics))
      _ => Some(event)
    }
  }
}

///|
