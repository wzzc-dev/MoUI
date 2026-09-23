///|
fn window_event_to_host_with_scale(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
  modifiers : @core.KeyModifiers,
  scale_factor~ : Double,
) -> @host.Event? {
  @window_input.window_event_to_host_with_modifiers(
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
    CloseRequested => {
      self.dispatch_host_event(window_id, CloseRequested)
      self.dispose_window(window_id)
      if self.lifecycle.runtime_slots_empty() {
        event_loop.exit()
      }
      return ()
    }
    DispatchHostEvent(host_event) => {
      match host_event {
        Resized(metrics) =>
          ignore(
            @window_host.sync_observed_resize(
              self.lifecycle,
              self.input,
              self.services,
              window_id,
              metrics,
            ),
          )
        _ => self.dispatch_host_event(window_id, host_event)
      }
      return ()
    }
    WindowRedrawRequired => {
      self.redraw_window(window_id)
      return ()
    }
    PlatformSpecific => ()
  }
  match event {
    PointerMoved(_, position, _, _) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    PointerButton(_, _, position, _, _) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_pointer_or_context_menu(window_id, event)
    }
    DragEntered(_, position) | DragMoved(position) | DragDropped(_, position) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    DragLeft(Some(position)) => {
      self.last_pointer = @window_input.normalize_pointer_position(
        position,
        scale_factor=self.current_scale_factor(window_id),
      )
      self.dispatch_window_event(window_id, event)
    }
    ModifiersChanged(modifiers) =>
      self.modifiers = @window_input.modifiers_to_core(modifiers)
    _ => self.dispatch_window_event(window_id, event)
  }
}

///|
fn WebApp::dispatch_pointer_or_context_menu(
  self : WebApp,
  window_id : @host.WindowId,
  event : @window_core.WindowEvent,
) -> Unit {
  if @window_input.window_event_is_context_menu_button(event) {
    // The press/release reaches the view tree first so per-target
    // `on_secondary_tap` handlers can record what was clicked; the menu is
    // built afterwards from that state. Without a handler on the hit view
    // the driver falls back to the program's global context-menu commands.
    self.dispatch_window_event(window_id, event)
    if @window_input.window_event_is_context_menu_trigger(event) {
      match self.lifecycle.runtime_slots().lookup(window_id) {
        Some(slot) =>
          ignore(slot.driver.show_context_menu(self.services.bridge()))
        None => ()
      }
      self.drain_async_host_services()
      self.sync_text_input_session()
    }
  } else {
    self.dispatch_window_event(window_id, event)
  }
}

///|
fn WebApp::dispatch_window_event(
  self : WebApp,
  window_id : @host.WindowId,
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
    ModifiersChanged(modifiers) => @window_input.modifiers_to_core(modifiers)
    KeyboardInput(_, key_event, false) =>
      web_modifiers_after_key_event(current, key_event)
    _ => current
  }
}

///|
fn web_modifiers_after_key_event(
  current : @core.KeyModifiers,
  event : @window_core.KeyEvent,
) -> @core.KeyModifiers {
  let pressed = @window_input.element_state_pressed(event.state())
  match event.logical_key() {
    Named(Shift) => { ..current, shift: pressed, }
    Named(Control) => { ..current, control: pressed, }
    Named(Alt) => { ..current, alt: pressed, }
    Named(Meta) => { ..current, meta: pressed, }
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
