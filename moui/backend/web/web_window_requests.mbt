///|
fn WebApp::drain_window_requests(
  self : WebApp,
  event_loop : @window_web.ActiveEventLoop,
) -> Unit {
  self.lifecycle.drain_window_requests(request => {
    self.apply_window_request(event_loop, request)
  })
}

///|
fn WebApp::apply_window_request(
  self : WebApp,
  event_loop : @window_web.ActiveEventLoop,
  request : @host.WindowRequest,
) -> @host.WindowRequestResult {
  @window_host.apply_window_request(
    self.lifecycle,
    self.input,
    self.services,
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
  match self.lifecycle.open_resolution(request) {
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
      @window_input.host_metrics_to_dpi_size(resolved.record.metrics),
    )
  let window : @window_web.Window? = Some(
    event_loop.try_create_window(attributes),
  ) catch {
    _ => None
  }
  match window {
    Some(window) => self.attach_resolved_window(window, resolved)
    None => {
      self.lifecycle.rollback_window_record(resolved.id)
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
      self.renderer_providers,
      window_web_default_canvas_id(window.id().into_raw()),
      metrics,
    ) {
    None => {
      window.drop()
      self.lifecycle.rollback_window_record(resolved.id)
      @host.WindowRequestResult::WindowRejected("failed to create Web renderer")
    }
    Some(resolution) => {
      let renderer = resolution
      ignore(self.lifecycle.window_registry().resize(resolved.id, metrics))
      self.lifecycle.sync_runtime_slots()
      let record = match self.lifecycle.window_registry().lookup(resolved.id) {
        Some(record) => record
        None => resolved.record
      }
      let driver = @runtime.HostRuntimeDriver::new(
        runtime=resolved.instance.runtime,
        schedule_redraw=() => (),
      )
      driver.set_redraw_scheduler(() => {
        @window_host.request_redraw_window_if_needed(
          self.lifecycle,
          self.images,
          resolved.id,
        )
      })
      driver.set_environment(
        self.services
        .bridge()
        .environment_with_system_theme(driver.environment()),
      )
      driver.set_text_system(renderer.text_system())
      ignore(driver.dispatch(@host.Event::Resized(metrics)))
      ignore(
        self.lifecycle.register_runtime_slot(
          @window_lifecycle.WindowRuntimeSlot::from_driver(record~, driver~),
        ),
      )
      ignore(
        self.lifecycle.bind_platform_window(
          platform_id=window.id(),
          window_id=resolved.id,
        ),
      )
      ignore(
        @window_host.attach_window_surface(
          self.lifecycle,
          self.frames,
          self.images,
          resolved.id,
          renderer,
          self.web_surface_actions(window, renderer),
        ),
      )
      ignore(self.platform_slots.insert({ host_id: resolved.id, window }))
      register_web_semantics_runtime(
        window.id().into_raw(),
        window_web_default_canvas_id(window.id().into_raw()),
        driver,
      )
      @window_host.request_platform_redraw(self.lifecycle, resolved.id)
      @host.WindowRequestResult::WindowOpened(resolved.id)
    }
  }
}
