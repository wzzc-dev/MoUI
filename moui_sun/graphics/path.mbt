///|
/// Path segment types
pub enum PathSegment {
  MoveTo(Double, Double)
  LineTo(Double, Double)
  QuadTo(Double, Double, Double, Double)
  CubicTo(Double, Double, Double, Double, Double, Double)
  Close
} derive(Eq, Debug)

///|
/// Boolean operation for supported path operands.
pub(all) enum PathBooleanOp {
  Union
  Intersection
  Difference
  Xor
} derive(Eq, Debug)

///|
/// 2D path builder for constructing vector shapes
pub struct Path {
  segments : Array[PathSegment]
  mut current_x : Double
  mut current_y : Double
  mut start_x : Double
  mut start_y : Double
} derive(Debug)

///|
priv struct PathControlBounds {
  mut has_bounds : Bool
  mut min_x : Double
  mut min_y : Double
  mut max_x : Double
  mut max_y : Double
}

///|
priv struct PathLineAppendResult {
  start_x : Double
  start_y : Double
}

///|
priv struct PolygonBoundarySegment {
  from : Point
  to : Point
}

///|
/// Create a new empty path
pub fn Path::new() -> Path {
  { segments: [], current_x: 0.0, current_y: 0.0, start_x: 0.0, start_y: 0.0 }
}

///|
/// Move to a point without drawing
pub fn Path::move_to(self : Path, x : Double, y : Double) -> Path {
  self.segments.push(PathSegment::MoveTo(x, y))
  self.current_x = x
  self.current_y = y
  self.start_x = x
  self.start_y = y
  self
}

///|
/// Draw a line to a point
pub fn Path::line_to(self : Path, x : Double, y : Double) -> Path {
  self.segments.push(PathSegment::LineTo(x, y))
  self.current_x = x
  self.current_y = y
  self
}

///|
/// Draw a quadratic bezier curve
pub fn Path::quad_to(
  self : Path,
  cx : Double,
  cy : Double,
  x : Double,
  y : Double,
) -> Path {
  self.segments.push(PathSegment::QuadTo(cx, cy, x, y))
  self.current_x = x
  self.current_y = y
  self
}

///|
/// Draw a cubic bezier curve
pub fn Path::cubic_to(
  self : Path,
  cx1 : Double,
  cy1 : Double,
  cx2 : Double,
  cy2 : Double,
  x : Double,
  y : Double,
) -> Path {
  self.segments.push(PathSegment::CubicTo(cx1, cy1, cx2, cy2, x, y))
  self.current_x = x
  self.current_y = y
  self
}

///|
/// Close the current subpath
pub fn Path::close(self : Path) -> Path {
  self.segments.push(PathSegment::Close)
  self.current_x = self.start_x
  self.current_y = self.start_y
  self
}

