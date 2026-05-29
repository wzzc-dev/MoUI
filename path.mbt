///|
/// Fill rule used when rasterizing a path.
#warnings("-deprecated_syntax")
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
#warnings("-deprecated_syntax")
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
pub fn Path::is_line(self : Path) -> PathLine? {
  if self.verbs.length() == 2 {
    match (self.verbs[0], self.verbs[1]) {
      (MoveTo(start), LineTo(end)) => Some(PathLine::new(start, end))
      _ => None
    }
  } else {
    None
  }
}

///|
pub fn Path::is_rect(self : Path) -> PathRect? {
  if self.verbs.length() == 5 {
    match
      (
        self.verbs[0],
        self.verbs[1],
        self.verbs[2],
        self.verbs[3],
        self.verbs[4],
      ) {
      (MoveTo(p0), LineTo(p1), LineTo(p2), LineTo(p3), Close) =>
        if p0.y == p1.y && p1.x == p2.x && p2.y == p3.y && p3.x == p0.x {
          Some(
            PathRect::new(Rect::new(p0.x, p0.y, p2.x, p2.y).sorted(), true, CW),
          )
        } else if p0.x == p1.x && p1.y == p2.y && p2.x == p3.x && p3.y == p0.y {
          Some(
            PathRect::new(Rect::new(p0.x, p0.y, p2.x, p2.y).sorted(), true, CCW),
          )
        } else {
          None
        }
      _ => None
    }
  } else {
    None
  }
}

///|
pub fn Path::is_oval(self : Path) -> Rect? {
  if self.verbs.length() == 6 {
    match
      (
        self.verbs[0],
        self.verbs[1],
        self.verbs[2],
        self.verbs[3],
        self.verbs[4],
        self.verbs[5],
      ) {
      (
        MoveTo(start),
        ConicTo(control0, end0, weight0),
        ConicTo(control1, end1, weight1),
        ConicTo(control2, end2, weight2),
        ConicTo(control3, end3, weight3),
        Close,
      ) => {
        let conic_weight : Scalar = 0.70710677
        if weight0 == conic_weight &&
          weight1 == conic_weight &&
          weight2 == conic_weight &&
          weight3 == conic_weight &&
          start == end3 &&
          start.x == control0.x &&
          start.x == control3.x &&
          end0.y == control0.y &&
          end0.y == control1.y &&
          end1.x == control1.x &&
          end1.x == control2.x &&
          end2.y == control2.y &&
          end2.y == control3.y &&
          end0.x == end2.x &&
          end1.y == start.y {
          Some(Rect::new(end1.x, end0.y, start.x, end2.y).sorted())
        } else {
          None
        }
      }
      _ => None
    }
  } else {
    None
  }
}

///|
fn include_path_bounds_point(bounds : Rect?, point : Point) -> Rect? {
  match bounds {
    None => Some(Rect::new(point.x, point.y, point.x, point.y))
    Some(rect) =>
      Some(
        Rect::new(
          Float::min(rect.left, point.x),
          Float::min(rect.top, point.y),
          Float::max(rect.right, point.x),
          Float::max(rect.bottom, point.y),
        ),
      )
  }
}

///|
pub fn Path::bounds(self : Path) -> Rect? {
  let initial_bounds : Rect? = None
  for bounds = initial_bounds, i = 0; i < self.verbs.length(); i = i + 1 {
    let bounds = match self.verbs[i] {
      MoveTo(point) | LineTo(point) => include_path_bounds_point(bounds, point)
      QuadTo(control, end) =>
        include_path_bounds_point(
          include_path_bounds_point(bounds, control),
          end,
        )
      ConicTo(control, end, _) =>
        include_path_bounds_point(
          include_path_bounds_point(bounds, control),
          end,
        )
      CubicTo(control0, control1, end) =>
        include_path_bounds_point(
          include_path_bounds_point(
            include_path_bounds_point(bounds, control0),
            control1,
          ),
          end,
        )
      Close => bounds
    }
    continue bounds, i + 1
  } nobreak {
    bounds
  }
}

///|
fn path_eval_quad_scalar(
  p0 : Scalar,
  p1 : Scalar,
  p2 : Scalar,
  t : Scalar,
) -> Scalar {
  let u : Scalar = 1.0 - t
  u * u * p0 + u * 2.0 * t * p1 + t * t * p2
}

