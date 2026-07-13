///|
pub impl @window_macos.ApplicationHandler for MacosApp with fn can_create_surfaces(
  self,
  event_loop,
) {
  let platform = if self.transparent_titlebar {
    // Use titlebar_hidden to set title_hidden + titlebar_transparent +
    // fullsize_content_view atomically (line 3906 in window_delegate.mbt).
    // Then re-assert titlebar_transparent=true so the later individual
    // set_window_titlebar_transparent call (line 3914) doesn't revert it.
    self.platform_attributes
    .with_titlebar_hidden(true)
    .with_titlebar_transparent(true)
    .with_title_hidden(true)
    .with_fullsize_content_view(true)
    .with_movable_by_window_background(true)
  } else {
    self.platform_attributes
  }
  let base_attributes = @window_core.WindowAttributes::default()
    .with_title(self.title)
    .with_surface_size(runtime_size_to_window_surface_size(self.runtime.size()))
    .with_platform_attributes(platform)
  let attributes = match self.min_window_size {
    Some(min) => base_attributes.with_min_inner_size(@dpi.Size::Logical(min))
    None => base_attributes
  }
  let window : @window_macos.Window? = Some(
    event_loop.try_create_window(attributes),
  ) catch {
    err => {
      println("error creating macOS window: \{err}")
      event_loop.exit()
      None
    }
  }
  match window {
    Some(window) => {
      let metrics = @host.surface_metrics_from_physical(
        window.surface_size(),
        scale_factor=window.scale_factor(),
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
      match (self.renderer_provider.create_renderer)(window, metrics) {
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
              frame_pending: false,
            }),
          )
          window.request_redraw()
          self.drain_window_requests(event_loop)
          // The primary window is ready and the app has finished launching,
          // so the default macOS menu bar is already installed. Invoke the
          // optional on_ready hook now so apps can install a custom system
          // menu (installing earlier gets overwritten by the default menu).
          match self.on_ready {
            Some(callback) => callback()
            None => ()
          }
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
pub impl @window_macos.ApplicationHandler for MacosApp with fn window_event(
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
      self.dispatch_window_event(window_id, event)
      match self.platform_slots.lookup_host(window_id) {
        Some(slot) => {
          let metrics = @host.surface_metrics_from_physical(
            slot.window.surface_size(),
            scale_factor=slot.window.scale_factor(),
          )
          (self.renderer_provider.sync_surface)(slot.window, metrics)
          slot.renderer.resize(metrics)
          slot.window.request_redraw()
        }
        None => ()
      }
    }
    @window_core.WindowEvent::ScaleFactorChanged(_, _) => {
      self.dispatch_window_event(window_id, event)
      match self.platform_slots.lookup_host(window_id) {
        Some(slot) => {
          let metrics = @host.surface_metrics_from_physical(
            slot.window.surface_size(),
            scale_factor=slot.window.scale_factor(),
          )
          (self.renderer_provider.sync_surface)(slot.window, metrics)
          slot.renderer.resize(metrics)
          slot.window.request_redraw()
        }
        None => ()
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
fn MacosApp::dispatch_pointer_or_context_menu(
  self : MacosApp,
  window_id : @host.HostWindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  if @host.window_event_is_context_menu_button(event) {
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
fn MacosApp::redraw_window(
  self : MacosApp,
  window_id : @host.HostWindowId,
) -> Bool {
  match
    (
      self.platform_slots.lookup_host(window_id),
      self.runtime_slots.lookup(window_id),
    ) {
    (Some(platform_slot), Some(runtime_slot)) => {
      let prior_completions = platform_slot.renderer.drain_present_completions()
      let prior_presented = @host.render_present_completions_have_presented(
        prior_completions,
      )
      let prior_terminal = @host.render_present_completions_have_terminal(
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
              window_id,
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
          if self.finish_presented_window(window_id, runtime_slot) {
            return true
          }
          if !runtime_slot_needs_redraw(runtime_slot) {
            return false
          }
        }
      }
      platform_slot.window.pre_present_notify()
      runtime_slot.driver.begin_redraw()
      let frame = runtime_slot.driver.draw_frame()
      let result = platform_slot.renderer.render_frame(frame)
      let present_completions = platform_slot.renderer.drain_present_completions()
      match macos_native_view_handle(platform_slot.window) {
        Some(handle) =>
          for plugin in self.platform_view_plugins {
            (plugin.sync_platform_views)(handle, frame, 0.0)
            (plugin.drain_commands)(handle)
          }
        None => ()
      }
      runtime_slot.driver.apply_render_frame_result(result)
      runtime_slot.driver.finish_redraw()
      let completion_presented = @host.render_present_completions_have_presented(
        present_completions,
      )
      let completion_terminal = @host.render_present_completions_have_terminal(
        present_completions,
      )
      platform_slot.frame_pending = result.queued && !completion_terminal
      if completion_presented ||
        (present_completions.is_empty() && result.presented) {
        ignore(
          self.image_repaint_tracker.record_presented(
            window_id,
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
      if presented {
        self.finish_presented_window(window_id, runtime_slot)
      } else {
        if platform_slot.frame_pending {
          platform_slot.window.request_redraw()
        } else if result.queued && completion_terminal {
          // Dropped and terminal fallback completions retry against the same
          // AppRuntime; the provider will select raster after fallback.
          platform_slot.window.request_redraw()
        }
        false
      }
    }
    _ => false
  }
}

///|
fn MacosApp::finish_presented_window(
  self : MacosApp,
  window_id : @host.HostWindowId,
  runtime_slot : @host.HostWindowRuntimeSlot,
) -> Bool {
  if self.record_native_ime_runtime_smoke(window_id) {
    true
  } else if self.first_frame_smoke_auto_exit {
    println(
      "macOS renderer presented first frame; exiting by request; title=" +
      runtime_slot.record.title,
    )
    self.first_frame_smoke_auto_exit = false
    self.dispose_window(window_id)
    true
  } else {
    false
  }
}

///|
/// Handle a decoded platform-view event received from a plugin's native event
/// dispatcher. Routes it into the runtime tree via
/// `HostRuntimeDriver::dispatch_platform_view`, bypassing `HostEvent` entirely.
fn MacosApp::dispatch_platform_view_event_from_plugin(
  self : MacosApp,
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
/// Resolve a native content-view handle back to its `HostWindowId` by scanning
/// the live platform slots. Used to route native platform-view events.
fn MacosApp::platform_view_host_id(
  self : MacosApp,
  raw_content_view_handle : UInt64,
) -> @host.HostWindowId? {
  for slot in self.platform_slots.slots {
    match macos_native_view_handle(slot.window) {
      Some(handle) =>
        if handle == raw_content_view_handle {
          return Some(slot.host_id)
        }
      None => ()
    }
  }
  None
}
