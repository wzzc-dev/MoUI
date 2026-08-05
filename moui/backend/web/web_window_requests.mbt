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
  request : @host.WindowRequest,
) -> @host.WindowRequestResult {
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
  request : @host.WindowOpenRequest,
) -> @host.WindowRequestResult {
  match self.coordinator.open_resolution(request) {
    @runtime.WindowOpenResolution::OpenRejected(message) =>
      @host.WindowRequestResult::WindowRejected(message)
    @runtime.WindowOpenResolution::OpenResolved(resolved) =>
      self.create_resolved_window(event_loop, resolved)
  }
}

///|
fn WebApp::create_resolved_window(
  self : WebApp,
  event_loop : @window_web.ActiveEventLoop,
  resolved : @runtime.WindowResolvedOpen,
) -> @host.WindowRequestResult {
  let attributes = @window_core.WindowAttributes::default()
    .with_title(resolved.record.title)
    .with_surface_size(
      @window_host.host_metrics_to_dpi_size(resolved.record.metrics),
    )
  let window : @window_web.Window? = Some(
    event_loop.try_create_window(attributes),
  ) catch {
    _ => None
  }
  match window {
    Some(window) => self.attach_resolved_window(window, resolved)
    None => {
      self.coordinator.rollback_window_record(resolved.id)
      @host.WindowRequestResult::WindowRejected("failed to create Web window")
    }
  }
}

///|
fn WebApp::attach_resolved_window(
  self : WebApp,
  window : @window_web.Window,
  resolved : @runtime.WindowResolvedOpen,
) -> @host.WindowRequestResult {
  let metrics = surface_metrics_from_physical(
    window.surface_size(),
    window.scale_factor(),
  )
  match
    resolve_web_renderer(
      self.renderer_factories,
      window_web_default_canvas_id(window.id().into_raw()),
      metrics,
    ) {
    None => {
      window.drop()
      self.coordinator.rollback_window_record(resolved.id)
      @host.WindowRequestResult::WindowRejected("failed to create Web renderer")
    }
    Some(resolution) => {
      let renderer = resolution.renderer()
      ignore(self.coordinator.window_registry().resize(resolved.id, metrics))
      self.coordinator.sync_runtime_slots()
      let record = match
        self.coordinator.window_registry().lookup(resolved.id) {
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
      ignore(driver.dispatch(@host.Event::Resized(metrics)))
      ignore(
        self.coordinator.register_runtime_slot(
          @window_host.WindowRuntimeSlot::from_driver(record~, driver~),
        ),
      )
      ignore(
        self.coordinator.bind_platform_window(
          platform_id=window.id(),
          window_id=resolved.id,
        ),
      )
      ignore(
        self.coordinator.attach_surface(
          resolved.id,
          renderer,
          self.web_surface_actions(window, renderer),
          image_loader=resolution.image_loader(),
        ),
      )
      ignore(
        self.platform_slots.insert({ host_id: resolved.id, window, renderer }),
      )
      register_web_semantics_runtime(
        window.id().into_raw(),
        window_web_default_canvas_id(window.id().into_raw()),
        resolved.instance.runtime,
      )
      self.coordinator.request_platform_redraw(resolved.id)
      @host.WindowRequestResult::WindowOpened(resolved.id)
    }
  }
}