///|
fn path_eval_conic_scalar(
  p0 : Scalar,
  p1 : Scalar,
  p2 : Scalar,
  weight : Scalar,
  t : Scalar,
) -> Scalar {
  let u : Scalar = 1.0 - t
  let numerator = u * u * p0 + weight * 2.0 * u * t * p1 + t * t * p2
  let denominator = u * u + weight * 2.0 * u * t + t * t
  numerator / denominator
}

///|
fn path_eval_cubic_scalar(
  p0 : Scalar,
  p1 : Scalar,
  p2 : Scalar,
  p3 : Scalar,
  t : Scalar,
) -> Scalar {
  let u : Scalar = 1.0 - t
  u * u * u * p0 + u * 3.0 * u * t * p1 + u * 3.0 * t * t * p2 + t * t * t * p3
}

///|
fn include_path_parametric_point(
  bounds : Rect?,
  x0 : Scalar,
  x1 : Scalar,
  x2 : Scalar,
  y0 : Scalar,
  y1 : Scalar,
  y2 : Scalar,
  t : Scalar,
) -> Rect? {
  if t > 0.0 && t < 1.0 {
    include_path_bounds_point(
      bounds,
      Point::new(
        path_eval_quad_scalar(x0, x1, x2, t),
        path_eval_quad_scalar(y0, y1, y2, t),
      ),
    )
  } else {
    bounds
  }
}

///|
fn include_path_conic_parametric_point(
  bounds : Rect?,
  x0 : Scalar,
  x1 : Scalar,
  x2 : Scalar,
  y0 : Scalar,
  y1 : Scalar,
  y2 : Scalar,
  weight : Scalar,
  t : Scalar,
) -> Rect? {
  if t > 0.0 && t < 1.0 {
    include_path_bounds_point(
      bounds,
      Point::new(
        path_eval_conic_scalar(x0, x1, x2, weight, t),
        path_eval_conic_scalar(y0, y1, y2, weight, t),
      ),
    )
  } else {
    bounds
  }
}

///|
fn include_path_cubic_parametric_point(
  bounds : Rect?,
  x0 : Scalar,
  x1 : Scalar,
  x2 : Scalar,
  x3 : Scalar,
  y0 : Scalar,
  y1 : Scalar,
  y2 : Scalar,
  y3 : Scalar,
  t : Scalar,
) -> Rect? {
  if t > 0.0 && t < 1.0 {
    include_path_bounds_point(
      bounds,
      Point::new(
        path_eval_cubic_scalar(x0, x1, x2, x3, t),
        path_eval_cubic_scalar(y0, y1, y2, y3, t),
      ),
    )
  } else {
    bounds
  }
}

///|
fn include_path_quad_extrema(
  bounds : Rect?,
  start : Point,
  control : Point,
  end : Point,
) -> Rect? {
  let bounds = include_path_bounds_point(
    include_path_bounds_point(bounds, start),
    end,
  )
  let include_axis = fn(
    bounds : Rect?,
    p0 : Scalar,
    p1 : Scalar,
    p2 : Scalar,
  ) -> Rect? {
    let denominator = p0 - 2.0 * p1 + p2
    if denominator == 0.0 {
      bounds
    } else {
      let t = (p0 - p1) / denominator
      include_path_parametric_point(
        bounds,
        start.x,
        control.x,
        end.x,
        start.y,
        control.y,
        end.y,
        t,
      )
    }
  }
  include_axis(
    include_axis(bounds, start.x, control.x, end.x),
    start.y,
    control.y,
    end.y,
  )
}

///|
fn include_path_conic_extrema(
  bounds : Rect?,
  start : Point,
  control : Point,
  end : Point,
  weight : Scalar,
) -> Rect? {
  let bounds = include_path_bounds_point(
    include_path_bounds_point(bounds, start),
    end,
  )
  let include_axis = fn(
    bounds : Rect?,
    p0 : Scalar,
    p1 : Scalar,
    p2 : Scalar,
  ) -> Rect? {
    let denominator = p0 - weight * p1 - p1 + p2 * weight
    if denominator == 0.0 {
      bounds
    } else {
      let t = (p0 - weight * p1) / denominator
      include_path_conic_parametric_point(
        bounds,
        start.x,
        control.x,
        end.x,
        start.y,
        control.y,
        end.y,
        weight,
        t,
      )
    }
  }
  include_axis(
    include_axis(bounds, start.x, control.x, end.x),
    start.y,
    control.y,
    end.y,
  )
}

