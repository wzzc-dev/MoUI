///|
/// Routes neutral lifecycle events through Platform Bridge before retaining the
/// Windows-local raw input decoder below that boundary.
pub impl @win.ApplicationHandler for WindowsNativeHostBackend with fn window_event(
  self,
  event_loop,
  platform_window_id,
  event,
) {
  self.drain_window_requests(event_loop)
  if event_loop.exiting() {
    return ()
  }
  let window_id = match
    self.coordinator.platform_windows.lookup_host(platform_window_id) {
    Some(window_id) => window_id
    None => return ()
  }
  let surface_size = match self.platform_slots.lookup_host(window_id) {
    Some(slot) => Some(slot.window.surface_size())
    None => None
  }
  match
    @platform_bridge.transform_cross_platform_event(
      event,
      scale_factor=1.0,
      surface_size~,
    ) {
    @platform_bridge.TransformedWindowEvent::CloseRequested => {
      self.dispatch_host_event(window_id, @host.HostEvent::CloseRequested)
      self.dispose_window(window_id)
      if self.coordinator.runtime_slots_empty() {
        event_loop.exit()
      }
      return ()
    }
    @platform_bridge.TransformedWindowEvent::DispatchHostEvent(host_event) => {
      match self.coordinator.surface_actions(window_id) {
        Some(actions) =>
          match host_event {
            @host.HostEvent::Resized(metrics) => {
              (actions.sync_surface)(metrics)
              (actions.renderer_resize)(
                @render.RendererSurfaceMetrics::new(
                  logical_size=metrics.logical_size,
                  physical_size=metrics.physical_size,
                  scale_factor=metrics.scale_factor,
                ),
              )
              (actions.request_redraw)()
            }
            _ => ()
          }
        None => ()
      }
      self.dispatch_host_event(window_id, host_event)
      return ()
    }
    @platform_bridge.TransformedWindowEvent::WindowRedrawRequired => {
      if self.redraw_window(window_id) {
        event_loop.exit()
      }
      return ()
    }
    @platform_bridge.TransformedWindowEvent::PlatformSpecific => ()
  }
  match event {
    @window_core.WindowEvent::PointerMoved(_, position, _, _) => {
      self.last_pointer = @platform_bridge.normalize_pointer_position(
        position,
        scale_factor=1.0,
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = @platform_bridge.normalize_pointer_position(
        position,
        scale_factor=1.0,
      )
      self.dispatch_pointer_or_context_menu(window_id, event)
    }
    @window_core.WindowEvent::DragEntered(_, position)
    | @window_core.WindowEvent::DragMoved(position)
    | @window_core.WindowEvent::DragDropped(_, position) => {
      self.last_pointer = @platform_bridge.normalize_pointer_position(
        position,
        scale_factor=1.0,
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::DragLeft(Some(position)) => {
      self.last_pointer = @platform_bridge.normalize_pointer_position(
        position,
        scale_factor=1.0,
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
