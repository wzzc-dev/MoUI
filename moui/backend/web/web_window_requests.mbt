///|
fn WebApp::drain_window_requests(
  self : WebApp,
  event_loop : @window_web.ActiveEventLoop,
) -> Unit {
  self.coordinator.drain_window_requests(request => {
    self.apply_window_request(event_loop, request)
  })
}

///|
fn WebApp::apply_window_request(
  self : WebApp,
  event_loop : @window_web.ActiveEventLoop,
  request : @host.HostWindowRequest,
) -> @host.HostWindowRequestResult {
  self.coordinator.apply_window_request(
    request,
    open_window=open_request => self.open_window(event_loop, open_request),
    dispose_window=id => self.dispose_window(id),
    exit=() => {
      event_loop.exit()
      set_web_async_host_service_queue(None)
    },
  )
}

///|
fn WebApp::open_window(
  self : WebApp,
  event_loop : @window_web.ActiveEventLoop,
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
fn WebApp::create_resolved_window(
  self : WebApp,
  event_loop : @window_web.ActiveEventLoop,
  resolved : @runtime.HostWindowResolvedOpen,
) -> @host.HostWindowRequestResult {
  let attributes = @window_core.WindowAttributes::default()
    .with_title(resolved.record.title)
    .with_surface_size(@host.host_metrics_to_dpi_size(resolved.record.metrics))
  let window : @window_web.Window? = Some(
    event_loop.try_create_window(attributes),
  ) catch {
    _ => None
  }
  match window {
    Some(window) => self.attach_resolved_window(window, resolved)
    None => {
      self.coordinator.rollback_window_record(resolved.id)
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
  resolved : @runtime.HostWindowResolvedOpen,
) -> @host.HostWindowRequestResult {
  let metrics = surface_metrics_from_physical(
    window.surface_size(),
    window.scale_factor(),
  )
  try
    WebRenderer::create(
      canvas_id=window_web_default_canvas_id(window.id().into_raw()),
      metrics~,
    )
  catch {
    _ => {
      window.drop()
      self.coordinator.rollback_window_record(resolved.id)
      @host.HostWindowRequestResult::WindowRejected(
        "failed to create Web renderer",
      )
    }
  } noraise {
    renderer => {
      ignore(self.coordinator.windows.resize(resolved.id, metrics))
      self.coordinator.sync_runtime_slots()
      let record = match self.coordinator.windows.lookup(resolved.id) {
        Some(record) => record
        None => resolved.record
      }
      let driver = @runtime.HostRuntimeDriver::new(
        runtime=resolved.instance.runtime,
        schedule_redraw=() => (),
      )
      driver.set_redraw_scheduler(() => {
        self.coordinator.request_redraw_window_if_needed(resolved.id)
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
        self.coordinator.attach_surface(
          resolved.id,
          renderer.host_renderer,
          self.web_surface_actions(window, renderer),
        ),
      )
      ignore(
        self.platform_slots.insert({
          host_id: resolved.id,
          platform_id: window.id(),
          window,
          renderer,
        }),
      )
      register_web_semantics_runtime(
        window.id().into_raw(),
        window_web_default_canvas_id(window.id().into_raw()),
        resolved.instance.runtime,
      )
      self.coordinator.request_platform_redraw(resolved.id)
      @host.HostWindowRequestResult::WindowOpened(resolved.id)
    }
  }
}
