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