///|
fn include_path_cubic_axis_extrema(
  bounds : Rect?,
  start : Point,
  control0 : Point,
  control1 : Point,
  end : Point,
  a : Scalar,
  b : Scalar,
  c : Scalar,
) -> Rect? {
  if a == 0.0 {
    if b == 0.0 {
      bounds
    } else {
      include_path_cubic_parametric_point(
        bounds,
        start.x,
        control0.x,
        control1.x,
        end.x,
        start.y,
        control0.y,
        control1.y,
        end.y,
        -c / b,
      )
    }
  } else {
    let discriminant = b * b - 4.0 * a * c
    if discriminant < 0.0 {
      bounds
    } else {
      let root = discriminant.sqrt()
      let bounds = include_path_cubic_parametric_point(
        bounds,
        start.x,
        control0.x,
        control1.x,
        end.x,
        start.y,
        control0.y,
        control1.y,
        end.y,
        (-b + root) / (2.0 * a),
      )
      include_path_cubic_parametric_point(
        bounds,
        start.x,
        control0.x,
        control1.x,
        end.x,
        start.y,
        control0.y,
        control1.y,
        end.y,
        (-b - root) / (2.0 * a),
      )
    }
  }
}

///|
fn include_path_cubic_extrema(
  bounds : Rect?,
  start : Point,
  control0 : Point,
  control1 : Point,
  end : Point,
) -> Rect? {
  let bounds = include_path_bounds_point(
    include_path_bounds_point(bounds, start),
    end,
  )
  let include_axis = fn(
    bounds : Rect?,
    p0 : Scalar,
    p1 : Scalar,
    p2 : Scalar,
    p3 : Scalar,
  ) -> Rect? {
    let a = -p0 + 3.0 * p1 - 3.0 * p2 + p3
    let b = (p0 - p1 * 2.0 + p2) * 2.0
    let c = -p0 + p1
    include_path_cubic_axis_extrema(
      bounds, start, control0, control1, end, a, b, c,
    )
  }
  include_axis(
    include_axis(bounds, start.x, control0.x, control1.x, end.x),
    start.y,
    control0.y,
    control1.y,
    end.y,
  )
}

///|
/// Computes a tighter geometric bound for quadratic, conic, and cubic curves.
///
/// `bounds` records the path's control-point bounds, matching Skia's cached
/// path bounds. This method mirrors Skia's `computeTightBounds` distinction by
/// adding only curve extrema that affect the actual drawn curve.
pub fn Path::compute_tight_bounds(self : Path) -> Rect? {
  let initial_bounds : Rect? = None
  let initial_current : Point? = None
  let initial_contour_start : Point? = None
  for bounds = initial_bounds, current = initial_current, contour_start = initial_contour_start, i = 0
      i < self.verbs.length()
      i = i + 1 {
    let (bounds, current, contour_start) = match self.verbs[i] {
      MoveTo(point) =>
        (include_path_bounds_point(bounds, point), Some(point), Some(point))
      LineTo(point) =>
        (
          match current {
            None => include_path_bounds_point(bounds, point)
            Some(start) =>
              include_path_bounds_point(
                include_path_bounds_point(bounds, start),
                point,
              )
          },
          Some(point),
          contour_start,
        )
      QuadTo(control, end) =>
        (
          match current {
            None => include_path_bounds_point(bounds, end)
            Some(start) =>
              include_path_quad_extrema(bounds, start, control, end)
          },
          Some(end),
          contour_start,
        )
      ConicTo(control, end, weight) =>
        (
          match current {
            None => include_path_bounds_point(bounds, end)
            Some(start) =>
              include_path_conic_extrema(bounds, start, control, end, weight)
          },
          Some(end),
          contour_start,
        )
      CubicTo(control0, control1, end) =>
        (
          match current {
            None => include_path_bounds_point(bounds, end)
            Some(start) =>
              include_path_cubic_extrema(bounds, start, control0, control1, end)
          },
          Some(end),
          contour_start,
        )
      Close =>
        (
          match (current, contour_start) {
            (Some(start), Some(end)) =>
              include_path_bounds_point(
                include_path_bounds_point(bounds, start),
                end,
              )
            _ => bounds
          },
          contour_start,
          contour_start,
        )
    }
    continue bounds, current, contour_start, i + 1
  } nobreak {
    bounds
  }
}

