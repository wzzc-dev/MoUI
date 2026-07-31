///|
pub fn resolve_control_color(
  color : @core.Color?,
  fallback : @core.Color,
) -> @core.Color {
  match color {
    Some(value) => value
    None => fallback
  }
}

///|
pub fn clamp_view_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
pub fn max_view_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
pub fn min_view_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}
