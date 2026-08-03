///|
/// Renderer-neutral Linux composition entry. Concrete renderer factories are
/// supplied by the application and are resolved only after a native window
/// exists and can provide its host surface kit.
pub fn entry(
  options? : LinuxHostAppOptions = LinuxHostAppOptions::new(),
  smoke_options? : LinuxHostSmokeOptions = LinuxHostSmokeOptions::new(),
) -> @runtime.PlatformEntry {
  @runtime.PlatformEntry::new(id="linux", launch=request => {
    let factories = request.renderer_factories()
    let image_source = @host_image_source.from_filesystem()
    let binding = LinuxSurfaceBinding::new(create_renderer=(window, metrics) => {
      let renderer_metrics = @platform_bridge.renderer_metrics_from_host(
        metrics,
      )
      let host_present = @render.HostPresentTarget::new(
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
      let gpu_surface = match
        @render.GpuHostSurfaceDescriptor::wayland_vulkan_surface(
          window.wl_display(),
          window.wl_surface(),
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
  window_requests~ : @host.HostWindowRequestQueue,
) -> Unit {
  let event_loop = @window_linux.EventLoop::new()
  let services = linux_service_bridge(
    system_theme=linux_color_scheme_from_theme(event_loop.system_theme()),
  )
  runtime.set_environment(
    services.environment_with_system_theme(runtime.environment()),
  )
  let app = LinuxNativeHostBackend::{
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
