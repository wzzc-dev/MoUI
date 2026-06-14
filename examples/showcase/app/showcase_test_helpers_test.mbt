///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn has_text_containing(
  commands : Array[@core.DrawCommand],
  text : String,
) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) &&
    value.contains(text)
  })
}

///|
fn has_image_fit(
  commands : Array[@core.DrawCommand],
  fit : @core.ImageFit,
) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawImage({ fit: image_fit, .. }) &&
    image_fit == fit
  })
}

///|
fn text_within(
  commands : Array[@core.DrawCommand],
  text : String,
  size : @core.Size,
) -> Bool {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text &&
          frame.origin.x >= 0.0 &&
          frame.origin.y >= 0.0 &&
          frame.origin.x + frame.size.width <= size.width &&
          frame.origin.y + frame.size.height <= size.height {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn click_text(runtime : @runtime.AppRuntime, text : String) -> Unit raise {
  guard text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for \{text}")
  }
  click_frame(runtime, frame)
}

///|
fn click_last_text(runtime : @runtime.AppRuntime, text : String) -> Unit raise {
  guard last_text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for \{text}")
  }
  click_frame(runtime, frame)
}

///|
fn click_frame(runtime : @runtime.AppRuntime, frame : @core.Rect) -> Unit {
  let position = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  click_point(runtime, position)
}

///|
fn host_click_frame(
  driver : @host.HostRuntimeDriver,
  frame : @core.Rect,
) -> Unit {
  let position = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  ignore(
    driver.dispatch(
      @host.HostEvent::Pointer(
        @core.PointerEvent::new(position~, phase=@core.PointerPhase::Down),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      @host.HostEvent::Pointer(
        @core.PointerEvent::new(position~, phase=@core.PointerPhase::Up),
      ),
    ),
  )
}

///|
fn click_point(runtime : @runtime.AppRuntime, position : @core.Point) -> Unit {
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position~, phase=@core.PointerPhase::Down),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position~, phase=@core.PointerPhase::Up),
    ),
  )
}

///|
fn last_text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  let mut frame : @core.Rect? = None
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame: next, .. }) =>
        if value == text {
          frame = Some(next)
        }
      _ => ()
    }
  }
  frame
}

///|
fn smallest_rounded_brush_containing(
  commands : Array[@core.DrawCommand],
  frame : @core.Rect,
) -> @core.Rect? {
  let mut candidate : @core.Rect? = None
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRectBrush({ rect, .. }, _) =>
        if rect_contains_rect(rect, frame) {
          candidate = match candidate {
            Some(existing) =>
              if rect_area(rect) < rect_area(existing) {
                Some(rect)
              } else {
                Some(existing)
              }
            None => Some(rect)
          }
        }
      _ => ()
    }
  }
  candidate
}

///|
fn rect_contains_rect(container : @core.Rect, child : @core.Rect) -> Bool {
  child.origin.x >= container.origin.x &&
  child.origin.y >= container.origin.y &&
  child.origin.x + child.size.width <= container.origin.x + container.size.width &&
  child.origin.y + child.size.height <=
  container.origin.y + container.size.height
}

///|
fn rect_area(rect : @core.Rect) -> Double {
  rect.size.width * rect.size.height
}

///|
fn rects_overlap(a : @core.Rect, b : @core.Rect) -> Bool {
  let a_right = a.origin.x + a.size.width
  let b_right = b.origin.x + b.size.width
  let a_bottom = a.origin.y + a.size.height
  let b_bottom = b.origin.y + b.size.height
  a.origin.x < b_right &&
  a_right > b.origin.x &&
  a.origin.y < b_bottom &&
  a_bottom > b.origin.y
}

///|
fn layout_tile_marker_count(commands : Array[@core.DrawCommand]) -> Int {
  let mut count = 0
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRect({ rect, radius }, _) =>
        if rect.size.width == 4.0 && rect.size.height == 22.0 && radius == 2.0 {
          count = count + 1
        }
      _ => ()
    }
  }
  count
}

///|
fn has_sidebar_scrollbar(commands : Array[@core.DrawCommand]) -> Bool {
  sidebar_scrollbar_frame(commands) is Some(_)
}

///|
fn sidebar_scrollbar_frame(commands : Array[@core.DrawCommand]) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRectBrush({ rect, .. }, _) =>
        if rect.size.width == 4.0 && rect.size.height >= 32.0 {
          return Some(rect)
        }
      _ => ()
    }
  }
  None
}

///|