///|
pub fn Path::stroke_bounds(self : Path, paint : Paint) -> Rect? {
  match self.bounds() {
    None => None
    Some(bounds) =>
      if paint.style is Fill || paint.stroke_width <= 0.0 {
        Some(bounds)
      } else {
        let outset = paint.stroke_width / 2.0
        Some(bounds.outset(outset, outset))
      }
  }
}

///|
fn path_contains_crosses_edge(
  start : Point,
  end : Point,
  point : Point,
) -> Bool {
  (start.y > point.y) != (end.y > point.y) &&
  point.x <
  (end.x - start.x) * (point.y - start.y) / (end.y - start.y) + start.x
}

///|
fn Path::path_contains_closed_contours(self : Path, point : Point) -> Bool {
  let initial_inside = false
  let initial_current : Point? = None
  let initial_contour_start : Point? = None
  for inside = initial_inside, current = initial_current, contour_start = initial_contour_start, i = 0
      i < self.verbs.length()
      i = i + 1 {
    let (inside, current, contour_start) = match self.verbs[i] {
      MoveTo(next) => (inside, Some(next), Some(next))
      LineTo(next) =>
        match current {
          None => (inside, Some(next), contour_start)
          Some(start) =>
            (
              if path_contains_crosses_edge(start, next, point) {
                !inside
              } else {
                inside
              },
              Some(next),
              contour_start,
            )
        }
      QuadTo(_, end) | ConicTo(_, end, _) | CubicTo(_, _, end) =>
        match current {
          None => (inside, Some(end), contour_start)
          Some(start) =>
            (
              if path_contains_crosses_edge(start, end, point) {
                !inside
              } else {
                inside
              },
              Some(end),
              contour_start,
            )
        }
      Close =>
        match (current, contour_start) {
          (Some(start), Some(end)) =>
            (
              if path_contains_crosses_edge(start, end, point) {
                !inside
              } else {
                inside
              },
              contour_start,
              contour_start,
            )
          _ => (inside, current, contour_start)
        }
    }
    continue inside, current, contour_start, i + 1
  } nobreak {
    inside
  }
}

///|
/// Returns whether `point` is inside the portable path approximation.
///
/// This value-layer implementation treats line segments exactly and uses curve
/// endpoints for curved verbs. The native package delegates `Path::contains` to
/// Skia for full curve-aware containment when Skia is linked.
pub fn Path::contains(self : Path, point : Point) -> Bool {
  match self.bounds() {
    None => self.fill_type.is_inverse()
    Some(bounds) =>
      if self.fill_type.is_inverse() {
        !bounds.contains_point(point) ||
        !self.path_contains_closed_contours(point)
      } else {
        bounds.contains_point(point) &&
        self.path_contains_closed_contours(point)
      }
  }
}

///|
pub fn Path::with_fill_type(self : Path, fill_type : PathFillType) -> Path {
  { ..self, fill_type, }
}

///|
pub fn Path::transform(self : Path, matrix : Matrix) -> Path {
  fn map_verb(verb : PathVerb) -> PathVerb {
    match verb {
      MoveTo(point) => MoveTo(matrix.map_point(point))
      LineTo(point) => LineTo(matrix.map_point(point))
      QuadTo(control, end) =>
        QuadTo(matrix.map_point(control), matrix.map_point(end))
      ConicTo(control, end, weight) =>
        ConicTo(matrix.map_point(control), matrix.map_point(end), weight)
      CubicTo(control0, control1, end) =>
        CubicTo(
          matrix.map_point(control0),
          matrix.map_point(control1),
          matrix.map_point(end),
        )
      Close => Close
    }
  }

  {
    fill_type: self.fill_type,
    verbs: self.verbs.map(map_verb),
    current_point: match self.current_point {
      None => None
      Some(point) => Some(matrix.map_point(point))
    },
  }
}

///|
pub fn Path::offset(self : Path, dx : Scalar, dy : Scalar) -> Path {
  self.transform(Matrix::translate(dx, dy))
}

///|
pub fn Path::reset(self : Path) -> Path {
  ignore(self)
  Path::new()
}

///|
pub fn Path::rewind(self : Path) -> Path {
  self.reset()
}

