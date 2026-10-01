///|
/// 2D point with floating point coordinates
pub struct Point {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
pub extend Point with Debug::{to_repr}

///|
pub extend Point with Eq::{not_equal, equal}

///|
/// Create a new point
pub fn Point::new(x~ : Double, y~ : Double) -> Point {
  { x, y, }
}

///|
/// 2D vector (same as Point but semantically different)
pub struct Vec2 {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
pub extend Vec2 with Debug::{to_repr}

///|
pub extend Vec2 with Eq::{not_equal, equal}

///|
pub fn Vec2::new(x~ : Double, y~ : Double) -> Vec2 {
  { x, y, }
}
