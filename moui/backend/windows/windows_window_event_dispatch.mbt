///|
/// Routes neutral lifecycle events through backend/common before retaining the
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
  let window_id = match self.lifecycle.lookup_window(platform_window_id) {
    Some(window_id) => window_id
    None => return ()
  }
  let surface_size = match self.platform_slots.lookup_host(window_id) {
    Some(slot) => Some(slot.window.surface_size())
    None => None
  }
  let scale_factor = match self.platform_slots.lookup_host(window_id) {
    Some(slot) => slot.window.scale_factor()
    None => 1.0
  }
  match
    @window_input.transform_cross_platform_event(
      event,
      scale_factor~,
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
        @host.Event::Resized(metrics) => {
          ignore(
            @window_host.sync_observed_resize(
              self.lifecycle,
              self.input,
              self.services,
              window_id,
              metrics,
            ),
          )
          // Win32 enters a modal move/size loop while the border is dragged.
          // Present the resized surface from this synchronous callback so the
          // desktop compositor never stretches the previous frame.
          if self.redraw_window(window_id) {
            event_loop.exit()
          }
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
        scale_factor~,
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor~,
      )
      self.dispatch_pointer_or_context_menu(window_id, event)
    }
    @window_core.WindowEvent::DragEntered(_, position)
    | @window_core.WindowEvent::DragMoved(position)
    | @window_core.WindowEvent::DragDropped(_, position) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor~,
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::DragLeft(Some(position)) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor~,
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
