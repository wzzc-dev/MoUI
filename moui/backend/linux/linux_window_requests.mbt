///|
fn LinuxNativeHostBackend::dispatch_window_event(
  self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  match event {
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      self.modifiers = @window_host.modifiers_to_core(modifiers)
    _ => ()
  }
  match
    @window_host.window_event_to_host_with_modifiers(
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
fn LinuxNativeHostBackend::dispatch_host_event(
  self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
  host_event : @host.Event,
) -> Unit {
  let decorations = match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.extra
    None => LinuxClientDecorationState::new(active=false)
  }
  self.coordinator.dispatch_host_event(window_id, host_event, adjust=event => {
    linux_adjust_host_event_for_client_decorations(event, decorations)
  })
}

///|
fn LinuxNativeHostBackend::drain_window_requests(
  self : LinuxNativeHostBackend,
  event_loop : @window_linux.ActiveEventLoop,
) -> Unit {
  self.coordinator.drain_window_requests(request => {
    self.apply_window_request(event_loop, request)
  })
}

///|
fn LinuxNativeHostBackend::apply_window_request(
  self : LinuxNativeHostBackend,
  event_loop : @window_linux.ActiveEventLoop,
  request : @host.WindowRequest,
) -> @host.WindowRequestResult {
  self.coordinator.apply_window_request(
    request,
    open_window=open_request => self.open_window(event_loop, open_request),
    dispose_window=id => self.dispose_window(id),
    exit=() => event_loop.exit(),
  )
}

///|
fn LinuxNativeHostBackend::open_window(
  self : LinuxNativeHostBackend,
  event_loop : @window_linux.ActiveEventLoop,
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
fn LinuxNativeHostBackend::create_resolved_window(
  self : LinuxNativeHostBackend,
  event_loop : @window_linux.ActiveEventLoop,
  resolved : @runtime.WindowResolvedOpen,
) -> @host.WindowRequestResult {
  let requested_surface_metrics = linux_surface_metrics_for_content(
    resolved.record.metrics,
    LinuxClientDecorationState::new(active=true),
  )
  let attributes = @window_core.WindowAttributes::default()
    .with_title(resolved.record.title)
    .with_surface_size(
      @window_host.host_metrics_to_dpi_size(requested_surface_metrics),
    )
  let linux_attributes = @window_linux.WindowAttributesLinux::default().with_app_id(
    "dev.wzzc.moui.showcase",
  )
  let window : @window_linux.Window? = Some(
    event_loop.try_create_window_with_linux_attributes(
      attributes, linux_attributes,
    ),
  ) catch {
    err => {
      println("error creating Linux window: \{err}")
      None
    }
  }
  match window {
    Some(window) => self.attach_resolved_window(window, resolved)
    None => {
      self.rollback_window_record(resolved.id)
      @host.WindowRequestResult::WindowRejected("failed to create Linux window")
    }
  }
}

///|
fn LinuxNativeHostBackend::attach_resolved_window(
  self : LinuxNativeHostBackend,
  window : @window_linux.Window,
  resolved : @runtime.WindowResolvedOpen,
) -> @host.WindowRequestResult {
  let initial_surface_metrics = linux_window_surface_metrics(window)
  let decorations = linux_client_decoration_state(window)
  let initial_metrics = linux_content_metrics_for_surface(
    initial_surface_metrics, decorations,
  )
  if decorations.active {
    linux_request_surface_for_content(window, initial_metrics, decorations)
  }
  let surface_metrics = linux_window_surface_metrics(window)
  let metrics = linux_content_metrics_for_surface(surface_metrics, decorations)
  match (self.surface_binding.create_renderer)(window, surface_metrics) {
    Some(resolution) => {
      let renderer = resolution.renderer()
      ignore(self.coordinator.window_registry().resize(resolved.id, metrics))
      ignore(
        self.coordinator
        .runtime_slots()
        .sync_open_from_registry(self.coordinator.window_registry()),
      )
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
        self.request_redraw_window_if_needed(resolved.id)
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
        self.platform_slots.insert(
          @window_host.WindowSlot::new(
            host_id=resolved.id,
            window~,
            extra=decorations,
          ),
        ),
      )
      ignore(
        self.coordinator.attach_surface(
          resolved.id,
          renderer,
          self.linux_surface_actions(window, renderer),
          image_loader=resolution.image_loader(),
        ),
      )
      self.bind_renderer_image_resource_changes(resolved.id)
      self.request_platform_redraw(resolved.id)
      @host.WindowRequestResult::WindowOpened(resolved.id)
    }
    None => {
      window.drop()
      self.rollback_window_record(resolved.id)
      @host.WindowRequestResult::WindowRejected(
        "failed to create Linux renderer",
      )
    }
  }
}

///|
fn LinuxNativeHostBackend::register_primary_runtime_slot(
  self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  self.coordinator.register_primary_runtime_slot(window_id, self.driver)
}

///|
fn LinuxNativeHostBackend::current_scale_factor(
  self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
) -> Double {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.scale_factor()
    None => 1.0
  }
}

