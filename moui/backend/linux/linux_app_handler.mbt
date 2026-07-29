///|
fn LinuxWindowPlatformSlots::new() -> LinuxWindowPlatformSlots {
  { slots: [] }
}

///|
fn LinuxWindowPlatformSlots::insert(
  self : LinuxWindowPlatformSlots,
  slot : LinuxWindowPlatformSlot,
) -> Bool {
  match
    (self.lookup_host(slot.host_id), self.lookup_platform(slot.platform_id)) {
    (None, None) => {
      self.slots.push(slot)
      true
    }
    _ => false
  }
}

///|
fn LinuxWindowPlatformSlots::lookup_host(
  self : LinuxWindowPlatformSlots,
  host_id : @host.HostWindowId,
) -> LinuxWindowPlatformSlot? {
  for slot in self.slots {
    if slot.host_id == host_id {
      return Some(slot)
    }
  }
  None
}

///|
fn LinuxWindowPlatformSlots::lookup_platform(
  self : LinuxWindowPlatformSlots,
  platform_id : @window_core.WindowId,
) -> LinuxWindowPlatformSlot? {
  for slot in self.slots {
    if slot.platform_id == platform_id {
      return Some(slot)
    }
  }
  None
}

///|
fn LinuxWindowPlatformSlots::remove_host(
  self : LinuxWindowPlatformSlots,
  host_id : @host.HostWindowId,
) -> LinuxWindowPlatformSlot? {
  let mut removed = None
  let kept = []
  for slot in self.slots {
    if slot.host_id == host_id {
      removed = Some(slot)
    } else {
      kept.push(slot)
    }
  }
  self.slots = kept
  removed
}

