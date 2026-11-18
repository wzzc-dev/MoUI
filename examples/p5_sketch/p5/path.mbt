///|
/// Renderer-neutral path builder. Every backend receives the same verbs; the
/// MoUI adapter converts them to `DrawCommand::DrawPath`.

///|
#derive(Eq)
pub(all) enum PathCmd {
  MoveTo(Double, Double)
  LineTo(Double, Double)
  QuadTo(Double, Double, Double, Double)
  CubicTo(Double, Double, Double, Double, Double, Double)
  Close
}

///|
pub(all) struct Path {
  commands : Array[PathCmd]
}

///|
/// How `arc` connects its endpoints.
#derive(Eq)
pub(all) enum ArcMode {
  Open
  Chord
  Pie
}

///|
/// The anchor mode used by `rect` and `ellipse`.
#derive(Eq)
pub(all) enum ShapeMode {
  Corner
  Corners
  Center
  Radius
}

///|
pub fn Path::new() -> Path {
  { commands: [], }
}

///|
pub fn Path::commands(self : Path) -> Array[PathCmd] {
  self.commands
}

///|
pub fn Path::copy(self : Path) -> Path {
  { commands: self.commands.copy(), }
}

///|
pub fn Path::move_to(self : Path, x : Double, y : Double) -> Unit {
  self.commands.push(MoveTo(x, y))
}

///|
pub fn Path::line_to(self : Path, x : Double, y : Double) -> Unit {
  self.commands.push(LineTo(x, y))
}

///|
pub fn Path::quad_to(
  self : Path,
  cx : Double,
  cy : Double,
  x : Double,
  y : Double,
) -> Unit {
  self.commands.push(QuadTo(cx, cy, x, y))
}

///|
pub fn Path::cubic_to(
  self : Path,
  c1x : Double,
  c1y : Double,
  c2x : Double,
  c2y : Double,
  x : Double,
  y : Double,
) -> Unit {
  self.commands.push(CubicTo(c1x, c1y, c2x, c2y, x, y))
}

///|
pub fn Path::close(self : Path) -> Unit {
  self.commands.push(Close)
}

///|
pub fn Path::is_empty_path(self : Path) -> Bool {
  self.commands.is_empty()
}

///|
pub fn Path::polygon(self : Path, points : ArrayView[(Double, Double)]) -> Unit {
  if points.length() == 0 {
    return
  }
  self.move_to(points[0].0, points[0].1)
  for index in 1..<points.length() {
    self.line_to(points[index].0, points[index].1)
  }
  self.close()
}

///|
fn kappa() -> Double {
  0.5522847498307936
}

///|
/// Appends an axis-aligned ellipse as four cubic segments.
pub fn Path::ellipse_at(
  self : Path,
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
) -> Unit {
  let k = kappa()
  self.move_to(cx + rx, cy)
  self.cubic_to(cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry)
  self.cubic_to(cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy)
  self.cubic_to(cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry)
  self.cubic_to(cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy)
  self.close()
}

///|
/// Appends a rectangle in corner coordinates.
pub fn Path::rect_at(
  self : Path,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  self.move_to(x, y)
  self.line_to(x + width, y)
  self.line_to(x + width, y + height)
  self.line_to(x, y + height)
  self.close()
}

