///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn has_text_color(
  commands : Array[@core.DrawCommand],
  text : String,
  color : @core.Color,
) -> Bool {
  commands.any(command => {
    command
    is @core.DrawCommand::DrawText({ text: value, color: value_color, .. }) &&
    value == text &&
    value_color == color
  })
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
fn click_text(runtime : @core.AppRuntime, text : String) -> Unit raise {
  guard text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for \{text}")
  }
  click_frame(runtime, frame)
}

///|
fn click_frame(runtime : @core.AppRuntime, frame : @core.Rect) -> Unit {
  let position = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
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
fn full_frame_solid_fill_count(commands : Array[@core.DrawCommand]) -> Int {
  let mut count = 0
  for command in commands {
    if is_full_frame_solid_fill(command) {
      count = count + 1
    }
  }
  count
}

///|
fn has_full_frame_solid_fill(
  commands : Array[@core.DrawCommand],
  alpha~ : Double,
) -> Bool {
  commands.any(command => {
    match command {
      @core.DrawCommand::FillRoundedRectBrush(
        { rect: { origin, size }, .. },
        @core.Brush::Solid({ r, g, b, a })
      ) =>
        origin.x == 0.0 &&
        origin.y == 0.0 &&
        size.width == 640.0 &&
        size.height == 480.0 &&
        r == 0.0 &&
        g == 0.0 &&
        b == 0.0 &&
        a == alpha
      _ => false
    }
  })
}

///|
fn has_solid_fill(
  commands : Array[@core.DrawCommand],
  color : @core.Color,
) -> Bool {
  commands.any(command => {
    match command {
      @core.DrawCommand::FillRoundedRectBrush(_, @core.Brush::Solid(value)) =>
        value == color
      _ => false
    }
  })
}

///|
fn is_full_frame_solid_fill(command : @core.DrawCommand) -> Bool {
  match command {
    @core.DrawCommand::FillRoundedRectBrush(
      { rect: { origin, size }, .. },
      @core.Brush::Solid(_)
    ) =>
      origin.x == 0.0 &&
      origin.y == 0.0 &&
      size.width == 640.0 &&
      size.height == 480.0
    _ => false
  }
}

///|
fn find_semantics_label(
  node : @core.SemanticsNode,
  label : String,
) -> @core.SemanticsNode? {
  if node.label == label {
    Some(node)
  } else {
    for child in node.children {
      match find_semantics_label(child, label) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
}