///|
fn LinuxNativeHostBackend::request_redraw(
  self : LinuxNativeHostBackend,
) -> Unit {
  match self.coordinator.active_runtime_slot() {
    Some(slot) => self.request_redraw_window_if_needed(slot.id)
    None => ()
  }
}

///|
fn LinuxNativeHostBackend::request_redraw_window_if_needed(
  self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  self.coordinator.request_redraw_window_if_needed(window_id)
}

///|
fn LinuxNativeHostBackend::bind_renderer_image_resource_changes(
  self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  self.coordinator.bind_renderer_image_resource_changes(window_id)
}

///|
fn LinuxNativeHostBackend::request_platform_redraw(
  self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.request_redraw()
    None => ()
  }
}

///|
fn LinuxNativeHostBackend::dispose_window(
  self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  self.coordinator.dispose_window(window_id)
  match self.platform_slots.remove_host(window_id) {
    Some(slot) => {
      let handle = slot.window.wl_surface()
      for plugin in self.platform_view_plugins {
        (plugin.dispose_platform_views)(handle)
      }
      slot.window.drop()
    }
    None => ()
  }
}

///|
fn LinuxNativeHostBackend::rollback_window_record(
  self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  self.coordinator.rollback_window_record(window_id)
}

///|
fn LinuxNativeHostBackend::linux_surface_actions(
  self : LinuxNativeHostBackend,
  window : @window_linux.Window,
  renderer : @render.WindowRenderer,
) -> @window_host.WindowSurfaceActions {
  @window_host.WindowSurfaceActions::new(
    focus=fn() { window.focus_window() },
    request_resize=fn(metrics) {
      let decorations = linux_client_decoration_state(window)
      linux_request_surface_for_content(window, metrics, decorations)
      let surface_metrics = linux_window_surface_metrics(window)
      (self.surface_binding.sync_surface)(window, surface_metrics)
      renderer.resize(@window_host.to_render_metrics(surface_metrics))
      linux_content_metrics_for_surface(surface_metrics, decorations)
    },
    sync_observed_resize=fn(surface_metrics) {
      let decorations = linux_client_decoration_state(window)
      (self.surface_binding.sync_surface)(window, surface_metrics)
      renderer.resize(@window_host.to_render_metrics(surface_metrics))
      linux_content_metrics_for_surface(surface_metrics, decorations)
    },
    set_minimized=fn(minimized) { window.set_minimized(minimized) },
    set_visible=fn(visible) { window.set_visible(visible) },
    request_redraw=fn() { window.request_redraw() },
    request_ime_update=fn(action) {
      match action {
        @window_host.TextInputSessionAction::EnableIme(request)
        | @window_host.TextInputSessionAction::UpdateIme(request)
        | @window_host.TextInputSessionAction::DisableIme(request) =>
          window.request_ime_update(request) catch {
            _ => ()
          }
        @window_host.TextInputSessionAction::NoImeChange => ()
      }
    },
    drop=fn() { window.drop() },
    native_view_handle=fn() { Some(window.wl_surface()) },
    dispose_platform_views=fn() {
      let handle = window.wl_surface()
      for plugin in self.platform_view_plugins {
        (plugin.dispose_platform_views)(handle)
      }
    },
  )
}
