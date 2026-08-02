///|
fn window_event_to_host_with_scale(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
  modifiers : @core.KeyModifiers,
  scale_factor~ : Double,
) -> @host.HostEvent? {
  @host.window_event_to_host_with_modifiers(
    event,
    last_pointer,
    modifiers,
    scale_factor~,
    blur_to_cancel=true,
  )
}

///|
pub impl @window_web.ApplicationHandler for WebApp with fn window_event(
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
      scale_factor=self.current_scale_factor(window_id),
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
      self.dispatch_host_event(window_id, host_event)
      match host_event {
        @host.HostEvent::Resized(_) =>
          self.coordinator.request_platform_redraw(window_id)
        _ => ()
      }
      return ()
    }
    @platform_bridge.TransformedWindowEvent::WindowRedrawRequired => {
      self.redraw_window(window_id)
      return ()
    }
    @platform_bridge.TransformedWindowEvent::PlatformSpecific => ()
  }
  match event {
    @window_core.WindowEvent::PointerMoved(_, position, _, _) => {
      self.last_pointer = @platform_bridge.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::PointerButton(_, _, position, _, _) => {
      self.last_pointer = @platform_bridge.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_pointer_or_context_menu(window_id, event)
    }
    @window_core.WindowEvent::DragEntered(_, position)
    | @window_core.WindowEvent::DragMoved(position)
    | @window_core.WindowEvent::DragDropped(_, position) => {
      self.last_pointer = @platform_bridge.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::DragLeft(Some(position)) => {
      self.last_pointer = @platform_bridge.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      self.modifiers = @host.modifiers_to_core(modifiers)
    _ => self.dispatch_window_event(window_id, event)
  }
}

///|
fn WebApp::dispatch_pointer_or_context_menu(
  self : WebApp,
  window_id : @host.HostWindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  if @host.window_event_is_context_menu_button(event) {
    if @host.window_event_is_context_menu_trigger(event) {
      match self.coordinator.runtime_slots.lookup(window_id) {
        Some(slot) => ignore(slot.driver.show_context_menu(self.services))
        None => ()
      }
      self.drain_async_host_services()
      self.coordinator.sync_text_input_session()
    }
  } else {
    self.dispatch_window_event(window_id, event)
  }
}

///|
fn WebApp::dispatch_window_event(
  self : WebApp,
  window_id : @host.HostWindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  self.modifiers = web_modifiers_after_window_event(self.modifiers, event)
  match
    window_event_to_host_with_scale(
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
fn web_modifiers_after_window_event(
  current : @core.KeyModifiers,
  event : @window_core.WindowEvent,
) -> @core.KeyModifiers {
  match event {
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      @host.modifiers_to_core(modifiers)
    @window_core.WindowEvent::KeyboardInput(_, key_event, false) =>
      web_modifiers_after_key_event(current, key_event)
    _ => current
  }
}

///|
fn web_modifiers_after_key_event(
  current : @core.KeyModifiers,
  event : @window_core.KeyEvent,
) -> @core.KeyModifiers {
  let pressed = @host.element_state_pressed(event.state())
  match event.logical_key() {
    @window_core.Key::Named(@window_core.NamedKey::Shift) =>
      { ..current, shift: pressed }
    @window_core.Key::Named(@window_core.NamedKey::Control) =>
      { ..current, control: pressed }
    @window_core.Key::Named(@window_core.NamedKey::Alt) =>
      { ..current, alt: pressed }
    @window_core.Key::Named(@window_core.NamedKey::Meta) =>
      { ..current, meta: pressed }
    _ => current
  }
}

///|
pub fn web_dispatch_event(
  kind : Int,
  raw_id : Int,
  arg0 : Int,
  arg1 : Int,
  argd : Double,
  text_id : Int,
) -> Unit {
  @window_web.web_dispatch_event_by_id(kind, raw_id, arg0, arg1, argd, text_id)
}