///|
/// Appends a rectangle with independent corner radii.
pub fn Path::rounded_rect_at(
  self : Path,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  tl : Double,
  tr : Double,
  br : Double,
  bl : Double,
) -> Unit {
  let maximum = width.min(height) / 2.0
  let tl = constrain(tl, 0.0, maximum)
  let tr = constrain(tr, 0.0, maximum)
  let br = constrain(br, 0.0, maximum)
  let bl = constrain(bl, 0.0, maximum)
  let k = kappa()
  self.move_to(x + tl, y)
  self.line_to(x + width - tr, y)
  if tr > 0.0 {
    self.cubic_to(
      x + width - tr + tr * k,
      y,
      x + width,
      y + tr - tr * k,
      x + width,
      y + tr,
    )
  }
  self.line_to(x + width, y + height - br)
  if br > 0.0 {
    self.cubic_to(
      x + width,
      y + height - br + br * k,
      x + width - br + br * k,
      y + height,
      x + width - br,
      y + height,
    )
  }
  self.line_to(x + bl, y + height)
  if bl > 0.0 {
    self.cubic_to(
      x + bl - bl * k,
      y + height,
      x,
      y + height - bl + bl * k,
      x,
      y + height - bl,
    )
  }
  self.line_to(x, y + tl)
  if tl > 0.0 {
    self.cubic_to(x, y + tl - tl * k, x + tl - tl * k, y, x + tl, y)
  }
  self.close()
}

///|
/// Appends an elliptical arc. Angles are radians and increase clockwise on
/// screen (the canvas convention: positive y points down).
pub fn Path::arc_at(
  self : Path,
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
  start_angle : Double,
  stop_angle : Double,
  mode : ArcMode,
) -> Unit {
  let mut delta = stop_angle - start_angle
  if delta < 0.0 {
    delta = delta + TAU
  }
  if delta == 0.0 {
    delta = TAU
  }
  delta = delta.min(TAU)
  let segments = (delta / HALF_PI).ceil().to_int().max(1)
  let step = delta / segments.to_double()
  let point = fn(angle : Double) {
    (cx + rx * @cmath.cos(angle), cy + ry * @cmath.sin(angle))
  }
  let start = point(start_angle)
  self.move_to(start.0, start.1)
  let mut angle = start_angle
  for _ in 0..<segments {
    let next_angle = angle + step
    let p0 = point(angle)
    let p1 = point(next_angle)
    let k = 4.0 / 3.0 * @cmath.tan(step / 4.0)
    let c1 = (
      p0.0 - rx * @cmath.sin(angle) * k,
      p0.1 + ry * @cmath.cos(angle) * k,
    )
    let c2 = (
      p1.0 + rx * @cmath.sin(next_angle) * k,
      p1.1 - ry * @cmath.cos(next_angle) * k,
    )
    self.cubic_to(c1.0, c1.1, c2.0, c2.1, p1.0, p1.1)
    angle = next_angle
  }
  match mode {
    Open => ()
    Chord => self.close()
    Pie => {
      self.line_to(cx, cy)
      self.close()
    }
  }
}

///|
/// Appends a quadratic/cubic Bézier through one segment.
pub fn Path::bezier_at(
  self : Path,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
  x4 : Double,
  y4 : Double,
) -> Unit {
  self.move_to(x1, y1)
  self.cubic_to(x2, y2, x3, y3, x4, y4)
}

///|
/// A conservative bounding box used for rectangular clip approximation.
pub fn Path::bounds(self : Path) -> (Double, Double, Double, Double) {
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut has_point = false
  let update = fn(x : Double, y : Double) {
    if !has_point {
      min_x = x
      min_y = y
      max_x = x
      max_y = y
      has_point = true
    } else {
      min_x = min_x.min(x)
      min_y = min_y.min(y)
      max_x = max_x.max(x)
      max_y = max_y.max(y)
    }
  }
  for command in self.commands {
    match command {
      MoveTo(x, y) | LineTo(x, y) => update(x, y)
      QuadTo(cx, cy, x, y) => {
        update(cx, cy)
        update(x, y)
      }
      CubicTo(c1x, c1y, c2x, c2y, x, y) => {
        update(c1x, c1y)
        update(c2x, c2y)
        update(x, y)
      }
      Close => ()
    }
  }
  (min_x, min_y, max_x - min_x, max_y - min_y)
}

///|
pub extend PathCmd with Eq::{not_equal, equal}

///|
pub extend ArcMode with Eq::{not_equal, equal}

///|
pub extend ShapeMode with Eq::{not_equal, equal}
