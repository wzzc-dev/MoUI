///|
pub impl @window_linux.ApplicationHandler for LinuxNativeHostBackend with fn can_create_surfaces(
  self,
  event_loop,
) {
  let base_attributes = @window_core.WindowAttributes::default()
    .with_title(self.title)
    .with_surface_size(
      @window_input.core_size_to_window_surface_size(self.runtime.size()),
    )
  let attributes = if self.transparent_titlebar {
    base_attributes.with_platform_attributes(
      self.platform_attributes.with_titlebar_transparent(true),
      // Note: Linux/Wayland titlebar transparency depends on the compositor and
      // client-side decoration support. The window package handles the mapping.
    )
  } else {
    base_attributes
  }
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
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      let initial_surface_metrics = linux_window_surface_metrics(window)
      let decorations = linux_client_decoration_state(window)
      let initial_metrics = linux_content_metrics_for_surface(
        initial_surface_metrics, decorations,
      )
      if decorations.active {
        linux_request_surface_for_content(window, initial_metrics, decorations)
      }
      let surface_metrics = linux_window_surface_metrics(window)
      let metrics = linux_content_metrics_for_surface(
        surface_metrics, decorations,
      )
      let window_id = self.lifecycle
        .window_registry()
        .open(title=self.title, metrics~, primary=true)
      ignore(
        self.lifecycle.bind_platform_window(platform_id=window.id(), window_id~),
      )
      self.register_primary_runtime_slot(window_id)
      self.driver.set_redraw_scheduler(() => {
        self.request_redraw_window_if_needed(window_id)
      })
      match (self.surface_binding.create_renderer)(window, surface_metrics) {
        Some(resolution) => {
          let renderer = resolution
          ignore(
            @window_host.attach_window_surface(
              self.lifecycle,
              self.frames,
              self.images,
              window_id,
              renderer,
              self.linux_surface_actions(window, renderer),
            ),
          )
          self.driver.set_text_system(renderer.text_system())
          ignore(self.driver.dispatch(@host.Event::Resized(metrics)))
          ignore(
            self.platform_slots.insert(
              @window_lifecycle.WindowSlot::new(
                host_id=window_id,
                window~,
                extra=decorations,
              ),
            ),
          )
          self.sync_atspi_window(window_id)
          window.request_redraw()
          self.drain_window_requests(event_loop)
        }
        None => {
          self.rollback_window_record(window_id)
          window.drop()
          event_loop.exit()
        }
      }
    }
    None => ()
  }
}

///|
pub impl @window_linux.ApplicationHandler for LinuxNativeHostBackend with fn about_to_wait(
  self,
  event_loop,
) {
  // Drain pending platform-view commands through any installed plugins.
  for slot in self.platform_slots.slots {
    let handle = slot.window.wl_surface()
    for plugin in self.platform_view_plugins {
      (plugin.drain_commands)(handle)
    }
  }
  // A plugin with a nested native event loop (e.g. WebKitGTK) may still have
  // outstanding work; keep the host spinning until the earliest reported
  // deadline instead of stalling on `Wait`.
  match
    @window_host.platform_view_plugins_next_deadline(self.platform_view_plugins) {
    Some(deadline) =>
      event_loop.set_control_flow(
        @window_core.ControlFlow::wait_until(deadline),
      )
    None => event_loop.set_control_flow(@window_core.ControlFlow::Wait)
  }
  self.drain_window_requests(event_loop)
  for slot in self.lifecycle.runtime_slots().open_slots() {
    let current = slot.driver.environment()
    let next = linux_environment_with_accessibility_settings(current)
    if next != current {
      slot.driver.set_environment(next)
    }
  }
  for slot in self.lifecycle.runtime_slots().open_slots() {
    self.sync_atspi_window(slot.id)
  }
}

///|
pub impl @window_linux.ApplicationHandler for LinuxNativeHostBackend with fn window_event(
  self,
  event_loop,
  platform_window_id,
  event,
) {
  self.drain_window_requests(event_loop)
  if event_loop.exiting() {
    return ()
  }
  let window_id = match self.lifecycle.lookup_window(platform_window_id) {
    Some(window_id) => window_id
    None => return ()
  }
  let surface_size = match self.platform_slots.lookup_host(window_id) {
    Some(slot) => Some(slot.window.surface_size())
    None => None
  }
  match
    @window_input.transform_cross_platform_event(
      event,
      scale_factor=self.current_scale_factor(window_id),
      surface_size~,
    ) {
    @window_input.TransformedWindowEvent::CloseRequested => {
      self.dispatch_host_event(window_id, @host.Event::CloseRequested)
      self.dispose_window(window_id)
      if self.lifecycle.runtime_slots_empty() {
        event_loop.exit()
      }
      return ()
    }
    @window_input.TransformedWindowEvent::DispatchHostEvent(host_event) => {
      match host_event {
        @host.Event::Resized(surface_metrics) => {
          match self.platform_slots.lookup_host(window_id) {
            Some(slot) =>
              slot.set_extra(extra=linux_client_decoration_state(slot.window))
            None => ()
          }
          ignore(
            @window_host.sync_observed_resize(
              self.lifecycle,
              self.input,
              self.services,
              window_id,
              surface_metrics,
            ),
          )
        }
        _ => self.dispatch_host_event(window_id, host_event)
      }
      return ()
    }
    @window_input.TransformedWindowEvent::WindowRedrawRequired => {
      if self.redraw_window(window_id) {
        event_loop.exit()
      }
      return ()
    }
    @window_input.TransformedWindowEvent::PlatformSpecific => ()
  }
  match event {
    @window_core.WindowEvent::PointerMoved(_, position, _, _) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_pointer_or_context_menu(window_id, event)
    }
    @window_core.WindowEvent::DragEntered(_, position)
    | @window_core.WindowEvent::DragMoved(position)
    | @window_core.WindowEvent::DragDropped(_, position) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::DragLeft(Some(position)) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::KeyboardInput(_, _, _) =>
      self.dispatch_window_event(window_id, event)
    @window_core.WindowEvent::Ime(_) =>
      self.dispatch_window_event(window_id, event)
    @window_core.WindowEvent::ModifiersChanged(_) =>
      self.dispatch_window_event(window_id, event)
    _ => self.dispatch_window_event(window_id, event)
  }
}