///|
fn Path::append_verb(
  self : Path,
  verb : PathVerb,
  current_point : Point?,
) -> Path {
  let verbs = self.verbs.copy()
  verbs.push(verb)
  { ..self, verbs, current_point }
}

///|
pub fn Path::move_to(self : Path, point : Point) -> Path {
  self.append_verb(MoveTo(point), Some(point))
}

///|
pub fn Path::line_to(self : Path, point : Point) -> Path {
  self.append_verb(LineTo(point), Some(point))
}

///|
pub fn Path::quad_to(self : Path, control : Point, end : Point) -> Path {
  self.append_verb(QuadTo(control, end), Some(end))
}

///|
pub fn Path::conic_to(
  self : Path,
  control : Point,
  end : Point,
  weight : Scalar,
) -> Path {
  self.append_verb(ConicTo(control, end, weight), Some(end))
}

///|
pub fn Path::cubic_to(
  self : Path,
  control0 : Point,
  control1 : Point,
  end : Point,
) -> Path {
  self.append_verb(CubicTo(control0, control1, end), Some(end))
}

///|
pub fn Path::close(self : Path) -> Path {
  self.append_verb(Close, self.current_point)
}

///|
pub fn Path::add_rect(
  self : Path,
  rect : Rect,
  direction? : PathDirection = CW,
) -> Path {
  if direction is CW {
    self
    .move_to(Point::new(rect.left, rect.top))
    .line_to(Point::new(rect.right, rect.top))
    .line_to(Point::new(rect.right, rect.bottom))
    .line_to(Point::new(rect.left, rect.bottom))
    .close()
  } else {
    self
    .move_to(Point::new(rect.left, rect.top))
    .line_to(Point::new(rect.left, rect.bottom))
    .line_to(Point::new(rect.right, rect.bottom))
    .line_to(Point::new(rect.right, rect.top))
    .close()
  }
}

///|
pub fn Path::add_oval(
  self : Path,
  oval : Rect,
  direction? : PathDirection = CW,
) -> Path {
  let oval = oval.sorted()
  if oval.is_empty() {
    self
  } else {
    let cx = (oval.left + oval.right) / 2.0
    let cy = (oval.top + oval.bottom) / 2.0
    let right = Point::new(oval.right, cy)
    let bottom = Point::new(cx, oval.bottom)
    let left = Point::new(oval.left, cy)
    let top = Point::new(cx, oval.top)
    let weight : Scalar = 0.70710677
    if direction is CW {
      self
      .move_to(right)
      .conic_to(Point::new(oval.right, oval.bottom), bottom, weight)
      .conic_to(Point::new(oval.left, oval.bottom), left, weight)
      .conic_to(Point::new(oval.left, oval.top), top, weight)
      .conic_to(Point::new(oval.right, oval.top), right, weight)
      .close()
    } else {
      self
      .move_to(right)
      .conic_to(Point::new(oval.right, oval.top), top, weight)
      .conic_to(Point::new(oval.left, oval.top), left, weight)
      .conic_to(Point::new(oval.left, oval.bottom), bottom, weight)
      .conic_to(Point::new(oval.right, oval.bottom), right, weight)
      .close()
    }
  }
}

///|
pub fn Path::add_circle(
  self : Path,
  center : Point,
  radius : Scalar,
  direction? : PathDirection = CW,
) -> Path {
  if radius <= 0.0 {
    self
  } else {
    self.add_oval(
      Rect::new(
        center.x - radius,
        center.y - radius,
        center.x + radius,
        center.y + radius,
      ),
      direction~,
    )
  }
}

