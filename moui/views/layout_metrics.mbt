///|
fn available_width(width : Double, constraints : @core.Constraints) -> Double {
  constraints.constrain(@core.Size::new(width~, height=0.0)).width
}

///|
fn placement_width(width : Double, frame : @core.Rect) -> Double {
  if frame.size.width > 0.0 {
    layout_max_double(1.0, layout_min_double(width, frame.size.width))
  } else {
    layout_max_double(1.0, width)
  }
}

///|
fn layout_mirror_x(
  frame : @core.Rect,
  local_x : Double,
  width : Double,
  direction : @core.LayoutDirection,
) -> Double {
  match direction {
    @core.LayoutDirection::LeftToRight => frame.origin.x + local_x
    @core.LayoutDirection::RightToLeft =>
      frame.origin.x + frame.size.width - local_x - width
  }
}

///|
fn layout_ceil_div(a : Int, b : Int) -> Int {
  let b = layout_max_int(1, b)
  if a == 0 {
    0
  } else {
    (a + b - 1) / b
  }
}

///|
fn layout_min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn layout_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn layout_min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn layout_max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
