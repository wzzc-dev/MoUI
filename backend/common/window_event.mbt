///|
pub fn physical_size_to_core(size : @dpi.PhysicalSize) -> @core.Size {
  @core.Size::new(
    width=size.width().to_double(),
    height=size.height().to_double(),
  )
}

///|
pub fn physical_position_to_core(
  position : @dpi.PhysicalPositionF64,
) -> @core.Point {
  @core.Point::new(x=position.x(), y=position.y())
}

///|
pub fn surface_metrics_from_physical(
  size : @dpi.PhysicalSize,
  scale_factor? : Double = 1.0,
) -> @host.HostSurfaceMetrics {
  let scale = if scale_factor > 0.0 { scale_factor } else { 1.0 }
  let physical = physical_size_to_core(size)
  @host.HostSurfaceMetrics::new(
    logical_size=@core.Size::new(
      width=physical.width / scale,
      height=physical.height / scale,
    ),
    physical_size=physical,
    scale_factor=scale,
  )
}

///|
pub fn element_state_to_pointer_phase(
  state : @window_core.ElementState,
) -> @core.PointerPhase {
  match state {
    @window_core.ElementState::Pressed => @core.PointerPhase::Down
    @window_core.ElementState::Released => @core.PointerPhase::Up
  }
}

///|
pub fn element_state_pressed(state : @window_core.ElementState) -> Bool {
  match state {
    @window_core.ElementState::Pressed => true
    @window_core.ElementState::Released => false
  }
}

///|
pub fn modifiers_to_core(
  modifiers : @window_core.Modifiers,
) -> @core.KeyModifiers {
  @core.KeyModifiers::new(
    shift=modifiers.shift_key(),
    control=modifiers.control_key(),
    alt=modifiers.alt_key(),
    meta=modifiers.meta_key(),
  )
}

///|
pub fn keyboard_event_to_core(
  event : @window_core.KeyEvent,
  modifiers : @core.KeyModifiers,
) -> @core.KeyboardEvent {
  @core.KeyboardEvent::new(
    key=key_event_name(event),
    text=key_event_text(event),
    pressed=element_state_pressed(event.state()),
    repeat=event.repeat(),
    modifiers~,
  )
}

///|
pub fn key_event_text(event : @window_core.KeyEvent) -> String? {
  match event.text() {
    Some(text) => if text == "" { None } else { Some(text) }
    None => None
  }
}

///|
pub fn key_event_name(event : @window_core.KeyEvent) -> String {
  match event.logical_key() {
    @window_core.Key::Character(text) => text
    @window_core.Key::Named(named) => named_key_name(named)
    @window_core.Key::Dead(_) => "Dead"
    @window_core.Key::Unidentified(_) => "Unidentified"
  }
}

///|
pub fn named_key_name(key : @window_core.NamedKey) -> String {
  match key {
    @window_core.NamedKey::Enter => "Enter"
    @window_core.NamedKey::Tab => "Tab"
    @window_core.NamedKey::Backspace => "Backspace"
    @window_core.NamedKey::Escape => "Escape"
    @window_core.NamedKey::Delete => "Delete"
    @window_core.NamedKey::ArrowLeft => "ArrowLeft"
    @window_core.NamedKey::ArrowRight => "ArrowRight"
    @window_core.NamedKey::ArrowUp => "ArrowUp"
    @window_core.NamedKey::ArrowDown => "ArrowDown"
    _ => "\{key}"
  }
}

///|
pub fn window_event_to_host_with_modifiers(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
  modifiers : @core.KeyModifiers,
  scale_factor? : Double = 1.0,
  blur_to_cancel? : Bool = false,
) -> @host.HostEvent? {
  match event {
    @window_core.WindowEvent::SurfaceResized(size) =>
      Some(
        @host.HostEvent::Resized(
          surface_metrics_from_physical(size, scale_factor~),
        ),
      )
    @window_core.WindowEvent::ScaleFactorChanged(scale, writer) =>
      Some(
        @host.HostEvent::Resized(
          surface_metrics_from_physical(
            writer.surface_size(),
            scale_factor=scale,
          ),
        ),
      )
    @window_core.WindowEvent::PointerMoved(_, position, _, _) =>
      Some(@host.HostEvent::PointerMoved(physical_position_to_core(position)))
    @window_core.WindowEvent::PointerButton(_, state, position, _, source) =>
      match source.mouse_button() {
        Some(@window_core.MouseButton::Left) =>
          Some(
            @host.HostEvent::PointerButton(
              physical_position_to_core(position),
              element_state_to_pointer_phase(state),
              0,
            ),
          )
        _ =>
          Some(
            @host.HostEvent::PointerButton(
              last_pointer,
              @core.PointerPhase::Cancel,
              0,
            ),
          )
      }
    @window_core.WindowEvent::CloseRequested =>
      Some(@host.HostEvent::CloseRequested)
    @window_core.WindowEvent::RedrawRequested =>
      Some(@host.HostEvent::RedrawRequested)
    @window_core.WindowEvent::KeyboardInput(_, key_event, is_synthetic) =>
      if is_synthetic {
        None
      } else {
        Some(
          @host.HostEvent::Keyboard(
            keyboard_event_to_core(key_event, modifiers),
          ),
        )
      }
    @window_core.WindowEvent::Ime(@window_core.Ime::Commit(text)) =>
      Some(@host.HostEvent::TextInput(text))
    @window_core.WindowEvent::Focused(focused) =>
      if blur_to_cancel && !focused {
        Some(
          @host.HostEvent::PointerButton(
            last_pointer,
            @core.PointerPhase::Cancel,
            0,
          ),
        )
      } else {
        None
      }
    _ => None
  }
}

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
pub fn window_event_to_core(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
) -> @core.AppEvent? {
  match window_event_to_host(event, last_pointer) {
    Some(host_event) => host_event.to_core()
    None => None
  }
}
