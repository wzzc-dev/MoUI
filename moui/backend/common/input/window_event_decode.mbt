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
    Pressed => Down
    Released => Up
  }
}

///|
pub fn element_state_pressed(state : @window_core.ElementState) -> Bool {
  match state {
    Pressed => true
    Released => false
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
    Character(text) => text
    Named(named) => named_key_name(named)
    Dead(_) => "Dead"
    Unidentified(_) => "Unidentified"
  }
}

///|
pub fn named_key_name(key : @window_core.NamedKey) -> String {
  match key {
    Enter => "Enter"
    Tab => "Tab"
    Backspace => "Backspace"
    Escape => "Escape"
    Delete => "Delete"
    ArrowLeft => "ArrowLeft"
    ArrowRight => "ArrowRight"
    ArrowUp => "ArrowUp"
    ArrowDown => "ArrowDown"
    _ => "\{key}"
  }
}

///|
pub fn mouse_button_to_core(button : @window_core.MouseButton) -> Int? {
  match button {
    Left => Some(0)
    Right => Some(1)
    Middle => Some(2)
    Back => Some(3)
    Forward => Some(4)
    _ => None
  }
}

///|
pub fn window_theme_to_color_scheme(
  theme : @window_core.Theme,
) -> @core.ColorScheme {
  match theme {
    Light => Light
    Dark => Dark
  }
}

///|
pub fn window_event_is_context_menu_trigger(
  event : @window_core.WindowEvent,
) -> Bool {
  match event {
    PointerButton(_, Pressed, _, true, Mouse(Right)) => true
    _ => false
  }
}

///|
pub fn window_event_is_context_menu_button(
  event : @window_core.WindowEvent,
) -> Bool {
  match event {
    PointerButton(_, _, _, _, Mouse(Right)) => true
    _ => false
  }
}

///|
pub fn touch_phase_to_host(
  phase : @window_core.TouchPhase,
) -> @backend_host.HostScrollPhase {
  match phase {
    Started => Started
    Moved => Moved
    Ended => Ended
    Cancelled => Cancelled
  }
}

///|
pub fn mouse_scroll_delta_to_host(
  delta : @window_core.MouseScrollDelta,
  scale_factor? : Double = 1.0,
) -> @backend_host.HostScrollDelta {
  match delta {
    LineDelta(x, y) => Lines(@core.Point::new(x~, y~))
    PixelDelta(position) =>
      Pixels(physical_position_to_core(position, scale_factor~))
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
    SurfaceResized(size) =>
      Some(Resized(surface_metrics_from_physical(size, scale_factor~)))
    ScaleFactorChanged(scale, writer) =>
      Some(
        Resized(
          surface_metrics_from_physical(
            writer.surface_size(),
            scale_factor=scale,
          ),
        ),
      )
    PointerMoved(_, position, _, _) =>
      Some(
        Pointer(
          @core.PointerEvent::new(
            position=physical_position_to_core(position, scale_factor~),
            phase=Move,
            modifiers~,
          ),
        ),
      )
    PointerButton(_, state, position, _, source) =>
      match source.mouse_button() {
        Some(button) =>
          match mouse_button_to_core(button) {
            Some(button) =>
              Some(
                Pointer(
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
    MouseWheel(_, delta, phase) =>
      Some(
        Scroll(
          @backend_host.HostScrollEvent::new(
            position=last_pointer,
            delta=mouse_scroll_delta_to_host(delta, scale_factor~),
            phase=touch_phase_to_host(phase),
          ),
        ),
      )
    DragEntered(paths, position) =>
      Some(
        DragDrop(
          @core.DragDropEvent::new(
            phase=Entered,
            paths~,
            position=Some(physical_position_to_core(position, scale_factor~)),
          ),
        ),
      )
    DragMoved(position) =>
      Some(
        DragDrop(
          @core.DragDropEvent::new(
            phase=Moved,
            position=Some(physical_position_to_core(position, scale_factor~)),
          ),
        ),
      )
    DragDropped(paths, position) =>
      Some(
        DragDrop(
          @core.DragDropEvent::new(
            phase=Dropped,
            paths~,
            position=Some(physical_position_to_core(position, scale_factor~)),
          ),
        ),
      )
    DragLeft(position) =>
      Some(
        DragDrop(
          @core.DragDropEvent::new(
            phase=Left,
            position=drag_drop_position_to_core(position, scale_factor~),
          ),
        ),
      )
    CloseRequested => Some(CloseRequested)
    RedrawRequested => Some(RedrawRequested)
    KeyboardInput(_, key_event, is_synthetic) =>
      if is_synthetic {
        None
      } else {
        Some(Keyboard(keyboard_event_to_core(key_event, modifiers)))
      }
    Ime(Enabled) => Some(TextInput(CompositionStart))
    Ime(Preedit(text, cursor)) =>
      Some(
        TextInput(
          CompositionUpdate(
            @core.CompositionUpdate::new(
              text~,
              cursor=ime_cursor_range_to_core(cursor),
            ),
          ),
        ),
      )
    Ime(Commit(text)) => Some(TextInput(CompositionEnd(text)))
    Ime(DeleteSurrounding(before, after)) =>
      Some(TextInput(DeleteSurrounding(before, after)))
    Ime(Disabled) => Some(TextInput(CompositionEnd("")))
    Focused(focused) =>
      Some(
        Focus(
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
    ThemeChanged(theme) =>
      Some(ThemeChanged(window_theme_to_color_scheme(theme)))
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
