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
