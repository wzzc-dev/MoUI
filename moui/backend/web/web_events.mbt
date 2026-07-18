///|
pub fn window_event_to_host(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
) -> @host.HostEvent? {
  window_event_to_host_with_modifiers(
    event,
    last_pointer,
    @core.KeyModifiers::none(),
  )
}

///|
pub fn window_event_to_host_with_modifiers(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
  modifiers : @core.KeyModifiers,
) -> @host.HostEvent? {
  @host.window_event_to_host_with_modifiers(
    event,
    last_pointer,
    modifiers,
    scale_factor=1.0,
  )
}

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
      self.request_platform_redraw(window_id)
    }
    @window_core.WindowEvent::ScaleFactorChanged(_, _) => {
      self.dispatch_window_event(window_id, event)
      self.request_platform_redraw(window_id)
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
    @window_core.WindowEvent::ModifiersChanged(modifiers) =>
      self.modifiers = @host.modifiers_to_core(modifiers)
    @window_core.WindowEvent::RedrawRequested => self.redraw_window(window_id)
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
      match self.runtime_slots.lookup(window_id) {
        Some(slot) => ignore(slot.driver.show_context_menu(self.services))
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
fn web_pointer_phase(kind : Int) -> @core.PointerPhase? {
  match kind {
    20 | 21 => Some(Move)
    22 => Some(Exit)
    23 => Some(Down)
    24 => Some(Up)
    25 => Some(Cancel)
    30 => Some(Move)
    _ => None
  }
}

///|
fn web_pointer_modifiers(bits : Int) -> @core.KeyModifiers {
  @core.KeyModifiers::new(
    shift=(bits & 1) != 0,
    control=(bits & 2) != 0,
    alt=(bits & 4) != 0,
    meta=(bits & 8) != 0,
  )
}

///|
fn web_pointer_dispatch_flags(result : @runtime.InputDispatchResult) -> Int {
  let mut flags = 0
  if result.handled {
    flags = flags | 1
  }
  if result.capture_pointer {
    flags = flags | 2
  }
  if result.release_pointer {
    flags = flags | 4
  }
  flags
}

///|
fn WebApp::dispatch_web_pointer_input(
  self : WebApp,
  window_id : @host.HostWindowId,
  kind : Int,
  x_px : Double,
  y_px : Double,
  delta_x_px : Double,
  delta_y_px : Double,
  button : Int,
  modifier_bits : Int,
) -> Int {
  match web_pointer_phase(kind) {
    Some(phase) => {
      let scale_factor = self.current_scale_factor(window_id)
      let position = @host.physical_position_to_core(
        @dpi.PhysicalPositionF64(x_px, y_px),
        scale_factor~,
      )
      self.last_pointer = position
      self.modifiers = web_pointer_modifiers(modifier_bits)
      let pointer = @core.PointerEvent::new(
        position~,
        phase~,
        button~,
        wheel_delta=@host.physical_position_to_core(
          @dpi.PhysicalPositionF64(delta_x_px, delta_y_px),
          scale_factor~,
        ),
        modifiers=self.modifiers,
      )
      match self.runtime_slots.lookup(window_id) {
        Some(slot) => {
          let result = slot.driver.dispatch_pointer_input(pointer)
          ignore(
            self.publish_subscription_event(
              window_id,
              @host.HostEvent::Pointer(pointer),
            ),
          )
          self.drain_async_host_services()
          self.sync_text_input_session()
          web_pointer_dispatch_flags(result)
        }
        None => 0
      }
    }
    None => 0
  }
}

///|
fn WebApp::publish_subscription_event(
  self : WebApp,
  window_id : @host.HostWindowId,
  event : @host.HostEvent,
) -> @host.HostPlatformEventPublishResult? {
  match self.event_sources {
    Some(sources) => Some(sources.publish(window_id~, event~))
    None => None
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
    Some(host_event) => {
      self.apply_window_lifecycle(window_id, host_event)
      match self.runtime_slots.lookup(window_id) {
        Some(slot) =>
          match host_event {
            @host.HostEvent::Resized(metrics) => {
              self.resize_renderer(window_id, metrics)
              ignore(slot.driver.dispatch(host_event))
            }
            @host.HostEvent::Keyboard(event) =>
              ignore(
                slot.driver.dispatch_keyboard_with_services(
                  event,
                  self.services,
                ),
              )
            _ => ignore(slot.driver.dispatch(host_event))
          }
        None => ()
      }
      ignore(self.publish_subscription_event(window_id, host_event))
      self.drain_async_host_services()
      self.sync_text_input_session()
    }
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

///|
pub fn web_dispatch_pointer_input(
  raw_id : Int,
  kind : Int,
  x_px : Double,
  y_px : Double,
  delta_x_px : Double,
  delta_y_px : Double,
  button : Int,
  buttons : Int,
  pointer_id : Int,
  pointer_kind : Int,
  modifiers : Int,
) -> Int {
  let _ = buttons
  let _ = pointer_id
  let _ = pointer_kind
  match web_active_app.val {
    Some(app) =>
      match
        app.platform_windows.lookup_host(
          @window_core.WindowId::from_raw(raw_id),
        ) {
        Some(window_id) =>
          app.dispatch_web_pointer_input(
            window_id, kind, x_px, y_px, delta_x_px, delta_y_px, button, modifiers,
          )
        None => 0
      }
    None => 0
  }
}
