///|
fn WebApp::drain_window_requests(
  self : WebApp,
  event_loop : @window_web.ActiveEventLoop,
) -> Unit {
  ignore(
    self.window_requests.drain_with_handler(request => {
      self.apply_window_request(event_loop, request)
    }),
  )
}

///|
fn WebApp::apply_window_request(
  self : WebApp,
  event_loop : @window_web.ActiveEventLoop,
  request : @host.HostWindowRequest,
) -> @host.HostWindowRequestResult {
  match request {
    @host.HostWindowRequest::OpenWindow(open_request) =>
      self.open_window(event_loop, open_request)
    @host.HostWindowRequest::FocusWindow(id) =>
      self.apply_platform_window_request(id, request, window => {
        window.focus_window()
      })
    @host.HostWindowRequest::CloseWindow(id) =>
      self.apply_platform_window_request(id, request, _window => {
        self.dispose_window(id)
        if self.runtime_slots.is_empty() {
          event_loop.exit()
        }
      })
    @host.HostWindowRequest::ResizeWindow(id, metrics) =>
      self.apply_platform_window_request(id, request, window => {
        ignore(window.request_surface_size(host_metrics_to_dpi_size(metrics)))
        self.resize_renderer(id, metrics)
        window.request_redraw()
      })
    @host.HostWindowRequest::MinimizeWindow(id) =>
      self.apply_platform_window_request(id, request, window => {
        window.set_minimized(true)
      })
    @host.HostWindowRequest::ShowWindow(id) =>
      self.apply_platform_window_request(id, request, window => {
        window.set_minimized(false)
        window.set_visible(true)
      })
    @host.HostWindowRequest::SetPrimaryWindow(id) =>
      self.apply_platform_window_request(id, request, _window => ())
  }
}

///|
fn WebApp::apply_platform_window_request(
  self : WebApp,
  id : @host.HostWindowId,
  request : @host.HostWindowRequest,
  apply : (@window_web.Window) -> Unit,
) -> @host.HostWindowRequestResult {
  match self.platform_slots.lookup_host(id) {
    Some(slot) => {
      let result = self.runtime_slots.apply_request(self.windows, request)
      match result {
        @host.HostWindowRequestResult::WindowRejected(_) => ()
        _ => apply(slot.window)
      }
      result
    }
    None =>
      @host.HostWindowRequestResult::WindowRejected(
        "window request has no active Web window",
      )
  }
}

///|
fn WebApp::open_window(
  self : WebApp,
  event_loop : @window_web.ActiveEventLoop,
  request : @host.HostWindowOpenRequest,
) -> @host.HostWindowRequestResult {
  match
    @runtime.resolve_open_request(self.windows, request, self.scene_resolver) {
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
    .with_surface_size(host_metrics_to_dpi_size(resolved.record.metrics))
  let window : @window_web.Window? = Some(
    event_loop.try_create_window(attributes),
  ) catch {
    _ => None
  }
  match window {
    Some(window) => self.attach_resolved_window(window, resolved)
    None => {
      self.rollback_resolved_window(resolved.id)
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
      self.rollback_resolved_window(resolved.id)
      @host.HostWindowRequestResult::WindowRejected(
        "failed to create Web renderer",
      )
    }
  } noraise {
    renderer => {
      ignore(self.windows.resize(resolved.id, metrics))
      ignore(self.runtime_slots.sync_open_from_registry(self.windows))
      let record = match self.windows.lookup(resolved.id) {
        Some(record) => record
        None => resolved.record
      }
      let driver = @runtime.HostRuntimeDriver::new(
        runtime=resolved.instance.runtime,
        schedule_redraw=() => (),
      )
      driver.set_redraw_scheduler(() => {
        self.request_redraw_window_if_needed(resolved.id)
      })
      driver.set_environment(
        self.services.environment_with_system_theme(driver.environment()),
      )
      driver.set_text_system(renderer.text_system())
      ignore(driver.dispatch(@host.HostEvent::Resized(metrics)))
      ignore(
        self.runtime_slots.insert(
          @runtime.HostWindowRuntimeSlot::from_driver(record~, driver~),
        ),
      )
      ignore(
        self.platform_windows.bind(platform_id=window.id(), host_id=resolved.id),
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
      self.request_platform_redraw(resolved.id)
      @host.HostWindowRequestResult::WindowOpened(resolved.id)
    }
  }
}

///|
fn WebApp::rollback_resolved_window(
  self : WebApp,
  id : @host.HostWindowId,
) -> Unit {
  ignore(self.windows.close(id))
  ignore(self.windows.remove_closed())
  ignore(self.runtime_slots.sync_open_from_registry(self.windows))
}
