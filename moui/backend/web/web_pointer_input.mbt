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
          // The browser ABI needs a synchronous consumption result. Keep the
          // shared host driver responsible for redraw scheduling, but bypass
          // its ordinary fire-and-forget event result for this one path.
          let result = slot.driver.runtime.dispatch_pointer_input(pointer)
          slot.driver.request_redraw_if_needed()
          ignore(
            self.publish_subscription_event(
              window_id,
              @host.HostEvent::Pointer(pointer),
            ),
          )
          self.drain_async_host_services()
          self.sync_text_input_session()
          result.host_flags()
        }
        None => 0
      }
    }
    None => 0
  }
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
  modifiers : Int,
) -> Int {
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
