///|
/// Fill rule used when rasterizing a path.
pub(all) enum PathFillType {
  Winding
  EvenOdd
  InverseWinding
  InverseEvenOdd
} derive(Debug, Eq)

///|
pub impl Default for PathFillType with fn default() {
  Winding
}

///|
pub fn PathFillType::is_inverse(self : PathFillType) -> Bool {
  self is (InverseWinding | InverseEvenOdd)
}

///|
pub fn PathFillType::to_skia_ordinal(self : PathFillType) -> Int {
  match self {
    Winding => 0
    EvenOdd => 1
    InverseWinding => 2
    InverseEvenOdd => 3
  }
}

///|
/// Direction used when adding closed contours.
pub(all) enum PathDirection {
  CW
  CCW
} derive(Debug, Eq)

///|
pub impl Default for PathDirection with fn default() {
  CW
}

///|
pub fn PathDirection::to_skia_ordinal(self : PathDirection) -> Int {
  match self {
    CW => 0
    CCW => 1
  }
}

///|
/// How path appends connect the source path to the destination path.
pub(all) enum AddPathMode {
  Append
  Extend
} derive(Debug, Eq)

///|
pub impl Default for AddPathMode with fn default() {
  Append
}

///|
/// Cross-platform path verb data modeled after Skia path commands.
pub(all) enum PathVerb {
  MoveTo(Point)
  LineTo(Point)
  QuadTo(Point, Point)
  ConicTo(Point, Point, Float)
  CubicTo(Point, Point, Point)
  Close
} derive(Debug, Eq)

///|
/// A single line segment recognized from a path.
pub(all) struct PathLine {
  start : Point
  end : Point
} derive(Debug, Eq)

///|
pub fn PathLine::new(start : Point, end : Point) -> PathLine {
  { start, end }
}

///|
/// Rectangle recognized from a path, plus Skia's closed and direction metadata.
pub(all) struct PathRect {
  rect : Rect
  is_closed : Bool
  direction : PathDirection
} derive(Debug, Eq)

///|
pub fn PathRect::new(
  rect : Rect,
  is_closed : Bool,
  direction : PathDirection,
) -> PathRect {
  { rect, is_closed, direction }
}

///|
/// Bitmask of path segment kinds, matching Skia's public segment-mask values.
pub(all) struct PathSegmentMask(Int) derive(Debug, Eq)

///|
pub fn PathSegmentMask::new(value : Int) -> PathSegmentMask {
  PathSegmentMask(value)
}

///|
pub fn PathSegmentMask::empty() -> PathSegmentMask {
  PathSegmentMask::new(0)
}

///|
pub fn PathSegmentMask::line() -> PathSegmentMask {
  PathSegmentMask::new(1)
}

///|
pub fn PathSegmentMask::quad() -> PathSegmentMask {
  PathSegmentMask::new(2)
}

///|
pub fn PathSegmentMask::conic() -> PathSegmentMask {
  PathSegmentMask::new(4)
}

///|
pub fn PathSegmentMask::cubic() -> PathSegmentMask {
  PathSegmentMask::new(8)
}

///|
pub fn PathSegmentMask::bits(self : PathSegmentMask) -> Int {
  let PathSegmentMask(value) = self
  value
}

///|
pub fn PathSegmentMask::contains(
  self : PathSegmentMask,
  other : PathSegmentMask,
) -> Bool {
  (self.bits() & other.bits()) == other.bits()
}

///|
fn PathSegmentMask::union(
  self : PathSegmentMask,
  other : PathSegmentMask,
) -> PathSegmentMask {
  PathSegmentMask::new(self.bits() | other.bits())
}

///|
/// Cross-platform path value.
///
/// The native package owns real `SkPath` handles. This value layer keeps a
/// portable path command stream that can be built, inspected, and tested on all
/// MoonBit targets before being converted at a native boundary.
pub(all) struct Path {
  fill_type : PathFillType
  verbs : Array[PathVerb]
  current_point : Point?
} derive(Debug, Eq)

///|
pub fn Path::new(fill_type? : PathFillType = Winding) -> Path {
  { fill_type, verbs: Array::new(), current_point: None }
}

///|
pub impl Default for Path with fn default() {
  Path::new()
}

///|
pub fn Path::is_empty(self : Path) -> Bool {
  self.verbs.is_empty()
}

///|
pub fn Path::verb_count(self : Path) -> Int {
  self.verbs.length()
}

///|
pub fn Path::count_verbs(self : Path) -> Int {
  self.verb_count()
}

///|
pub fn Path::count_points(self : Path) -> Int {
  let initial_count = 0
  for count = initial_count, i = 0; i < self.verbs.length(); i = i + 1 {
    let increment = match self.verbs[i] {
      MoveTo(_) => 1
      LineTo(_) => 1
      QuadTo(_, _) => 2
      ConicTo(_, _, _) => 2
      CubicTo(_, _, _) => 3
      Close => 0
    }
    continue count + increment, i + 1
  } nobreak {
    count
  }
}

///|
pub fn Path::segment_masks(self : Path) -> PathSegmentMask {
  let initial_mask = PathSegmentMask::empty()
  for mask = initial_mask, i = 0; i < self.verbs.length(); i = i + 1 {
    let mask = match self.verbs[i] {
      MoveTo(_) | Close => mask
      LineTo(_) => mask.union(PathSegmentMask::line())
      QuadTo(_, _) => mask.union(PathSegmentMask::quad())
      ConicTo(_, _, _) => mask.union(PathSegmentMask::conic())
      CubicTo(_, _, _) => mask.union(PathSegmentMask::cubic())
    }
    continue mask, i + 1
  } nobreak {
    mask
  }
}

///|
fn path_scalar_is_finite(value : Scalar) -> Bool {
  value == value && value - value == 0.0
}

///|
fn path_point_is_finite(point : Point) -> Bool {
  path_scalar_is_finite(point.x) && path_scalar_is_finite(point.y)
}

///|
pub fn Path::is_finite(self : Path) -> Bool {
  for finite = true, i = 0; i < self.verbs.length(); i = i + 1 {
    let verb_finite = match self.verbs[i] {
      MoveTo(point) | LineTo(point) => path_point_is_finite(point)
      QuadTo(control, end) =>
        path_point_is_finite(control) && path_point_is_finite(end)
      ConicTo(control, end, weight) =>
        path_point_is_finite(control) &&
        path_point_is_finite(end) &&
        path_scalar_is_finite(weight)
      CubicTo(control0, control1, end) =>
        path_point_is_finite(control0) &&
        path_point_is_finite(control1) &&
        path_point_is_finite(end)
      Close => true
    }
    continue finite && verb_finite, i + 1
  } nobreak {
    finite
  }
}

///|
pub fn Path::is_inverse_fill_type(self : Path) -> Bool {
  self.fill_type.is_inverse()
}

///|
pub fn Path::is_last_contour_closed(self : Path) -> Bool {
  self.verbs.length() > 0 && self.verbs[self.verbs.length() - 1] is Close
}

///|
pub fn Path::last_point(self : Path) -> Point? {
  self.current_point
}

///|
pub fn Path::with_fill_type(self : Path, fill_type : PathFillType) -> Path {
  { ..self, fill_type, }
}