///|
pub impl @window_linux.ApplicationHandler for LinuxApp with fn can_create_surfaces(
  self,
  event_loop,
) {
  let base_attributes = @window_core.WindowAttributes::default()
    .with_title(self.title)
    .with_surface_size(runtime_size_to_window_surface_size(self.runtime.size()))
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
      let window_id = self.windows.open(
        title=self.title,
        metrics~,
        primary=true,
      )
      ignore(
        self.platform_windows.bind(platform_id=window.id(), host_id=window_id),
      )
      self.register_primary_runtime_slot(window_id)
      self.driver.set_redraw_scheduler(() => {
        self.request_redraw_window_if_needed(window_id)
      })
      match (self.renderer_provider.create_renderer)(window, surface_metrics) {
        Some(renderer) => {
          self.bind_renderer_image_resource_changes(window_id, renderer)
          self.driver.set_text_system(renderer.text_system())
          ignore(self.driver.dispatch(@host.HostEvent::Resized(metrics)))
          ignore(
            self.platform_slots.insert({
              host_id: window_id,
              platform_id: window.id(),
              window,
              renderer,
              decorations,
              frame_pending: false,
            }),
          )
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
pub impl @window_linux.ApplicationHandler for LinuxApp with fn about_to_wait(
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
  match @host.platform_view_plugins_next_deadline(self.platform_view_plugins) {
    Some(deadline) =>
      event_loop.set_control_flow(
        @window_core.ControlFlow::wait_until(deadline),
      )
    None => event_loop.set_control_flow(@window_core.ControlFlow::Wait)
  }
  self.drain_window_requests(event_loop)
}

///|
pub impl @window_linux.ApplicationHandler for LinuxApp with fn window_event(
  self,
  event_loop,
  platform_window_id,
  event,
) {
  self.drain_window_requests(event_loop)
  if event_loop.exiting() {
    return ()
  }
  let window_id = match self.platform_windows.lookup_host(platform_window_id) {
    Some(window_id) => window_id
    None => return ()
  }
  match event {
    @window_core.WindowEvent::CloseRequested => {
      self.dispatch_window_event(window_id, event)
      self.dispose_window(window_id)
      if self.runtime_slots.is_empty() {
        event_loop.exit()
      }
    }
    @window_core.WindowEvent::SurfaceResized(_) => {
      let mut dispatched = false
      match self.platform_slots.lookup_host(window_id) {
        Some(slot) => {
          slot.decorations = linux_client_decoration_state(slot.window)
          let surface_metrics = linux_window_surface_metrics(slot.window)
          let metrics = linux_content_metrics_for_surface(
            surface_metrics,
            slot.decorations,
          )
          ignore(self.windows.resize(window_id, metrics))
          self.sync_runtime_slot(window_id)
          (self.renderer_provider.sync_surface)(slot.window, surface_metrics)
          slot.renderer.resize(to_render_metrics(surface_metrics))
          slot.window.request_redraw()
          self.dispatch_host_event(window_id, @host.HostEvent::Resized(metrics))
          dispatched = true
        }
        None => ()
      }
      if !dispatched {
        self.dispatch_window_event(window_id, event)
      }
    }
    @window_core.WindowEvent::ScaleFactorChanged(_, _) => {
      let mut dispatched = false
      match self.platform_slots.lookup_host(window_id) {
        Some(slot) => {
          slot.decorations = linux_client_decoration_state(slot.window)
          let surface_metrics = linux_window_surface_metrics(slot.window)
          let metrics = linux_content_metrics_for_surface(
            surface_metrics,
            slot.decorations,
          )
          ignore(self.windows.resize(window_id, metrics))
          self.sync_runtime_slot(window_id)
          (self.renderer_provider.sync_surface)(slot.window, surface_metrics)
          slot.renderer.resize(to_render_metrics(surface_metrics))
          slot.window.request_redraw()
          self.dispatch_host_event(window_id, @host.HostEvent::Resized(metrics))
          dispatched = true
        }
        None => ()
      }
      if !dispatched {
        self.dispatch_window_event(window_id, event)
      }
    }
    @window_core.WindowEvent::PointerMoved(_, position, _, _) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_pointer_or_context_menu(window_id, event)
    }
    @window_core.WindowEvent::DragEntered(_, position)
    | @window_core.WindowEvent::DragMoved(position)
    | @window_core.WindowEvent::DragDropped(_, position) => {
      self.last_pointer = @host.physical_position_to_core(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::DragLeft(Some(position)) => {
      self.last_pointer = @host.physical_position_to_core(
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
    @window_core.WindowEvent::RedrawRequested =>
      if self.redraw_window(window_id) {
        event_loop.exit()
      }
    _ => self.dispatch_window_event(window_id, event)
  }
}

///|
fn LinuxApp::dispatch_pointer_or_context_menu(
  self : LinuxApp,
  window_id : @host.HostWindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  if @host.window_event_is_context_menu_button(event) {
    if self.pointer_is_in_client_titlebar(window_id) {
      return ()
    }
    if @host.window_event_is_context_menu_trigger(event) {
      match self.runtime_slots.lookup(window_id) {
        Some(slot) => ignore(slot.driver.show_context_menu(self.services))
        None => ()
      }
      self.sync_text_input_session()
    }
  } else {
    self.dispatch_window_event(window_id, event)
  }
}

///|
fn LinuxApp::pointer_is_in_client_titlebar(
  self : LinuxApp,
  window_id : @host.HostWindowId,
) -> Bool {
  match self.platform_slots.lookup_host(window_id) {
    Some(slot) =>
      slot.decorations.active &&
      self.last_pointer.y < slot.decorations.titlebar_height
    None => false
  }
}

///|
fn LinuxApp::redraw_window(
  self : LinuxApp,
  window_id : @host.HostWindowId,
) -> Bool {
  match
    (
      self.platform_slots.lookup_host(window_id),
      self.runtime_slots.lookup(window_id),
    ) {
    (Some(platform_slot), Some(runtime_slot)) => {
      let prior_completions = platform_slot.renderer.drain_present_completions()
      let prior_presented = @render.render_present_completions_have_presented(
        prior_completions,
      )
      let prior_terminal = @render.render_present_completions_have_terminal(
        prior_completions,
      )
      if platform_slot.frame_pending {
        if !prior_terminal {
          platform_slot.window.request_redraw()
          return false
        }
        platform_slot.frame_pending = false
        if prior_presented {
          ignore(
            self.image_repaint_tracker.record_presented(
              to_render_id(window_id),
              platform_slot.renderer,
            ),
          )
          ignore(
            self.renderer_provider.schedule_image_resource_loads(
              window_id,
              platform_slot.renderer,
              self.image_resource_completion_source(),
            ),
          )
          self.sync_text_input_session()
          if self.first_frame_smoke_auto_exit {
            println(
              "Linux renderer presented first frame; exiting by request; title=" +
              runtime_slot.record.title,
            )
            self.first_frame_smoke_auto_exit = false
            self.dispose_window(window_id)
            return true
          }
          if !runtime_slot_needs_redraw(runtime_slot) {
            return false
          }
        }
      }
      platform_slot.window.pre_present_notify()
      runtime_slot.driver.begin_redraw()
      let surface_metrics = linux_window_surface_metrics(platform_slot.window)
      let frame = runtime_slot.driver.draw_frame()
      let commands = linux_client_decorated_commands_with_clear_color(
        frame.commands,
        title=runtime_slot.record.title,
        metrics=surface_metrics,
        decorations=platform_slot.decorations,
        clear_color=frame.clear_color,
      )

      // Set up platform-view pixel drawing through any plugin that provides a
      // draw hook (Linux WebKitGTK offscreen rendering).
      let has_platform_views = frame.platform_views.length() > 0
      if has_platform_views {
        let f = frame
        let renderer = platform_slot.renderer
        let offset_y = platform_slot.decorations.titlebar_height
        let handle = platform_slot.window.wl_surface()
        for plugin in self.platform_view_plugins {
          match plugin.setup_platform_view_draw {
            Some(setup_fn) =>
              setup_fn(handle, f, offset_y, draw_fn => {
                renderer.set_platform_view_draw_fn(Some(draw_fn))
              })
            None => ()
          }
        }
      }

      let result = platform_slot.renderer.render_frame({
        ..frame,
        commands,
        damage: if platform_slot.decorations.active {
          @core.DamageRegion::full("linux client decorations")
        } else {
          frame.damage
        },
      })
      let present_completions = platform_slot.renderer.drain_present_completions()

      // Clear the platform view draw function
      if has_platform_views {
        platform_slot.renderer.set_platform_view_draw_fn(None)
      }

      let handle = platform_slot.window.wl_surface()
      for plugin in self.platform_view_plugins {
        (plugin.sync_platform_views)(
          handle,
          frame,
          platform_slot.decorations.titlebar_height,
        )
        (plugin.drain_commands)(handle)
      }
      runtime_slot.driver.apply_render_frame_result(result)
      runtime_slot.driver.finish_redraw()
      let completion_presented = @render.render_present_completions_have_presented(
        present_completions,
      )
      let completion_terminal = @render.render_present_completions_have_terminal(
        present_completions,
      )
      platform_slot.frame_pending = result.queued && !completion_terminal
      if completion_presented ||
        (present_completions.is_empty() && result.presented) {
        ignore(
          self.image_repaint_tracker.record_presented(
            to_render_id(window_id),
            platform_slot.renderer,
          ),
        )
      }
      ignore(
        self.renderer_provider.schedule_image_resource_loads(
          window_id,
          platform_slot.renderer,
          self.image_resource_completion_source(),
        ),
      )
      self.sync_text_input_session()
      let presented = completion_presented ||
        (present_completions.is_empty() && result.presented)
      if self.first_frame_smoke_auto_exit && presented {
        println(
          "Linux renderer presented first frame; exiting by request; title=" +
          runtime_slot.record.title,
        )
        self.first_frame_smoke_auto_exit = false
        self.dispose_window(window_id)
        true
      } else {
        if platform_slot.frame_pending ||
          (result.queued && completion_terminal && !completion_presented) {
          platform_slot.window.request_redraw()
        }
        false
      }
    }
    _ => false
  }
}

///|
/// Handle a decoded platform-view event received from a plugin's native event
/// dispatcher. Routes it into the runtime tree via
/// `HostRuntimeDriver::dispatch_platform_view`, bypassing `HostEvent` entirely.
fn LinuxApp::dispatch_platform_view_event_from_plugin(
  self : LinuxApp,
  window_ptr : UInt64,
  id : String,
  event : @core.PlatformViewEvent,
) -> Unit {
  match self.platform_view_host_id(window_ptr) {
    Some(window_id) => {
      match self.runtime_slots.lookup(window_id) {
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
/// Resolve a native `wl_surface` handle back to its `HostWindowId` by scanning
/// the live platform slots. Used to route native platform-view events.
fn LinuxApp::platform_view_host_id(
  self : LinuxApp,
  native_surface : UInt64,
) -> @host.HostWindowId? {
  for slot in self.platform_slots.slots {
    if slot.window.wl_surface() == native_surface {
      return Some(slot.host_id)
    }
  }
  None
}
