///|
fn MacosNativeHostBackend::dispatch_window_event(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  match event {
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      self.modifiers = @host.modifiers_to_core(modifiers)
    _ => ()
  }
  match
    @host.window_event_to_host_with_modifiers(
      event,
      self.last_pointer,
      self.modifiers,
      scale_factor=self.current_scale_factor(window_id),
    ) {
    Some(host_event) => self.dispatch_host_event(window_id, host_event)
    None => ()
  }
}

///|
/// Dispatch a platform-neutral event that has already crossed the Platform
/// Bridge. Native keyboard decoding still enters through `dispatch_window_event`.
fn MacosNativeHostBackend::dispatch_host_event(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
  host_event : @host.HostEvent,
) -> Unit {
  self.coordinator.dispatch_host_event(window_id, host_event, adjust=event => {
    Some(event)
  })
}

///|
fn MacosNativeHostBackend::drain_window_requests(
  self : MacosNativeHostBackend,
  event_loop : @window_macos.ActiveEventLoop,
) -> Unit {
  self.coordinator.drain_window_requests(request => {
    self.apply_window_request(event_loop, request)
  })
}

///|
fn MacosNativeHostBackend::apply_window_request(
  self : MacosNativeHostBackend,
  event_loop : @window_macos.ActiveEventLoop,
  request : @host.HostWindowRequest,
) -> @host.HostWindowRequestResult {
  self.coordinator.apply_window_request(
    request,
    open_window=open_request => self.open_window(event_loop, open_request),
    exit=() => event_loop.exit(),
  )
}

///|
fn MacosNativeHostBackend::open_window(
  self : MacosNativeHostBackend,
  event_loop : @window_macos.ActiveEventLoop,
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
fn MacosNativeHostBackend::create_resolved_window(
  self : MacosNativeHostBackend,
  event_loop : @window_macos.ActiveEventLoop,
  resolved : @runtime.HostWindowResolvedOpen,
) -> @host.HostWindowRequestResult {
  let platform = @window_core.PlatformWindowAttributes::default()
    .with_fullsize_content_view(true)
    .with_titlebar_transparent(true)
    .with_movable_by_window_background(true)
  let attributes = @window_core.WindowAttributes::default()
    .with_title(resolved.record.title)
    .with_surface_size(
      @host.core_size_to_window_surface_size(
        resolved.record.metrics.logical_size,
      ),
    )
    .with_platform_attributes(platform)
  let window : @window_macos.Window? = Some(
    event_loop.try_create_window(attributes),
  ) catch {
    err => {
      println("error creating macOS window: \{err}")
      None
    }
  }
  match window {
    Some(window) => self.attach_resolved_window(window, resolved)
    None => {
      self.coordinator.rollback_window_record(resolved.id)
      @host.HostWindowRequestResult::WindowRejected(
        "failed to create macOS window",
      )
    }
  }
}

///|
fn MacosNativeHostBackend::attach_resolved_window(
  self : MacosNativeHostBackend,
  window : @window_macos.Window,
  resolved : @runtime.HostWindowResolvedOpen,
) -> @host.HostWindowRequestResult {
  let metrics = @host.surface_metrics_from_physical(
    window.surface_size(),
    scale_factor=window.scale_factor(),
  )
  match (self.surface_binding.create_renderer)(window, metrics) {
    Some(resolution) => {
      let renderer = resolution.renderer()
      ignore(self.coordinator.windows.resize(resolved.id, metrics))
      ignore(
        self.coordinator.runtime_slots.sync_open_from_registry(
          self.coordinator.windows,
        ),
      )
      let record = match self.coordinator.windows.lookup(resolved.id) {
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
        self.platform_slots.insert(
          @platform_bridge.WindowSlot::new(
            host_id=resolved.id,
            platform_id=window.id(),
            window~,
            extra=(),
          ),
        ),
      )
      ignore(
        self.coordinator.attach_surface(
          resolved.id,
          renderer,
          self.macos_surface_actions(window, renderer),
          image_loader=resolution.image_loader(),
        ),
      )
      self.bind_renderer_image_resource_changes(resolved.id)
      self.request_platform_redraw(resolved.id)
      @host.HostWindowRequestResult::WindowOpened(resolved.id)
    }
    None => {
      window.drop()
      self.coordinator.rollback_window_record(resolved.id)
      @host.HostWindowRequestResult::WindowRejected(
        "failed to create macOS renderer",
      )
    }
  }
}

///|
fn MacosNativeHostBackend::register_primary_runtime_slot(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Unit {
  self.coordinator.register_primary_runtime_slot(window_id, self.driver)
}

///|
fn MacosNativeHostBackend::current_scale_factor(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Double {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.scale_factor()
    None => 1.0
  }
}

///|
fn MacosNativeHostBackend::request_redraw(
  self : MacosNativeHostBackend,
) -> Unit {
  self.coordinator.request_redraw()
}

///|
fn MacosNativeHostBackend::request_redraw_window_if_needed(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Unit {
  self.coordinator.request_redraw_window_if_needed(window_id)
}

///|
fn MacosNativeHostBackend::bind_renderer_image_resource_changes(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Unit {
  self.coordinator.bind_renderer_image_resource_changes(window_id)
}

///|
fn MacosNativeHostBackend::request_platform_redraw(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Unit {
  self.coordinator.request_platform_redraw(window_id)
}

///|
fn MacosNativeHostBackend::dispose_window(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Unit {
  self.coordinator.dispose_window(window_id)
  ignore(self.platform_slots.remove_host(window_id))
}

///|
fn MacosNativeHostBackend::rollback_window_record(
  self : MacosNativeHostBackend,
  window_id : @host.HostWindowId,
) -> Unit {
  self.coordinator.rollback_window_record(window_id)
}

///|
fn MacosNativeHostBackend::macos_surface_actions(
  self : MacosNativeHostBackend,
  window : @window_macos.Window,
  renderer : @render.HostWindowRenderer,
) -> @runtime.WindowSurfaceActions {
  @runtime.WindowSurfaceActions::new(
    focus=fn() { window.focus_window() },
    request_surface_size=fn(metrics) {
      ignore(
        window.request_surface_size(
          @host.core_size_to_window_surface_size(metrics.logical_size),
        ),
      )
    },
    sync_surface=fn(metrics) {
      (self.surface_binding.sync_surface)(window, metrics)
    },
    renderer_resize=fn(metrics) { renderer.resize(metrics) },
    set_minimized=fn(minimized) { window.set_minimized(minimized) },
    set_visible=fn(visible) { window.set_visible(visible) },
    request_redraw=fn() { window.request_redraw() },
    request_ime_update=fn(action) {
      match action {
        @host.TextInputSessionAction::EnableIme(request)
        | @host.TextInputSessionAction::UpdateIme(request)
        | @host.TextInputSessionAction::DisableIme(request) =>
          window.request_ime_update(request) catch {
            _ => ()
          }
        @host.TextInputSessionAction::NoImeChange => ()
      }
    },
    drop=fn() { window.drop() },
    native_view_handle=fn() { macos_native_view_handle(window) },
    dispose_platform_views=fn() {
      match macos_native_view_handle(window) {
        Some(handle) =>
          for plugin in self.platform_view_plugins {
            (plugin.dispose_platform_views)(handle)
          }
        None => ()
      }
    },
  )
}
