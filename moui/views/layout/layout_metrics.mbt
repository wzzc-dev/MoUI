///|
pub fn available_width(
  width : Double,
  constraints : @core.Constraints,
) -> Double {
  constraints.constrain(@core.Size::new(width~, height=0.0)).width
}

///|
pub fn placement_width(width : Double, frame : @core.Rect) -> Double {
  if frame.size.width > 0.0 {
    max_double(1.0, min_double(width, frame.size.width))
  } else {
    max_double(1.0, width)
  }
}

///|
pub fn layout_ceil_div(a : Int32, b : Int32) -> Int32 {
  let b = max_int(1, b)
  if a == 0 {
    0
  } else {
    (a + b - 1) / b
  }
}

///|
pub fn max_int(a : Int32, b : Int32) -> Int32 {
  if a > b {
    a
  } else {
    b
  }
}

///|
pub fn min_int(a : Int32, b : Int32) -> Int32 {
  if a < b {
    a
  } else {
    b
  }
}

///|
pub fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
pub fn min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}
