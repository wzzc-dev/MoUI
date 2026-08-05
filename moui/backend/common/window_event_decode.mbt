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
  scale_factor? : Double = 1.0,
) -> @core.Point {
  let scale = if scale_factor > 0.0 { scale_factor } else { 1.0 }
  @core.Point::new(x=position.x() / scale, y=position.y() / scale)
}

///|
pub fn surface_metrics_from_physical(
  size : @dpi.PhysicalSize,
  scale_factor? : Double = 1.0,
) -> @core.SurfaceMetrics {
  let scale = if scale_factor > 0.0 { scale_factor } else { 1.0 }
  let physical = physical_size_to_core(size)
  @core.SurfaceMetrics::new(
    logical_size=@core.Size::new(
      width=physical.width / scale,
      height=physical.height / scale,
    ),
    physical_size=physical,
    scale_factor=scale,
  )
}

///|
pub fn host_metrics_to_dpi_size(metrics : @core.SurfaceMetrics) -> @dpi.Size {
  @dpi.LogicalSize::LogicalSize(
    metrics.logical_size.width,
    metrics.logical_size.height,
  ).into_size()
}

///|
pub fn core_size_to_window_surface_size(size : @core.Size) -> @dpi.Size {
  @dpi.LogicalSize::LogicalSize(size.width, size.height).into_size()
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
pub fn mouse_button_to_core(button : @window_core.MouseButton) -> Int? {
  match button {
    @window_core.MouseButton::Left => Some(0)
    @window_core.MouseButton::Right => Some(1)
    @window_core.MouseButton::Middle => Some(2)
    @window_core.MouseButton::Back => Some(3)
    @window_core.MouseButton::Forward => Some(4)
    _ => None
  }
}

///|
pub fn window_theme_to_color_scheme(
  theme : @window_core.Theme,
) -> @core.ColorScheme {
  match theme {
    @window_core.Theme::Light => @core.ColorScheme::Light
    @window_core.Theme::Dark => @core.ColorScheme::Dark
  }
}

///|
pub fn window_event_is_context_menu_trigger(
  event : @window_core.WindowEvent,
) -> Bool {
  match event {
    @window_core.WindowEvent::PointerButton(
      _,
      @window_core.ElementState::Pressed,
      _,
      true,
      @window_core.ButtonSource::Mouse(@window_core.MouseButton::Right)
    ) => true
    _ => false
  }
}

///|
pub fn window_event_is_context_menu_button(
  event : @window_core.WindowEvent,
) -> Bool {
  match event {
    @window_core.WindowEvent::PointerButton(
      _,
      _,
      _,
      _,
      @window_core.ButtonSource::Mouse(@window_core.MouseButton::Right)
    ) => true
    _ => false
  }
}

///|
pub fn touch_phase_to_host(
  phase : @window_core.TouchPhase,
) -> @backend_host.HostScrollPhase {
  match phase {
    @window_core.TouchPhase::Started => @backend_host.HostScrollPhase::Started
    @window_core.TouchPhase::Moved => @backend_host.HostScrollPhase::Moved
    @window_core.TouchPhase::Ended => @backend_host.HostScrollPhase::Ended
    @window_core.TouchPhase::Cancelled =>
      @backend_host.HostScrollPhase::Cancelled
  }
}

///|
pub fn mouse_scroll_delta_to_host(
  delta : @window_core.MouseScrollDelta,
  scale_factor? : Double = 1.0,
) -> @backend_host.HostScrollDelta {
  match delta {
    @window_core.MouseScrollDelta::LineDelta(x, y) =>
      @backend_host.HostScrollDelta::Lines(@core.Point::new(x~, y~))
    @window_core.MouseScrollDelta::PixelDelta(position) =>
      @backend_host.HostScrollDelta::Pixels(
        physical_position_to_core(position, scale_factor~),
      )
  }
}

///|
fn drag_drop_position_to_core(
  position : @dpi.PhysicalPositionF64?,
  scale_factor~ : Double,
) -> @core.Point? {
  match position {
    Some(position) => Some(physical_position_to_core(position, scale_factor~))
    None => None
  }
}

///|
pub fn window_event_to_host_with_modifiers(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
  modifiers : @core.KeyModifiers,
  scale_factor? : Double = 1.0,
  blur_to_cancel? : Bool = false,
) -> @backend_host.Event? {
  match event {
    @window_core.WindowEvent::SurfaceResized(size) =>
      Some(
        @backend_host.Event::Resized(
          surface_metrics_from_physical(size, scale_factor~),
        ),
      )
    @window_core.WindowEvent::ScaleFactorChanged(scale, writer) =>
      Some(
        @backend_host.Event::Resized(
          surface_metrics_from_physical(
            writer.surface_size(),
            scale_factor=scale,
          ),
        ),
      )
    @window_core.WindowEvent::PointerMoved(_, position, _, _) =>
      Some(
        @backend_host.Event::Pointer(
          @core.PointerEvent::new(
            position=physical_position_to_core(position, scale_factor~),
            phase=@core.PointerPhase::Move,
            modifiers~,
          ),
        ),
      )
    @window_core.WindowEvent::PointerButton(_, state, position, _, source) =>
      match source.mouse_button() {
        Some(button) =>
          match mouse_button_to_core(button) {
            Some(button) =>
              Some(
                @backend_host.Event::Pointer(
                  @core.PointerEvent::new(
                    position=physical_position_to_core(position, scale_factor~),
                    phase=element_state_to_pointer_phase(state),
                    button~,
                    modifiers~,
                  ),
                ),
              )
            None => None
          }
        None => None
      }
    @window_core.WindowEvent::MouseWheel(_, delta, phase) =>
      Some(
        @backend_host.Event::Scroll(
          @backend_host.HostScrollEvent::new(
            position=last_pointer,
            delta=mouse_scroll_delta_to_host(delta, scale_factor~),
            phase=touch_phase_to_host(phase),
          ),
        ),
      )
    @window_core.WindowEvent::DragEntered(paths, position) =>
      Some(
        @backend_host.Event::DragDrop(
          @core.DragDropEvent::new(
            phase=@core.DragDropPhase::Entered,
            paths~,
            position=Some(physical_position_to_core(position, scale_factor~)),
          ),
        ),
      )
    @window_core.WindowEvent::DragMoved(position) =>
      Some(
        @backend_host.Event::DragDrop(
          @core.DragDropEvent::new(
            phase=@core.DragDropPhase::Moved,
            position=Some(physical_position_to_core(position, scale_factor~)),
          ),
        ),
      )
    @window_core.WindowEvent::DragDropped(paths, position) =>
      Some(
        @backend_host.Event::DragDrop(
          @core.DragDropEvent::new(
            phase=@core.DragDropPhase::Dropped,
            paths~,
            position=Some(physical_position_to_core(position, scale_factor~)),
          ),
        ),
      )
    @window_core.WindowEvent::DragLeft(position) =>
      Some(
        @backend_host.Event::DragDrop(
          @core.DragDropEvent::new(
            phase=@core.DragDropPhase::Left,
            position=drag_drop_position_to_core(position, scale_factor~),
          ),
        ),
      )
    @window_core.WindowEvent::CloseRequested =>
      Some(@backend_host.Event::CloseRequested)
    @window_core.WindowEvent::RedrawRequested =>
      Some(@backend_host.Event::RedrawRequested)
    @window_core.WindowEvent::KeyboardInput(_, key_event, is_synthetic) =>
      if is_synthetic {
        None
      } else {
        Some(
          @backend_host.Event::Keyboard(
            keyboard_event_to_core(key_event, modifiers),
          ),
        )
      }
    @window_core.WindowEvent::Ime(@window_core.Ime::Enabled) =>
      Some(
        @backend_host.Event::TextInput(@core.TextInputEvent::CompositionStart),
      )
    @window_core.WindowEvent::Ime(@window_core.Ime::Preedit(text, cursor)) =>
      Some(
        @backend_host.Event::TextInput(
          @core.TextInputEvent::CompositionUpdate(
            @core.CompositionUpdate::new(
              text~,
              cursor=ime_cursor_range_to_core(cursor),
            ),
          ),
        ),
      )
    @window_core.WindowEvent::Ime(@window_core.Ime::Commit(text)) =>
      Some(
        @backend_host.Event::TextInput(
          @core.TextInputEvent::CompositionEnd(text),
        ),
      )
    @window_core.WindowEvent::Ime(
      @window_core.Ime::DeleteSurrounding(before, after)
    ) =>
      Some(
        @backend_host.Event::TextInput(
          @core.TextInputEvent::DeleteSurrounding(before, after),
        ),
      )
    @window_core.WindowEvent::Ime(@window_core.Ime::Disabled) =>
      Some(
        @backend_host.Event::TextInput(@core.TextInputEvent::CompositionEnd("")),
      )
    @window_core.WindowEvent::Focused(focused) =>
      Some(
        @backend_host.Event::Focus(
          @backend_host.HostFocusEvent::new(
            focused~,
            pointer_cancel_position=if blur_to_cancel && !focused {
              Some(last_pointer)
            } else {
              None
            },
          ),
        ),
      )
    @window_core.WindowEvent::ThemeChanged(theme) =>
      Some(
        @backend_host.Event::ThemeChanged(window_theme_to_color_scheme(theme)),
      )
    _ => None
  }
}

///|
fn ime_cursor_range_to_core(
  cursor : @window_core.ImeCursorRange?,
) -> @core.TextRange? {
  match cursor {
    Some(cursor) =>
      Some(@core.TextRange::new(start=cursor.start(), end=cursor.end()))
    None => None
  }
}

///|
pub fn window_event_to_host(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
) -> @backend_host.Event? {
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
