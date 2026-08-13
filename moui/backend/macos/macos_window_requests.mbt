///|
fn MacosNativeHostBackend::dispatch_window_event(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  match event {
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      self.modifiers = @window_input.modifiers_to_core(modifiers)
    _ => ()
  }
  match
    @window_input.window_event_to_host_with_modifiers(
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
  window_id : @host.WindowId,
  host_event : @host.Event,
) -> Unit {
  @window_host.dispatch_host_event(
    self.lifecycle,
    self.input,
    self.services,
    window_id,
    host_event,
    adjust=event => Some(event),
  )
}

///|
fn MacosNativeHostBackend::drain_window_requests(
  self : MacosNativeHostBackend,
  event_loop : @window_macos.ActiveEventLoop,
) -> Unit {
  self.lifecycle.drain_window_requests(request => {
    self.apply_window_request(event_loop, request)
  })
}

///|
fn MacosNativeHostBackend::apply_window_request(
  self : MacosNativeHostBackend,
  event_loop : @window_macos.ActiveEventLoop,
  request : @host.WindowRequest,
) -> @host.WindowRequestResult {
  @window_host.apply_window_request(
    self.lifecycle,
    self.input,
    self.services,
    request,
    open_window=open_request => self.open_window(event_loop, open_request),
    dispose_window=id => self.dispose_window(id),
    exit=() => event_loop.exit(),
  )
}

///|
fn MacosNativeHostBackend::open_window(
  self : MacosNativeHostBackend,
  event_loop : @window_macos.ActiveEventLoop,
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
fn MacosNativeHostBackend::create_resolved_window(
  self : MacosNativeHostBackend,
  event_loop : @window_macos.ActiveEventLoop,
  resolved : @runtime.WindowResolvedOpen,
) -> @host.WindowRequestResult {
  let platform = @window_core.PlatformWindowAttributes::default()
    .with_fullsize_content_view(true)
    .with_titlebar_transparent(true)
    .with_movable_by_window_background(true)
  let attributes = @window_core.WindowAttributes::default()
    .with_title(resolved.record.title)
    .with_surface_size(
      @window_input.core_size_to_window_surface_size(
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
      self.lifecycle.rollback_window_record(resolved.id)
      @host.WindowRequestResult::WindowRejected("failed to create macOS window")
    }
  }
}

///|
fn MacosNativeHostBackend::attach_resolved_window(
  self : MacosNativeHostBackend,
  window : @window_macos.Window,
  resolved : @runtime.WindowResolvedOpen,
) -> @host.WindowRequestResult {
  let metrics = @window_input.surface_metrics_from_physical(
    window.surface_size(),
    scale_factor=window.scale_factor(),
  )
  match (self.surface_binding.create_renderer)(window, metrics) {
    Some(resolution) => {
      let renderer = resolution
      ignore(self.lifecycle.window_registry().resize(resolved.id, metrics))
      ignore(
        self.lifecycle
        .runtime_slots()
        .sync_open_from_registry(self.lifecycle.window_registry()),
      )
      let record = match self.lifecycle.window_registry().lookup(resolved.id) {
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
        macos_environment_with_accessibility_settings(
          self.services
          .bridge()
          .environment_with_system_theme(driver.environment()),
        ),
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
        self.platform_slots.insert(
          @window_lifecycle.WindowSlot::new(
            host_id=resolved.id,
            window~,
            extra=(),
          ),
        ),
      )
      ignore(
        @window_host.attach_window_surface(
          self.lifecycle,
          self.frames,
          self.images,
          resolved.id,
          renderer,
          self.macos_surface_actions(window, renderer),
        ),
      )
      self.sync_accessibility_window(resolved.id)
      self.request_platform_redraw(resolved.id)
      @host.WindowRequestResult::WindowOpened(resolved.id)
    }
    None => {
      window.drop()
      self.lifecycle.rollback_window_record(resolved.id)
      @host.WindowRequestResult::WindowRejected(
        "failed to create macOS renderer",
      )
    }
  }
}

///|
fn MacosNativeHostBackend::register_primary_runtime_slot(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  self.lifecycle.register_primary_runtime_slot(window_id, self.driver)
}

///|
fn MacosNativeHostBackend::current_scale_factor(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
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
  @window_host.request_redraw(self.lifecycle, self.images)
}

///|
fn MacosNativeHostBackend::request_redraw_window_if_needed(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  @window_host.request_redraw_window_if_needed(
    self.lifecycle,
    self.images,
    window_id,
  )
}

///|
fn MacosNativeHostBackend::request_platform_redraw(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  @window_host.request_platform_redraw(self.lifecycle, window_id)
}

///|
fn MacosNativeHostBackend::dispose_window(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  self.dispose_accessibility_window(window_id)
  @window_host.dispose_window(
    self.lifecycle,
    self.frames,
    self.images,
    self.services,
    window_id,
  )
  ignore(self.platform_slots.remove_host(window_id))
}

///|
fn MacosNativeHostBackend::rollback_window_record(
  self : MacosNativeHostBackend,
  window_id : @host.WindowId,
) -> Unit {
  self.lifecycle.rollback_window_record(window_id)
}

///|
fn MacosNativeHostBackend::sync_text_input_session(
  self : MacosNativeHostBackend,
) -> Unit {
  @window_host.sync_text_input_session(self.lifecycle, self.input)
}

///|
fn MacosNativeHostBackend::macos_surface_actions(
  self : MacosNativeHostBackend,
  window : @window_macos.Window,
  renderer : @render.RendererSession,
) -> @window_lifecycle.WindowSurfaceActions {
  @window_lifecycle.WindowSurfaceActions::new(
    focus=fn() { window.focus_window() },
    request_resize=fn(metrics) {
      ignore(
        window.request_surface_size(
          @window_input.core_size_to_window_surface_size(metrics.logical_size),
        ),
      )
      (self.surface_binding.sync_surface)(window, metrics)
      renderer.resize(@window_host.to_render_metrics(metrics))
      metrics
    },
    sync_observed_resize=fn(metrics) {
      (self.surface_binding.sync_surface)(window, metrics)
      renderer.resize(@window_host.to_render_metrics(metrics))
      metrics
    },
    set_minimized=fn(minimized) { window.set_minimized(minimized) },
    set_visible=fn(visible) { window.set_visible(visible) },
    request_redraw=fn() { window.request_redraw() },
    request_ime_update=fn(action) {
      match action {
        @window_input.TextInputSessionAction::EnableIme(request)
        | @window_input.TextInputSessionAction::UpdateIme(request)
        | @window_input.TextInputSessionAction::DisableIme(request) =>
          window.request_ime_update(request) catch {
            _ => ()
          }
        @window_input.TextInputSessionAction::NoImeChange => ()
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