///|
pub fn Path::add_round_rect(
  self : Path,
  rect : Rect,
  rx : Scalar,
  ry : Scalar,
  direction? : PathDirection = CW,
) -> Path {
  let rect = rect.sorted()
  if rect.is_empty() {
    self
  } else if rx <= 0.0 || ry <= 0.0 {
    self.add_rect(rect, direction~)
  } else {
    let rx = Float::min(rx, rect.width() / 2.0)
    let ry = Float::min(ry, rect.height() / 2.0)
    let weight : Scalar = 0.70710677
    let top_left_start = Point::new(rect.left + rx, rect.top)
    let top_right_start = Point::new(rect.right - rx, rect.top)
    let right_top_end = Point::new(rect.right, rect.top + ry)
    let right_bottom_start = Point::new(rect.right, rect.bottom - ry)
    let bottom_right_end = Point::new(rect.right - rx, rect.bottom)
    let bottom_left_start = Point::new(rect.left + rx, rect.bottom)
    let left_bottom_end = Point::new(rect.left, rect.bottom - ry)
    let left_top_start = Point::new(rect.left, rect.top + ry)
    if direction is CW {
      self
      .move_to(top_left_start)
      .line_to(top_right_start)
      .conic_to(Point::new(rect.right, rect.top), right_top_end, weight)
      .line_to(right_bottom_start)
      .conic_to(Point::new(rect.right, rect.bottom), bottom_right_end, weight)
      .line_to(bottom_left_start)
      .conic_to(Point::new(rect.left, rect.bottom), left_bottom_end, weight)
      .line_to(left_top_start)
      .conic_to(Point::new(rect.left, rect.top), top_left_start, weight)
      .close()
    } else {
      self
      .move_to(top_left_start)
      .conic_to(Point::new(rect.left, rect.top), left_top_start, weight)
      .line_to(left_bottom_end)
      .conic_to(Point::new(rect.left, rect.bottom), bottom_left_start, weight)
      .line_to(bottom_right_end)
      .conic_to(Point::new(rect.right, rect.bottom), right_bottom_start, weight)
      .line_to(right_top_end)
      .conic_to(Point::new(rect.right, rect.top), top_right_start, weight)
      .line_to(top_left_start)
      .close()
    }
  }
}

///|
fn Size::is_rrect_square_corner(self : Size) -> Bool {
  self.width <= 0.0 || self.height <= 0.0
}

///|
fn Path::append_rrect_corner(
  self : Path,
  corner : Point,
  end : Point,
  radius : Size,
) -> Path {
  if radius.is_rrect_square_corner() {
    self.line_to(corner)
  } else {
    let weight : Scalar = 0.70710677
    self.conic_to(corner, end, weight)
  }
}

///|
pub fn Path::add_rrect(
  self : Path,
  rrect : RRect,
  direction? : PathDirection = CW,
) -> Path {
  if rrect.is_empty() {
    self
  } else if rrect.is_rect() {
    self.add_rect(rrect.rect, direction~)
  } else {
    let rect = rrect.rect
    let ul = rrect.upper_left
    let ur = rrect.upper_right
    let lr = rrect.lower_right
    let ll = rrect.lower_left
    let top_left_start = Point::new(rect.left + ul.width, rect.top)
    let top_right_start = Point::new(rect.right - ur.width, rect.top)
    let right_top_end = Point::new(rect.right, rect.top + ur.height)
    let right_bottom_start = Point::new(rect.right, rect.bottom - lr.height)
    let bottom_right_end = Point::new(rect.right - lr.width, rect.bottom)
    let bottom_left_start = Point::new(rect.left + ll.width, rect.bottom)
    let left_bottom_end = Point::new(rect.left, rect.bottom - ll.height)
    let left_top_start = Point::new(rect.left, rect.top + ul.height)
    if direction is CW {
      self
      .move_to(top_left_start)
      .line_to(top_right_start)
      .append_rrect_corner(Point::new(rect.right, rect.top), right_top_end, ur)
      .line_to(right_bottom_start)
      .append_rrect_corner(
        Point::new(rect.right, rect.bottom),
        bottom_right_end,
        lr,
      )
      .line_to(bottom_left_start)
      .append_rrect_corner(
        Point::new(rect.left, rect.bottom),
        left_bottom_end,
        ll,
      )
      .line_to(left_top_start)
      .append_rrect_corner(Point::new(rect.left, rect.top), top_left_start, ul)
      .close()
    } else {
      self
      .move_to(top_left_start)
      .append_rrect_corner(Point::new(rect.left, rect.top), left_top_start, ul)
      .line_to(left_bottom_end)
      .append_rrect_corner(
        Point::new(rect.left, rect.bottom),
        bottom_left_start,
        ll,
      )
      .line_to(bottom_right_end)
      .append_rrect_corner(
        Point::new(rect.right, rect.bottom),
        right_bottom_start,
        lr,
      )
      .line_to(right_top_end)
      .append_rrect_corner(
        Point::new(rect.right, rect.top),
        top_right_start,
        ur,
      )
      .line_to(top_left_start)
      .close()
    }
  }
}