///|
/// Add a rectangle to the path
pub fn Path::add_rect(
  self : Path,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Path {
  ignore(self.move_to(x, y))
  ignore(self.line_to(x + w, y))
  ignore(self.line_to(x + w, y + h))
  ignore(self.line_to(x, y + h))
  self.close()
}

///|
/// Add an open polyline through the given points
pub fn Path::add_polyline(self : Path, points : Array[Point]) -> Path {
  guard points.length() > 0 else { return self }
  ignore(self.move_to(points[0].x, points[0].y))
  for i in 1..<points.length() {
    ignore(self.line_to(points[i].x, points[i].y))
  }
  self
}

///|
/// Add a closed polygon through the given points
pub fn Path::add_polygon(self : Path, points : Array[Point]) -> Path {
  guard points.length() >= 3 else { return self }
  ignore(self.add_polyline(points))
  self.close()
}

///|
/// Add a rounded rectangle with a uniform corner radius to the path
pub fn Path::add_rounded_rect(
  self : Path,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
) -> Path {
  guard w > 0.0 && h > 0.0 && radius > 0.0 else {
    return self.add_rect(x, y, w, h)
  }
  let r = radius.min(w / 2.0).min(h / 2.0)
  let k = 0.5522847498
  let kr = k * r
  let right = x + w
  let bottom = y + h

  ignore(self.move_to(x + r, y))
  ignore(self.line_to(right - r, y))
  ignore(self.cubic_to(right - r + kr, y, right, y + r - kr, right, y + r))
  ignore(self.line_to(right, bottom - r))
  ignore(
    self.cubic_to(
      right,
      bottom - r + kr,
      right - r + kr,
      bottom,
      right - r,
      bottom,
    ),
  )
  ignore(self.line_to(x + r, bottom))
  ignore(self.cubic_to(x + r - kr, bottom, x, bottom - r + kr, x, bottom - r))
  ignore(self.line_to(x, y + r))
  ignore(self.cubic_to(x, y + r - kr, x + r - kr, y, x + r, y))
  self.close()
}

///|
/// Add a rounded rectangle with independent corner radii in clockwise order.
pub fn Path::add_rounded_rect_corners(
  self : Path,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  top_left : Double,
  top_right : Double,
  bottom_right : Double,
  bottom_left : Double,
) -> Path {
  guard w > 0.0 && h > 0.0 else { return self.add_rect(x, y, w, h) }
  let tl = clamp_corner_radius(top_left, w, h)
  let tr = clamp_corner_radius(top_right, w, h)
  let br = clamp_corner_radius(bottom_right, w, h)
  let bl = clamp_corner_radius(bottom_left, w, h)
  guard tl > 0.0 || tr > 0.0 || br > 0.0 || bl > 0.0 else {
    return self.add_rect(x, y, w, h)
  }
  let k = 0.5522847498
  let right = x + w
  let bottom = y + h

  ignore(self.move_to(x + tl, y))
  ignore(self.line_to(right - tr, y))
  if tr > 0.0 {
    let kr = k * tr
    ignore(self.cubic_to(right - tr + kr, y, right, y + tr - kr, right, y + tr))
  }
  ignore(self.line_to(right, bottom - br))
  if br > 0.0 {
    let kr = k * br
    ignore(
      self.cubic_to(
        right,
        bottom - br + kr,
        right - br + kr,
        bottom,
        right - br,
        bottom,
      ),
    )
  }
  ignore(self.line_to(x + bl, bottom))
  if bl > 0.0 {
    let kr = k * bl
    ignore(
      self.cubic_to(x + bl - kr, bottom, x, bottom - bl + kr, x, bottom - bl),
    )
  }
  ignore(self.line_to(x, y + tl))
  if tl > 0.0 {
    let kr = k * tl
    ignore(self.cubic_to(x, y + tl - kr, x + tl - kr, y, x + tl, y))
  }
  self.close()
}

///|
fn clamp_corner_radius(radius : Double, w : Double, h : Double) -> Double {
  radius.max(0.0).min(w / 2.0).min(h / 2.0)
}

///|
/// Add a circle approximation using cubic bezier curves
pub fn Path::add_circle(
  self : Path,
  cx : Double,
  cy : Double,
  radius : Double,
) -> Path {
  guard radius > 0.0 else { return self }
  let k = 0.5522847498 // kappa for circle approximation
  let kr = k * radius

  ignore(self.move_to(cx + radius, cy))
  ignore(
    self.cubic_to(cx + radius, cy - kr, cx + kr, cy - radius, cx, cy - radius),
  )
  ignore(
    self.cubic_to(cx - kr, cy - radius, cx - radius, cy - kr, cx - radius, cy),
  )
  ignore(
    self.cubic_to(cx - radius, cy + kr, cx - kr, cy + radius, cx, cy + radius),
  )
  ignore(
    self.cubic_to(cx + kr, cy + radius, cx + radius, cy + kr, cx + radius, cy),
  )
  self.close()
}

///|
/// Add an ellipse approximation using cubic bezier curves
pub fn Path::add_ellipse(
  self : Path,
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
) -> Path {
  guard rx > 0.0 && ry > 0.0 else { return self }
  let k = 0.5522847498 // kappa for circle/ellipse approximation
  let kx = k * rx
  let ky = k * ry

  ignore(self.move_to(cx + rx, cy))
  ignore(self.cubic_to(cx + rx, cy - ky, cx + kx, cy - ry, cx, cy - ry))
  ignore(self.cubic_to(cx - kx, cy - ry, cx - rx, cy - ky, cx - rx, cy))
  ignore(self.cubic_to(cx - rx, cy + ky, cx - kx, cy + ry, cx, cy + ry))
  ignore(self.cubic_to(cx + kx, cy + ry, cx + rx, cy + ky, cx + rx, cy))
  self.close()
}

///|
/// Add an open circular arc approximated with cubic bezier curves.
pub fn Path::add_arc(
  self : Path,
  cx : Double,
  cy : Double,
  radius : Double,
  start_angle : Double,
  sweep_angle : Double,
) -> Path {
  let sweep = clamp_sweep_angle(sweep_angle)
  guard radius > 0.0 && start_angle == start_angle && sweep != 0.0 else {
    return self
  }
  ignore(
    self.move_to(arc_x(cx, radius, start_angle), arc_y(cy, radius, start_angle)),
  )
  append_arc_segments(self, cx, cy, radius, start_angle, sweep)
}

///|
/// Add a closed pie slice from the center through a circular arc.
pub fn Path::add_pie(
  self : Path,
  cx : Double,
  cy : Double,
  radius : Double,
  start_angle : Double,
  sweep_angle : Double,
) -> Path {
  let sweep = clamp_sweep_angle(sweep_angle)
  guard radius > 0.0 && start_angle == start_angle && sweep != 0.0 else {
    return self
  }
  ignore(self.move_to(cx, cy))
  ignore(
    self.line_to(arc_x(cx, radius, start_angle), arc_y(cy, radius, start_angle)),
  )
  ignore(append_arc_segments(self, cx, cy, radius, start_angle, sweep))
  self.close()
}

///|
fn append_arc_segments(
  path : Path,
  cx : Double,
  cy : Double,
  radius : Double,
  start_angle : Double,
  sweep_angle : Double,
) -> Path {
  let half_pi = 1.5707963267948966
  let mut remaining = sweep_angle
  let mut angle = start_angle
  while remaining != 0.0 {
    let step = if remaining > half_pi {
      half_pi
    } else if remaining < -half_pi {
      -half_pi
    } else {
      remaining
    }
    ignore(append_arc_segment(path, cx, cy, radius, angle, step))
    angle = angle + step
    remaining = remaining - step
  }
  path
}

///|
fn append_arc_segment(
  path : Path,
  cx : Double,
  cy : Double,
  radius : Double,
  start_angle : Double,
  sweep_angle : Double,
) -> Path {
  let end_angle = start_angle + sweep_angle
  let k = 4.0 / 3.0 * @math.tan(sweep_angle / 4.0)
  let cos0 = @math.cos(start_angle)
  let sin0 = @math.sin(start_angle)
  let cos1 = @math.cos(end_angle)
  let sin1 = @math.sin(end_angle)
  let x0 = cx + radius * cos0
  let y0 = cy + radius * sin0
  let x1 = cx + radius * cos1
  let y1 = cy + radius * sin1

  path.cubic_to(
    x0 - radius * k * sin0,
    y0 + radius * k * cos0,
    x1 + radius * k * sin1,
    y1 - radius * k * cos1,
    x1,
    y1,
  )
}

///|
fn arc_x(cx : Double, radius : Double, angle : Double) -> Double {
  cx + radius * @math.cos(angle)
}

///|
fn arc_y(cy : Double, radius : Double, angle : Double) -> Double {
  cy + radius * @math.sin(angle)
}

///|
fn clamp_sweep_angle(sweep : Double) -> Double {
  let two_pi = 6.283185307179586
  if sweep != sweep {
    0.0
  } else if sweep > two_pi {
    two_pi
  } else if sweep < -two_pi {
    -two_pi
  } else {
    sweep
  }
}

///|
/// Get the segments of the path
pub fn Path::get_segments(self : Path) -> Array[PathSegment] {
  copy_path_segments(self.segments)
}

///|
fn copy_path_segments(segments : Array[PathSegment]) -> Array[PathSegment] {
  let copied = []
  for segment in segments {
    copied.push(segment)
  }
  copied
}

///|
/// Return the number of path segments without exposing the segment array.
pub fn Path::segment_count(self : Path) -> Int {
  self.segments.length()
}

///|
/// Check if the path is empty
pub fn Path::is_empty(self : Path) -> Bool {
  self.segment_count() == 0
}

///|
/// Return a copy with exact no-op segments removed.
///
/// This keeps path geometry intact while coalescing consecutive moves, removing
/// zero-length line segments, removing fully degenerate curves, and dropping
/// repeated close commands and empty subpaths, including trailing open moves.
/// Explicit line-to-start segments immediately before close commands are folded
/// into the close. Curves that trace the same straight span with monotonic
/// control points are folded into line segments. Contiguous line segments that
/// keep moving along the same straight span are coalesced.
pub fn Path::simplified(self : Path) -> Path {
  let simplified = Path::new()
  let mut has_current = false
  let mut subpath_has_draw = false
  let mut current_x = 0.0
  let mut current_y = 0.0
  let mut start_x = 0.0
  let mut start_y = 0.0
  let mut can_merge_line = false
  let mut merge_start_x = 0.0
  let mut merge_start_y = 0.0

  for segment in self.segments {
    match segment {
      PathSegment::MoveTo(x, y) => {
        remove_trailing_open_move(simplified)
        ignore(simplified.move_to(x, y))
        has_current = true
        current_x = x
        current_y = y
        start_x = x
        start_y = y
        subpath_has_draw = false
        can_merge_line = false
      }
      PathSegment::LineTo(x, y) => {
        if has_current && !same_path_point(current_x, current_y, x, y) {
          let result = append_simplified_line_to(
            simplified, current_x, current_y, x, y, can_merge_line, merge_start_x,
            merge_start_y,
          )
          can_merge_line = true
          merge_start_x = result.start_x
          merge_start_y = result.start_y
          subpath_has_draw = true
        }
        current_x = x
        current_y = y
      }
      PathSegment::QuadTo(cx, cy, x, y) => {
        if has_current {
          if is_straight_quad_segment(current_x, current_y, cx, cy, x, y) {
            let result = append_simplified_line_to(
              simplified, current_x, current_y, x, y, can_merge_line, merge_start_x,
              merge_start_y,
            )
            can_merge_line = true
            merge_start_x = result.start_x
            merge_start_y = result.start_y
            subpath_has_draw = true
          } else if !(same_path_point(current_x, current_y, cx, cy) &&
            same_path_point(current_x, current_y, x, y)) {
            ignore(simplified.quad_to(cx, cy, x, y))
            can_merge_line = false
            subpath_has_draw = true
          }
        }
        current_x = x
        current_y = y
      }
      PathSegment::CubicTo(cx1, cy1, cx2, cy2, x, y) => {
        if has_current {
          if is_straight_cubic_segment(
              current_x, current_y, cx1, cy1, cx2, cy2, x, y,
            ) {
            let result = append_simplified_line_to(
              simplified, current_x, current_y, x, y, can_merge_line, merge_start_x,
              merge_start_y,
            )
            can_merge_line = true
            merge_start_x = result.start_x
            merge_start_y = result.start_y
            subpath_has_draw = true
          } else if !(same_path_point(current_x, current_y, cx1, cy1) &&
            same_path_point(current_x, current_y, cx2, cy2) &&
            same_path_point(current_x, current_y, x, y)) {
            ignore(simplified.cubic_to(cx1, cy1, cx2, cy2, x, y))
            can_merge_line = false
            subpath_has_draw = true
          }
        }
        current_x = x
        current_y = y
      }
      PathSegment::Close => {
        if has_current && !ends_with_close(simplified) {
          if !subpath_has_draw {
            remove_trailing_open_move(simplified)
          } else if same_path_point(current_x, current_y, start_x, start_y) {
            remove_trailing_line_to_point(simplified, start_x, start_y)
            ignore(simplified.close())
          } else {
            ignore(simplified.close())
          }
        }
        current_x = start_x
        current_y = start_y
        subpath_has_draw = false
        can_merge_line = false
      }
    }
  }

  if !subpath_has_draw {
    remove_trailing_open_move(simplified)
  }
  simplified
}

///|
/// Return a copy of this path with all explicit coordinates transformed.
pub fn Path::transformed(self : Path, transform : Transform) -> Path {
  let out = Path::new()
  for segment in self.segments {
    match segment {
      PathSegment::MoveTo(x, y) => {
        let (tx, ty) = transform.apply(x, y)
        ignore(out.move_to(tx, ty))
      }
      PathSegment::LineTo(x, y) => {
        let (tx, ty) = transform.apply(x, y)
        ignore(out.line_to(tx, ty))
      }
      PathSegment::QuadTo(cx, cy, x, y) => {
        let (tcx, tcy) = transform.apply(cx, cy)
        let (tx, ty) = transform.apply(x, y)
        ignore(out.quad_to(tcx, tcy, tx, ty))
      }
      PathSegment::CubicTo(cx1, cy1, cx2, cy2, x, y) => {
        let (tcx1, tcy1) = transform.apply(cx1, cy1)
        let (tcx2, tcy2) = transform.apply(cx2, cy2)
        let (tx, ty) = transform.apply(x, y)
        ignore(out.cubic_to(tcx1, tcy1, tcx2, tcy2, tx, ty))
      }
      PathSegment::Close => ignore(out.close())
    }
  }
  out
}

///|
/// Return conservative bounds over all explicit path control points.
pub fn Path::control_bounds(self : Path) -> Rect? {
  let bounds = PathControlBounds::new()
  for segment in self.segments {
    match segment {
      PathSegment::MoveTo(x, y) | PathSegment::LineTo(x, y) =>
        bounds.add_point(x, y)
      PathSegment::QuadTo(cx, cy, x, y) => {
        bounds.add_point(cx, cy)
        bounds.add_point(x, y)
      }
      PathSegment::CubicTo(cx1, cy1, cx2, cy2, x, y) => {
        bounds.add_point(cx1, cy1)
        bounds.add_point(cx2, cy2)
        bounds.add_point(x, y)
      }
      PathSegment::Close => ()
    }
  }
  bounds.to_rect()
}

///|
/// Return normalized bounds when this path is one closed axis-aligned rectangle.
pub fn Path::rect_bounds(self : Path) -> Rect? {
  match self.line_polygon_points() {
    Some(points) => rect_bounds_from_points(points)
    None => None
  }
}

///|
/// Return isolated points when this path is one simplified closed line polygon.
pub fn Path::line_polygon_points(self : Path) -> Array[Point]? {
  path_line_polygon_points(self.simplified())
}

///|
/// Return whether this path can be treated as one simplified closed line
/// polygon.
pub fn Path::is_line_polygon(self : Path) -> Bool {
  self.line_polygon_points() is Some(_)
}

///|
/// Return the signed shoelace area for one simplified closed line polygon.
pub fn Path::line_polygon_signed_area(self : Path) -> Double? {
  match self.line_polygon_points() {
    Some(points) => Some(line_polygon_signed_area(points))
    None => None
  }
}

///|
/// Return the absolute shoelace area for one simplified closed line polygon.
pub fn Path::line_polygon_area(self : Path) -> Double? {
  match self.line_polygon_signed_area() {
    Some(area) => Some(area.abs())
    None => None
  }
}

///|
/// Boolean two supported path shapes. Empty paths follow geometric identity
/// rules. Rect-like paths and single convex
/// line-polygon paths support all operations. Single axis-aligned line polygons
/// are decomposed into rectangle cells so common GUI clip shapes such as L
/// regions can also be combined. Other non-convex or curved operands are
/// currently rejected with None.
pub fn Path::boolean(self : Path, other : Path, op : PathBooleanOp) -> Path? {
  let left = self.simplified()
  let right = other.simplified()
  if path_boolean_operand_is_empty(left) {
    match op {
      PathBooleanOp::Union | PathBooleanOp::Xor => return Some(right)
      PathBooleanOp::Intersection | PathBooleanOp::Difference =>
        return Some(Path::new())
    }
  }
  if path_boolean_operand_is_empty(right) {
    match op {
      PathBooleanOp::Union | PathBooleanOp::Difference | PathBooleanOp::Xor =>
        return Some(left)
      PathBooleanOp::Intersection => return Some(Path::new())
    }
  }
  match left.rect_boolean(right, op) {
    Some(result) => Some(result)
    None =>
      match orthogonal_line_polygon_boolean_path(left, right, op) {
        Some(result) => Some(result)
        None => convex_line_polygon_boolean_path(left, right, op)
      }
  }
}

///|
/// Return the geometric union of two supported path shapes.
pub fn Path::union(self : Path, other : Path) -> Path? {
  self.boolean(other, PathBooleanOp::Union)
}

///|
/// Return the geometric intersection of two supported path shapes.
pub fn Path::intersection(self : Path, other : Path) -> Path? {
  self.boolean(other, PathBooleanOp::Intersection)
}

///|
/// Return the geometric difference of this path minus another supported shape.
pub fn Path::difference(self : Path, other : Path) -> Path? {
  self.boolean(other, PathBooleanOp::Difference)
}

///|
/// Return the geometric symmetric difference of two supported path shapes.
pub fn Path::xor(self : Path, other : Path) -> Path? {
  self.boolean(other, PathBooleanOp::Xor)
}

///|
fn path_boolean_operand_is_empty(path : Path) -> Bool {
  if path.is_empty() {
    true
  } else {
    match path.line_polygon_area() {
      Some(area) => area <= path_geometry_epsilon
      None => false
    }
  }
}

///|
/// Boolean two axis-aligned rectangle paths by decomposing them into
/// non-overlapping rectangle cells. Returns None when either operand is not a
/// single rect-like path.
pub fn Path::rect_boolean(
  self : Path,
  other : Path,
  op : PathBooleanOp,
) -> Path? {
  match self.rect_bounds() {
    Some(a) =>
      match other.rect_bounds() {
        Some(b) => Some(rect_boolean_path(a, b, op))
        None => None
      }
    None => None
  }
}

///|
fn path_line_polygon_points(path : Path) -> Array[Point]? {
  let points = []
  let mut has_move = false
  let mut closed = false
  for i in 0..<path.segments.length() {
    match path.segments[i] {
      PathSegment::MoveTo(x, y) => {
        guard !has_move && points.length() == 0 else { return None }
        points.push(Point::new(x~, y~))
        has_move = true
      }
      PathSegment::LineTo(x, y) => {
        guard has_move && !closed else { return None }
        points.push(Point::new(x~, y~))
      }
      PathSegment::Close => {
        guard has_move && i == path.segments.length() - 1 else { return None }
        closed = true
      }
      PathSegment::QuadTo(_, _, _, _)
      | PathSegment::CubicTo(_, _, _, _, _, _) => return None
    }
  }
  guard has_move && points.length() > 1 else { return None }
  let first = points[0]
  let last = points[points.length() - 1]
  let has_explicit_close = same_path_point(first.x, first.y, last.x, last.y)
  guard closed || has_explicit_close else { return None }
  if has_explicit_close {
    ignore(points.remove(points.length() - 1))
  }
  Some(points)
}

///|
fn line_polygon_signed_area(points : Array[Point]) -> Double {
  guard points.length() > 1 else { return 0.0 }
  let mut twice_area = 0.0
  for i in 0..<points.length() {
    let current = points[i]
    let next = points[(i + 1) % points.length()]
    twice_area = twice_area + current.x * next.y - current.y * next.x
  }
  twice_area / 2.0
}

///|
fn convex_line_polygon_boolean_path(
  a : Path,
  b : Path,
  op : PathBooleanOp,
) -> Path? {
  match a.line_polygon_points() {
    Some(subject) =>
      match b.line_polygon_points() {
        Some(clip) => {
          guard is_convex_line_polygon_points(subject) &&
            is_convex_line_polygon_points(clip) else {
            return None
          }
          let subject = counter_clockwise_polygon_points(subject)
          let clip = counter_clockwise_polygon_points(clip)
          match op {
            PathBooleanOp::Intersection =>
              Some(
                path_from_optional_polygon_points(
                  clip_polygon_by_convex_polygon(subject, clip),
                ),
              )
            PathBooleanOp::Difference =>
              Some(
                path_from_polygon_fragments(
                  convex_polygon_boundary_boolean_fragments(subject, clip, op),
                ),
              )
            PathBooleanOp::Xor =>
              Some(
                path_from_polygon_fragments(
                  convex_polygon_boundary_boolean_fragments(subject, clip, op),
                ),
              )
            PathBooleanOp::Union =>
              Some(
                path_from_polygon_fragments(
                  convex_polygon_boundary_boolean_fragments(subject, clip, op),
                ),
              )
          }
        }
        None => None
      }
    None => None
  }
}

///|
fn orthogonal_line_polygon_boolean_path(
  a : Path,
  b : Path,
  op : PathBooleanOp,
) -> Path? {
  match a.line_polygon_points() {
    Some(subject) =>
      match b.line_polygon_points() {
        Some(clip) => {
          guard is_orthogonal_line_polygon_points(subject) &&
            is_orthogonal_line_polygon_points(clip) else {
            return None
          }
          Some(orthogonal_polygon_boolean_path(subject, clip, op))
        }
        None => None
      }
    None => None
  }
}

///|
fn orthogonal_polygon_boolean_path(
  subject : Array[Point],
  clip : Array[Point],
  op : PathBooleanOp,
) -> Path {
  let xs = []
  let ys = []
  push_polygon_grid_coordinates(xs, ys, subject)
  push_polygon_grid_coordinates(xs, ys, clip)

  let cells = []
  for yi in 0..<(ys.length() - 1) {
    let mut current : Rect? = None
    for xi in 0..<(xs.length() - 1) {
      let cell = Rect::new(
        x=xs[xi],
        y=ys[yi],
        width=xs[xi + 1] - xs[xi],
        height=ys[yi + 1] - ys[yi],
      )
      if orthogonal_boolean_keeps_cell(subject, clip, cell, op) {
        match current {
          Some(rect) =>
            if rect_boolean_cells_are_row_adjacent(rect, cell) {
              current = Some(
                Rect::new(
                  x=rect.x,
                  y=rect.y,
                  width=rect.width + cell.width,
                  height=rect.height,
                ),
              )
            } else {
              cells.push(rect)
              current = Some(cell)
            }
          None => current = Some(cell)
        }
      }
    }
    match current {
      Some(rect) => cells.push(rect)
      None => ()
    }
  }

  path_from_merged_rect_cells(cells)
}

///|
fn push_polygon_grid_coordinates(
  xs : Array[Double],
  ys : Array[Double],
  points : Array[Point],
) -> Unit {
  for point in points {
    push_sorted_unique_double(xs, point.x)
    push_sorted_unique_double(ys, point.y)
  }
}

///|
fn orthogonal_boolean_keeps_cell(
  subject : Array[Point],
  clip : Array[Point],
  cell : Rect,
  op : PathBooleanOp,
) -> Bool {
  guard !cell.is_empty() else { return false }
  let center = Point::new(
    x=cell.x + cell.width / 2.0,
    y=cell.y + cell.height / 2.0,
  )
  let in_subject = point_inside_line_polygon_points(center, subject)
  let in_clip = point_inside_line_polygon_points(center, clip)
  match op {
    PathBooleanOp::Union => in_subject || in_clip
    PathBooleanOp::Intersection => in_subject && in_clip
    PathBooleanOp::Difference => in_subject && !in_clip
    PathBooleanOp::Xor => in_subject != in_clip
  }
}

///|
fn clip_polygon_by_convex_polygon(
  subject : Array[Point],
  clip : Array[Point],
) -> Array[Point] {
  let mut output = copy_points(subject)
  let clip_area = line_polygon_signed_area(clip)
  for i in 0..<clip.length() {
    guard output.length() > 0 else { return output }
    output = clip_polygon_by_half_plane(
      output,
      clip[i],
      clip[(i + 1) % clip.length()],
      clip_area,
      keep_inside=true,
    )
  }
  output
}

///|
fn convex_polygon_boundary_boolean_fragments(
  subject : Array[Point],
  clip : Array[Point],
  op : PathBooleanOp,
) -> Array[Array[Point]] {
  let segments : Array[PolygonBoundarySegment] = []
  match op {
    PathBooleanOp::Union => {
      append_union_boundary_segments(
        segments,
        subject,
        clip,
        keep_same_direction_boundary=true,
      )
      append_union_boundary_segments(
        segments,
        clip,
        subject,
        keep_same_direction_boundary=false,
      )
    }
    PathBooleanOp::Difference => {
      append_difference_subject_boundary_segments(segments, subject, clip)
      append_difference_clip_boundary_segments(segments, clip, subject)
    }
    PathBooleanOp::Xor => {
      append_difference_subject_boundary_segments(segments, subject, clip)
      append_difference_clip_boundary_segments(segments, clip, subject)
      append_difference_subject_boundary_segments(segments, clip, subject)
      append_difference_clip_boundary_segments(segments, subject, clip)
    }
    PathBooleanOp::Intersection => ()
  }
  trace_polygon_boundary_segments(segments)
}

///|
fn append_union_boundary_segments(
  out : Array[PolygonBoundarySegment],
  polygon : Array[Point],
  other : Array[Point],
  keep_same_direction_boundary~ : Bool,
) -> Unit {
  append_polygon_boundary_segments(out, polygon, other, reverse=false, keep_segment=fn(
    from,
    to,
    midpoint,
  ) {
    union_boundary_segment_kept(
      from, to, midpoint, other, keep_same_direction_boundary,
    )
  })
}

///|
fn append_difference_subject_boundary_segments(
  out : Array[PolygonBoundarySegment],
  subject : Array[Point],
  clip : Array[Point],
) -> Unit {
  append_polygon_boundary_segments(out, subject, clip, reverse=false, keep_segment=fn(
    _from,
    _to,
    point,
  ) {
    !point_inside_convex_polygon(point, clip, include_boundary=true)
  })
}

///|
fn append_difference_clip_boundary_segments(
  out : Array[PolygonBoundarySegment],
  clip : Array[Point],
  subject : Array[Point],
) -> Unit {
  append_polygon_boundary_segments(out, clip, subject, reverse=true, keep_segment=fn(
    _from,
    _to,
    point,
  ) {
    point_inside_convex_polygon(point, subject, include_boundary=false)
  })
}

///|
fn append_polygon_boundary_segments(
  out : Array[PolygonBoundarySegment],
  polygon : Array[Point],
  other : Array[Point],
  reverse~ : Bool,
  keep_segment~ : (Point, Point, Point) -> Bool,
) -> Unit {
  for i in 0..<polygon.length() {
    let start = polygon[i]
    let end = polygon[(i + 1) % polygon.length()]
    let cuts = [0.0, 1.0]
    for j in 0..<other.length() {
      push_boundary_edge_cut_parameters(
        cuts,
        start,
        end,
        other[j],
        other[(j + 1) % other.length()],
      )
    }
    for cut_index in 0..<(cuts.length() - 1) {
      let t0 = cuts[cut_index]
      let t1 = cuts[cut_index + 1]
      if t1 - t0 > path_geometry_epsilon {
        let from = interpolate_points(start, end, t0)
        let to = interpolate_points(start, end, t1)
        let midpoint = interpolate_points(start, end, (t0 + t1) / 2.0)
        if keep_segment(from, to, midpoint) {
          push_polygon_boundary_segment(out, from, to, reverse)
        }
      }
    }
  }
}

///|
fn union_boundary_segment_kept(
  from : Point,
  to : Point,
  midpoint : Point,
  other : Array[Point],
  keep_same_direction_boundary : Bool,
) -> Bool {
  if point_inside_convex_polygon(midpoint, other, include_boundary=false) {
    false
  } else if !point_inside_convex_polygon(midpoint, other, include_boundary=true) {
    true
  } else {
    keep_same_direction_boundary &&
    coincident_boundary_direction(from, to, other) > 0
  }
}

///|
fn coincident_boundary_direction(
  from : Point,
  to : Point,
  polygon : Array[Point],
) -> Int {
  for i in 0..<polygon.length() {
    let edge_start = polygon[i]
    let edge_end = polygon[(i + 1) % polygon.length()]
    if point_on_segment_with_epsilon(edge_start, edge_end, from) &&
      point_on_segment_with_epsilon(edge_start, edge_end, to) {
      let dot = (to.x - from.x) * (edge_end.x - edge_start.x) +
        (to.y - from.y) * (edge_end.y - edge_start.y)
      if dot > path_geometry_epsilon {
        return 1
      } else if dot < -path_geometry_epsilon {
        return -1
      }
    }
  }
  0
}

///|
fn push_boundary_edge_cut_parameters(
  cuts : Array[Double],
  a0 : Point,
  a1 : Point,
  b0 : Point,
  b1 : Point,
) -> Unit {
  let ax = a1.x - a0.x
  let ay = a1.y - a0.y
  let bx = b1.x - b0.x
  let by = b1.y - b0.y
  let denominator = ax * by - ay * bx
  if denominator.abs() > path_geometry_epsilon {
    let dx = b0.x - a0.x
    let dy = b0.y - a0.y
    let t = (dx * by - dy * bx) / denominator
    let u = (dx * ay - dy * ax) / denominator
    if t >= -path_geometry_epsilon &&
      t <= 1.0 + path_geometry_epsilon &&
      u >= -path_geometry_epsilon &&
      u <= 1.0 + path_geometry_epsilon {
      push_sorted_unique_parameter(cuts, clamp_unit_parameter(t))
    }
  } else if cross_points(a0, a1, b0).abs() <= path_geometry_epsilon &&
    cross_points(a0, a1, b1).abs() <= path_geometry_epsilon {
    push_point_cut_parameter(cuts, a0, a1, b0)
    push_point_cut_parameter(cuts, a0, a1, b1)
  }
}

///|
fn push_point_cut_parameter(
  cuts : Array[Double],
  a0 : Point,
  a1 : Point,
  point : Point,
) -> Unit {
  guard point_on_segment_with_epsilon(a0, a1, point) else { return }
  let dx = a1.x - a0.x
  let dy = a1.y - a0.y
  let t = if dx.abs() >= dy.abs() {
    guard dx.abs() > path_geometry_epsilon else { return }
    (point.x - a0.x) / dx
  } else {
    guard dy.abs() > path_geometry_epsilon else { return }
    (point.y - a0.y) / dy
  }
  push_sorted_unique_parameter(cuts, clamp_unit_parameter(t))
}

///|
fn push_sorted_unique_parameter(values : Array[Double], value : Double) -> Unit {
  let mut index = 0
  while index < values.length() && values[index] < value - path_geometry_epsilon {
    index = index + 1
  }
  guard index >= values.length() ||
    (values[index] - value).abs() > path_geometry_epsilon else {
    return
  }
  let tail = []
  while values.length() > index {
    tail.push(values.remove(index))
  }
  values.push(value)
  for item in tail {
    values.push(item)
  }
}

///|
fn clamp_unit_parameter(value : Double) -> Double {
  value.max(0.0).min(1.0)
}

///|
fn point_on_segment_with_epsilon(a : Point, b : Point, point : Point) -> Bool {
  guard cross_points(a, b, point).abs() <= path_geometry_epsilon else {
    return false
  }
  point.x >= a.x.min(b.x) - path_geometry_epsilon &&
  point.x <= a.x.max(b.x) + path_geometry_epsilon &&
  point.y >= a.y.min(b.y) - path_geometry_epsilon &&
  point.y <= a.y.max(b.y) + path_geometry_epsilon
}

///|
fn interpolate_points(a : Point, b : Point, t : Double) -> Point {
  Point::new(x=a.x + (b.x - a.x) * t, y=a.y + (b.y - a.y) * t)
}

///|
fn push_polygon_boundary_segment(
  out : Array[PolygonBoundarySegment],
  from : Point,
  to : Point,
  reverse : Bool,
) -> Unit {
  guard !same_polygon_point(from, to) else { return }
  if reverse {
    out.push({ from: to, to: from })
  } else {
    out.push({ from, to })
  }
}

///|
fn trace_polygon_boundary_segments(
  segments : Array[PolygonBoundarySegment],
) -> Array[Array[Point]] {
  let loops = []
  while segments.length() > 0 {
    let first = segments.remove(0)
    let points = [first.from, first.to]
    let start = first.from
    let mut current = first.to
    let mut closed = same_polygon_point(current, start)
    let mut remaining_steps = segments.length() + 1
    while !closed && remaining_steps > 0 {
      let next_index = find_next_polygon_boundary_segment(segments, current)
      if next_index < 0 {
        remaining_steps = 0
      } else {
        let next = segments.remove(next_index)
        current = next.to
        points.push(current)
        closed = same_polygon_point(current, start)
        remaining_steps = remaining_steps - 1
      }
    }
    if closed {
      ignore(points.remove(points.length() - 1))
      match clean_polygon_fragment(points) {
        Some(boundary_loop) => loops.push(boundary_loop)
        None => ()
      }
    }
  }
  loops
}

///|
fn find_next_polygon_boundary_segment(
  segments : Array[PolygonBoundarySegment],
  point : Point,
) -> Int {
  for i in 0..<segments.length() {
    if same_polygon_point(segments[i].from, point) {
      return i
    }
  }
  -1
}

///|
fn point_inside_convex_polygon(
  point : Point,
  polygon : Array[Point],
  include_boundary~ : Bool,
) -> Bool {
  for i in 0..<polygon.length() {
    let cross = cross_points(
      polygon[i],
      polygon[(i + 1) % polygon.length()],
      point,
    )
    if include_boundary {
      guard cross >= -path_geometry_epsilon else { return false }
    } else {
      guard cross > path_geometry_epsilon else { return false }
    }
  }
  true
}

///|
fn counter_clockwise_polygon_points(points : Array[Point]) -> Array[Point] {
  if line_polygon_signed_area(points) >= 0.0 {
    copy_points(points)
  } else {
    reverse_polygon_points(points)
  }
}

///|
fn reverse_polygon_points(points : Array[Point]) -> Array[Point] {
  let reversed = []
  for i in 0..<points.length() {
    reversed.push(points[points.length() - 1 - i])
  }
  reversed
}

///|
fn clip_polygon_by_half_plane(
  polygon : Array[Point],
  clip_start : Point,
  clip_end : Point,
  clip_area : Double,
  keep_inside~ : Bool,
) -> Array[Point] {
  guard polygon.length() > 0 else { return [] }
  let output = []
  let mut previous = polygon[polygon.length() - 1]
  let mut previous_kept = point_matches_clip_side(
    previous, clip_start, clip_end, clip_area, keep_inside,
  )
  for current in polygon {
    let current_kept = point_matches_clip_side(
      current, clip_start, clip_end, clip_area, keep_inside,
    )
    if current_kept {
      if !previous_kept {
        output.push(
          line_segment_intersection(previous, current, clip_start, clip_end),
        )
      }
      output.push(current)
    } else if previous_kept {
      output.push(
        line_segment_intersection(previous, current, clip_start, clip_end),
      )
    }
    previous = current
    previous_kept = current_kept
  }
  normalize_polygon_points(output)
}

///|
fn point_matches_clip_side(
  point : Point,
  edge_start : Point,
  edge_end : Point,
  clip_area : Double,
  keep_inside : Bool,
) -> Bool {
  let inside = point_inside_clip_edge(point, edge_start, edge_end, clip_area)
  if keep_inside {
    inside
  } else {
    !inside
  }
}

///|
fn point_inside_clip_edge(
  point : Point,
  edge_start : Point,
  edge_end : Point,
  clip_area : Double,
) -> Bool {
  let cross = cross_points(edge_start, edge_end, point)
  if clip_area >= 0.0 {
    cross >= -path_geometry_epsilon
  } else {
    cross <= path_geometry_epsilon
  }
}

///|
fn line_segment_intersection(
  a0 : Point,
  a1 : Point,
  b0 : Point,
  b1 : Point,
) -> Point {
  let ax = a1.x - a0.x
  let ay = a1.y - a0.y
  let bx = b1.x - b0.x
  let by = b1.y - b0.y
  let denominator = ax * by - ay * bx
  guard denominator.abs() > path_geometry_epsilon else { return a1 }
  let dx = b0.x - a0.x
  let dy = b0.y - a0.y
  let t = (dx * by - dy * bx) / denominator
  Point::new(x=a0.x + ax * t, y=a0.y + ay * t)
}

///|
fn is_convex_line_polygon_points(points : Array[Point]) -> Bool {
  guard points.length() >= 3 else { return false }
  let area = line_polygon_signed_area(points)
  guard area.abs() > path_geometry_epsilon else { return false }
  for i in 0..<points.length() {
    let turn = cross_points(
      points[i],
      points[(i + 1) % points.length()],
      points[(i + 2) % points.length()],
    )
    if turn.abs() > path_geometry_epsilon &&
      turn * area < -path_geometry_epsilon {
      return false
    }
  }
  true
}

///|
fn is_orthogonal_line_polygon_points(points : Array[Point]) -> Bool {
  guard points.length() >= 3 else { return false }
  guard line_polygon_signed_area(points).abs() > path_geometry_epsilon else {
    return false
  }
  for i in 0..<points.length() {
    let a = points[i]
    let b = points[(i + 1) % points.length()]
    guard is_axis_aligned_non_empty_edge(a, b) else { return false }
  }
  true
}

///|
fn point_inside_line_polygon_points(
  point : Point,
  polygon : Array[Point],
) -> Bool {
  let mut inside = false
  for i in 0..<polygon.length() {
    let a = polygon[i]
    let b = polygon[(i + 1) % polygon.length()]
    if (a.y > point.y) != (b.y > point.y) {
      let crossing_x = a.x + (point.y - a.y) * (b.x - a.x) / (b.y - a.y)
      if point.x < crossing_x {
        inside = !inside
      }
    }
  }
  inside
}

///|
fn cross_points(a : Point, b : Point, c : Point) -> Double {
  (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
}

///|
fn normalize_polygon_points(points : Array[Point]) -> Array[Point] {
  let normalized = []
  for point in points {
    if normalized.length() == 0 ||
      !same_polygon_point(normalized[normalized.length() - 1], point) {
      normalized.push(point)
    }
  }
  if normalized.length() > 1 &&
    same_polygon_point(normalized[0], normalized[normalized.length() - 1]) {
    ignore(normalized.remove(normalized.length() - 1))
  }
  normalized
}

///|
fn same_polygon_point(a : Point, b : Point) -> Bool {
  (a.x - b.x).abs() <= path_geometry_epsilon &&
  (a.y - b.y).abs() <= path_geometry_epsilon
}

///|
fn copy_points(points : Array[Point]) -> Array[Point] {
  let copied = []
  for point in points {
    copied.push(point)
  }
  copied
}

///|
fn path_from_polygon_points(points : Array[Point]) -> Path {
  guard points.length() > 0 else { return Path::new() }
  let path = Path::new().move_to(points[0].x, points[0].y)
  for i in 1..<points.length() {
    ignore(path.line_to(points[i].x, points[i].y))
  }
  path.close()
}

///|
fn path_from_optional_polygon_points(points : Array[Point]) -> Path {
  match clean_polygon_fragment(points) {
    Some(fragment) => path_from_polygon_points(fragment)
    None => Path::new()
  }
}

///|
fn path_from_polygon_fragments(fragments : Array[Array[Point]]) -> Path {
  let path = Path::new()
  for fragment in fragments {
    match clean_polygon_fragment(fragment) {
      Some(points) => append_polygon_points(path, points)
      None => ()
    }
  }
  path
}

///|
fn append_polygon_points(path : Path, points : Array[Point]) -> Unit {
  guard points.length() > 0 else { return }
  ignore(path.move_to(points[0].x, points[0].y))
  for i in 1..<points.length() {
    ignore(path.line_to(points[i].x, points[i].y))
  }
  ignore(path.close())
}

///|
fn clean_polygon_fragment(points : Array[Point]) -> Array[Point]? {
  let normalized = normalize_polygon_points(points)
  guard normalized.length() >= 3 else { return None }
  guard line_polygon_signed_area(normalized).abs() > path_geometry_epsilon else {
    return None
  }
  Some(normalized)
}

///|
let path_geometry_epsilon = 0.000000001

///|
fn rect_boolean_path(a : Rect, b : Rect, op : PathBooleanOp) -> Path {
  let xs = []
  let ys = []
  push_sorted_unique_double(xs, a.x)
  push_sorted_unique_double(xs, a.right())
  push_sorted_unique_double(xs, b.x)
  push_sorted_unique_double(xs, b.right())
  push_sorted_unique_double(ys, a.y)
  push_sorted_unique_double(ys, a.bottom())
  push_sorted_unique_double(ys, b.y)
  push_sorted_unique_double(ys, b.bottom())

  let cells = []
  for yi in 0..<(ys.length() - 1) {
    let mut current : Rect? = None
    for xi in 0..<(xs.length() - 1) {
      let cell = Rect::new(
        x=xs[xi],
        y=ys[yi],
        width=xs[xi + 1] - xs[xi],
        height=ys[yi + 1] - ys[yi],
      )
      if rect_boolean_keeps_cell(a, b, cell, op) {
        match current {
          Some(rect) =>
            if rect_boolean_cells_are_row_adjacent(rect, cell) {
              current = Some(
                Rect::new(
                  x=rect.x,
                  y=rect.y,
                  width=rect.width + cell.width,
                  height=rect.height,
                ),
              )
            } else {
              cells.push(rect)
              current = Some(cell)
            }
          None => current = Some(cell)
        }
      }
    }
    match current {
      Some(rect) => cells.push(rect)
      None => ()
    }
  }

  let out = Path::new()
  append_merged_rect_cells(out, cells)
  out
}

///|
fn path_from_merged_rect_cells(cells : Array[Rect]) -> Path {
  let path = Path::new()
  append_merged_rect_cells(path, cells)
  path
}

///|
fn append_merged_rect_cells(path : Path, cells : Array[Rect]) -> Unit {
  for rect in merge_rect_boolean_column_cells(cells) {
    ignore(path.add_rect(rect.x, rect.y, rect.width, rect.height))
  }
}

///|
fn rect_boolean_cells_are_row_adjacent(left : Rect, right : Rect) -> Bool {
  same_rect_boolean_edge(left.right(), right.x) &&
  same_rect_boolean_edge(left.y, right.y) &&
  same_rect_boolean_edge(left.height, right.height)
}

///|
fn merge_rect_boolean_column_cells(cells : Array[Rect]) -> Array[Rect] {
  let merged : Array[Rect] = []
  for cell in cells {
    let mut merged_index = -1
    for i in 0..<merged.length() {
      let existing = merged[i]
      if same_rect_boolean_edge(existing.x, cell.x) &&
        same_rect_boolean_edge(existing.width, cell.width) &&
        same_rect_boolean_edge(existing.bottom(), cell.y) {
        merged_index = i
      }
    }
    if merged_index >= 0 {
      let existing = merged[merged_index]
      merged[merged_index] = Rect::new(
        x=existing.x,
        y=existing.y,
        width=existing.width,
        height=existing.height + cell.height,
      )
    } else {
      merged.push(cell)
    }
  }
  merged
}

///|
fn same_rect_boolean_edge(a : Double, b : Double) -> Bool {
  (a - b).abs() <= path_geometry_epsilon
}

///|
fn rect_boolean_keeps_cell(
  a : Rect,
  b : Rect,
  cell : Rect,
  op : PathBooleanOp,
) -> Bool {
  guard !cell.is_empty() else { return false }
  let center_x = cell.x + cell.width / 2.0
  let center_y = cell.y + cell.height / 2.0
  let in_a = a.contains(center_x, center_y)
  let in_b = b.contains(center_x, center_y)
  match op {
    PathBooleanOp::Union => in_a || in_b
    PathBooleanOp::Intersection => in_a && in_b
    PathBooleanOp::Difference => in_a && !in_b
    PathBooleanOp::Xor => in_a != in_b
  }
}

///|
fn push_sorted_unique_double(values : Array[Double], value : Double) -> Unit {
  let mut index = 0
  while index < values.length() && values[index] < value {
    index = index + 1
  }
  guard index >= values.length() || values[index] != value else { return }
  let tail = []
  while values.length() > index {
    tail.push(values.remove(index))
  }
  values.push(value)
  for item in tail {
    values.push(item)
  }
}

///|
fn rect_bounds_from_points(points : Array[Point]) -> Rect? {
  guard points.length() == 4 else { return None }
  guard points_are_axis_aligned_closed(points) else { return None }
  let rect = point_array_bounds(points)
  guard !rect.is_empty() else { return None }
  for point in points {
    guard point_is_rect_corner(point, rect) else { return None }
  }
  Some(rect)
}

///|
fn points_are_axis_aligned_closed(points : Array[Point]) -> Bool {
  for i in 0..<points.length() {
    let a = points[i]
    let b = points[(i + 1) % points.length()]
    guard is_axis_aligned_non_empty_edge(a, b) else { return false }
  }
  true
}

///|
fn is_axis_aligned_non_empty_edge(a : Point, b : Point) -> Bool {
  (a.x == b.x && a.y != b.y) || (a.y == b.y && a.x != b.x)
}

///|
fn point_array_bounds(points : Array[Point]) -> Rect {
  let first = points[0]
  let mut min_x = first.x
  let mut min_y = first.y
  let mut max_x = first.x
  let mut max_y = first.y
  for point in points {
    min_x = min_x.min(point.x)
    min_y = min_y.min(point.y)
    max_x = max_x.max(point.x)
    max_y = max_y.max(point.y)
  }
  Rect::new(x=min_x, y=min_y, width=max_x - min_x, height=max_y - min_y)
}

///|
fn point_is_rect_corner(point : Point, rect : Rect) -> Bool {
  (point.x == rect.x || point.x == rect.right()) &&
  (point.y == rect.y || point.y == rect.bottom())
}

///|
fn append_simplified_line_to(
  path : Path,
  line_start_x : Double,
  line_start_y : Double,
  x : Double,
  y : Double,
  can_merge_line : Bool,
  merge_start_x : Double,
  merge_start_y : Double,
) -> PathLineAppendResult {
  if can_merge_line &&
    is_point_on_line_segment(
      merge_start_x, merge_start_y, x, y, line_start_x, line_start_y,
    ) {
    replace_trailing_line_to(path, x, y)
    { start_x: merge_start_x, start_y: merge_start_y }
  } else {
    ignore(path.line_to(x, y))
    { start_x: line_start_x, start_y: line_start_y }
  }
}

///|
fn same_path_point(x0 : Double, y0 : Double, x1 : Double, y1 : Double) -> Bool {
  x0 == x1 && y0 == y1
}

///|
fn is_straight_quad_segment(
  x0 : Double,
  y0 : Double,
  cx : Double,
  cy : Double,
  x1 : Double,
  y1 : Double,
) -> Bool {
  !same_path_point(x0, y0, x1, y1) &&
  is_point_on_line_segment(x0, y0, x1, y1, cx, cy)
}

///|
fn is_straight_cubic_segment(
  x0 : Double,
  y0 : Double,
  cx1 : Double,
  cy1 : Double,
  cx2 : Double,
  cy2 : Double,
  x1 : Double,
  y1 : Double,
) -> Bool {
  guard !same_path_point(x0, y0, x1, y1) else { return false }
  guard is_point_on_line_segment(x0, y0, x1, y1, cx1, cy1) else { return false }
  guard is_point_on_line_segment(x0, y0, x1, y1, cx2, cy2) else { return false }
  path_projection_numerator(x0, y0, x1, y1, cx1, cy1) <=
  path_projection_numerator(x0, y0, x1, y1, cx2, cy2)
}

///|
fn is_point_on_line_segment(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  px : Double,
  py : Double,
) -> Bool {
  let dx = x1 - x0
  let dy = y1 - y0
  let len_sq = dx * dx + dy * dy
  guard len_sq > 0.0 else { return same_path_point(x0, y0, px, py) }
  let rel_x = px - x0
  let rel_y = py - y0
  guard rel_x * dy - rel_y * dx == 0.0 else { return false }
  let projection = rel_x * dx + rel_y * dy
  projection >= 0.0 && projection <= len_sq
}

///|
fn path_projection_numerator(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  px : Double,
  py : Double,
) -> Double {
  let dx = x1 - x0
  let dy = y1 - y0
  (px - x0) * dx + (py - y0) * dy
}

///|
fn remove_trailing_open_move(path : Path) -> Unit {
  let length = path.segments.length()
  guard length > 0 else { return }
  match path.segments[length - 1] {
    PathSegment::MoveTo(_, _) => ignore(path.segments.remove(length - 1))
    _ => ()
  }
}

///|
fn replace_trailing_line_to(path : Path, x : Double, y : Double) -> Unit {
  let length = path.segments.length()
  guard length > 0 else { return }
  match path.segments[length - 1] {
    PathSegment::LineTo(_, _) => {
      ignore(path.segments.remove(length - 1))
      ignore(path.line_to(x, y))
    }
    _ => ignore(path.line_to(x, y))
  }
}

///|
fn remove_trailing_line_to_point(path : Path, x : Double, y : Double) -> Unit {
  let length = path.segments.length()
  guard length > 0 else { return }
  match path.segments[length - 1] {
    PathSegment::LineTo(line_x, line_y) =>
      if same_path_point(line_x, line_y, x, y) {
        ignore(path.segments.remove(length - 1))
      }
    _ => ()
  }
}

///|
fn ends_with_close(path : Path) -> Bool {
  let length = path.segments.length()
  guard length > 0 else { return false }
  path.segments[length - 1] is PathSegment::Close
}

///|
/// Return whether a point is inside this path under the given fill rule.
pub fn Path::contains_point(
  self : Path,
  x : Double,
  y : Double,
  fill_rule : FillRule,
) -> Bool {
  guard !self.is_empty() else { return false }
  let edges = path_to_edges(self, Transform::identity())
  guard edges.length() > 0 else { return false }
  is_point_in_edges(x, y, edges, fill_rule)
}

///|
fn PathControlBounds::new() -> PathControlBounds {
  { has_bounds: false, min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 }
}

///|
fn PathControlBounds::add_point(
  self : PathControlBounds,
  x : Double,
  y : Double,
) -> Unit {
  if self.has_bounds {
    self.min_x = self.min_x.min(x)
    self.min_y = self.min_y.min(y)
    self.max_x = self.max_x.max(x)
    self.max_y = self.max_y.max(y)
  } else {
    self.has_bounds = true
    self.min_x = x
    self.min_y = y
    self.max_x = x
    self.max_y = y
  }
}

///|
fn PathControlBounds::to_rect(self : PathControlBounds) -> Rect? {
  guard self.has_bounds else { return None }
  Some(
    Rect::new(
      x=self.min_x,
      y=self.min_y,
      width=self.max_x - self.min_x,
      height=self.max_y - self.min_y,
    ),
  )
}