///|
fn LinuxNativeHostBackend::dispatch_pointer_or_context_menu(
  self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  if @window_input.window_event_is_context_menu_button(event) {
    if self.pointer_is_in_client_titlebar(window_id) {
      return ()
    }
    if @window_input.window_event_is_context_menu_trigger(event) {
      match self.lifecycle.runtime_slots().lookup(window_id) {
        Some(slot) =>
          ignore(slot.driver.show_context_menu(self.services.bridge()))
        None => ()
      }
      self.sync_text_input_session()
    }
  } else {
    self.dispatch_window_event(window_id, event)
  }
}

///|
fn LinuxNativeHostBackend::pointer_is_in_client_titlebar(
  self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
) -> Bool {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) =>
      slot.extra.active && self.last_pointer.y < slot.extra.titlebar_height
    None => false
  }
}

///|
fn LinuxNativeHostBackend::redraw_window(
  self : LinuxNativeHostBackend,
  window_id : @host.WindowId,
) -> Bool {
  match self.platform_slots.lookup_host(window_id) {
    Some(platform_slot) =>
      @window_host.run_window_redraw(
        self.lifecycle,
        self.frames,
        self.images,
        self.input,
        window_id,
        render=(renderer, runtime_slot, submission) => {
          let frame = submission.frame()
          platform_slot.window.pre_present_notify()
          let surface_metrics = linux_window_surface_metrics(
            platform_slot.window,
          )
          let commands = linux_client_decorated_commands_with_clear_color(
            frame.commands,
            title=runtime_slot.record.title,
            metrics=surface_metrics,
            decorations=platform_slot.extra,
            clear_color=frame.clear_color,
          )
          let has_platform_views = frame.platform_views.length() > 0
          if has_platform_views {
            let offset_y = platform_slot.extra.titlebar_height
            let handle = platform_slot.window.wl_surface()
            for plugin in self.platform_view_plugins {
              match plugin.setup_platform_view_draw {
                Some(setup_fn) =>
                  setup_fn(handle, frame, offset_y, draw => {
                    let sink = @core.PlatformViewPixelSink::new(draw=fn(
                      pixels,
                      width,
                      height,
                      stride,
                      x,
                      y,
                      draw_width,
                      draw_height,
                    ) {
                      renderer.draw_platform_view_pixels(
                        pixels, width, height, stride, x, y, draw_width, draw_height,
                      )
                    })
                    renderer.set_platform_view_draw_fn(
                      Some(fn() { draw(sink) }),
                    )
                  })
                None => ()
              }
            }
          }
          let result = renderer.render_frame(
            @render.RenderFrameSubmission::new(token=submission.token(), frame={
              ..frame,
              commands,
              damage: if platform_slot.extra.active {
                @core.DamageRegion::full("linux client decorations")
              } else {
                frame.damage
              },
            }),
          )
          if has_platform_views {
            renderer.set_platform_view_draw_fn(None)
          }
          @runtime.sync_platform_view_plugins(
            self.platform_view_plugins,
            platform_slot.window.wl_surface(),
            frame,
            content_offset=platform_slot.extra.titlebar_height,
          )
          result
        },
        finish_presented=runtime_slot => {
          @runtime.finish_first_frame_smoke_auto_exit(
            platform_name="Linux",
            title=runtime_slot.record.title,
            flag=self.first_frame_smoke_auto_exit,
            finish=fn() {
              self.first_frame_smoke_auto_exit = false
              self.dispose_window(window_id)
            },
          )
        },
      )
    None => false
  }
}

///|
/// Handle a decoded platform-view event received from a plugin's native event
/// dispatcher. Routes it into the runtime tree via
/// `HostRuntimeDriver::dispatch_platform_view`, bypassing `Event` entirely.
fn LinuxNativeHostBackend::dispatch_platform_view_event_from_plugin(
  self : LinuxNativeHostBackend,
  window_ptr : UInt64,
  id : String,
  event : @core.PlatformViewEvent,
) -> Unit {
  match self.platform_view_host_id(window_ptr) {
    Some(window_id) => {
      match self.lifecycle.runtime_slots().lookup(window_id) {
        Some(slot) => slot.driver.dispatch_platform_view(id, event)
        None => ()
      }
      self.sync_text_input_session()
      self.request_redraw_window_if_needed(window_id)
    }
    None => ()
  }
}

///|
/// Resolve a native `wl_surface` handle back to its `WindowId` by scanning
/// the live platform slots. Used to route native platform-view events.
fn LinuxNativeHostBackend::platform_view_host_id(
  self : LinuxNativeHostBackend,
  native_surface : UInt64,
) -> @host.WindowId? {
  for slot in self.platform_slots.slots {
    if slot.window.wl_surface() == native_surface {
      return Some(slot.host_id)
    }
  }
  None
}
