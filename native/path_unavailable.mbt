///|
pub fn Path::new() -> Path? {
  None
}

///|
pub fn Path::from_value(path : @skia.Path) -> Path? {
  ignore(path)
  None
}

///|
pub fn Path::is_available(self : Path) -> Bool {
  ignore(self)
  false
}

///|
pub fn Path::set_fill_type(self : Path, fill_type : @skia.PathFillType) -> Unit {
  ignore(self)
  ignore(fill_type)
}

///|
pub fn Path::fill_type(self : Path) -> @skia.PathFillType {
  ignore(self)
  @skia.Winding
}

///|
pub fn Path::is_inverse_fill_type(self : Path) -> Bool {
  ignore(self)
  false
}

///|
pub fn Path::reset(self : Path) -> Unit {
  ignore(self)
}

///|
pub fn Path::rewind(self : Path) -> Unit {
  ignore(self)
}

///|
pub fn Path::move_to(self : Path, point : @skia.Point) -> Unit {
  ignore(self)
  ignore(point)
}

///|
pub fn Path::line_to(self : Path, point : @skia.Point) -> Unit {
  ignore(self)
  ignore(point)
}

///|
pub fn Path::quad_to(
  self : Path,
  control : @skia.Point,
  end : @skia.Point,
) -> Unit {
  ignore(self)
  ignore(control)
  ignore(end)
}

///|
pub fn Path::conic_to(
  self : Path,
  control : @skia.Point,
  end : @skia.Point,
  weight : Float,
) -> Unit {
  ignore(self)
  ignore(control)
  ignore(end)
  ignore(weight)
}

///|
pub fn Path::cubic_to(
  self : Path,
  control0 : @skia.Point,
  control1 : @skia.Point,
  end : @skia.Point,
) -> Unit {
  ignore(self)
  ignore(control0)
  ignore(control1)
  ignore(end)
}

///|
pub fn Path::close(self : Path) -> Unit {
  ignore(self)
}

///|
pub fn Path::add_path_value(
  self : Path,
  path : @skia.Path,
  matrix? : @skia.Matrix = @skia.Matrix::identity(),
  mode? : @skia.AddPathMode = @skia.Append,
) -> Unit {
  ignore(self)
  ignore(path)
  ignore(matrix)
  ignore(mode)
}

///|
pub fn Path::add_path_value_matrix(
  self : Path,
  path : @skia.Path,
  matrix : @skia.Matrix,
  mode? : @skia.AddPathMode = @skia.Append,
) -> Unit {
  ignore(self)
  ignore(path)
  ignore(matrix)
  ignore(mode)
}

///|
pub fn Path::add_path_value_offset(
  self : Path,
  path : @skia.Path,
  offset : @skia.Point,
  mode? : @skia.AddPathMode = @skia.Append,
) -> Unit {
  ignore(self)
  ignore(path)
  ignore(offset)
  ignore(mode)
}

///|
pub fn Path::add_poly(
  self : Path,
  points : Array[@skia.Point],
  close? : Bool = false,
) -> Unit {
  ignore(self)
  ignore(points)
  ignore(close)
}

///|
pub fn Path::add_rect(
  self : Path,
  rect : @skia.Rect,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  ignore(self)
  ignore(rect)
  ignore(direction)
}

///|
pub fn Path::add_oval(
  self : Path,
  oval : @skia.Rect,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  ignore(self)
  ignore(oval)
  ignore(direction)
}

///|
pub fn Path::add_circle(
  self : Path,
  center : @skia.Point,
  radius : Float,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  ignore(self)
  ignore(center)
  ignore(radius)
  ignore(direction)
}

///|
pub fn Path::add_round_rect(
  self : Path,
  rect : @skia.Rect,
  rx : Float,
  ry : Float,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  ignore(self)
  ignore(rect)
  ignore(rx)
  ignore(ry)
  ignore(direction)
}

///|
pub fn Path::add_rrect(
  self : Path,
  rrect : @skia.RRect,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  ignore(self)
  ignore(rrect)
  ignore(direction)
}

///|
pub fn Path::transform(self : Path, matrix : @skia.Matrix) -> Unit {
  ignore(self)
  ignore(matrix)
}

///|
pub fn Path::offset(self : Path, dx : Float, dy : Float) -> Unit {
  ignore(self)
  ignore(dx)
  ignore(dy)
}

///|
pub fn Path::contains(self : Path, point : @skia.Point) -> Bool {
  ignore(self)
  ignore(point)
  false
}

///|
pub fn Path::is_empty(self : Path) -> Bool {
  ignore(self)
  true
}

///|
pub fn Path::is_finite(self : Path) -> Bool {
  ignore(self)
  true
}

///|
pub fn Path::count_points(self : Path) -> Int {
  ignore(self)
  0
}

///|
pub fn Path::count_verbs(self : Path) -> Int {
  ignore(self)
  0
}

///|
pub fn Path::segment_masks(self : Path) -> @skia.PathSegmentMask {
  ignore(self)
  @skia.PathSegmentMask::empty()
}

///|
pub fn Path::is_last_contour_closed(self : Path) -> Bool {
  ignore(self)
  false
}

///|
pub fn Path::last_point(self : Path) -> @skia.Point? {
  ignore(self)
  None
}

///|
pub fn Path::is_line(self : Path) -> @skia.PathLine? {
  ignore(self)
  None
}

///|
pub fn Path::is_rect(self : Path) -> @skia.PathRect? {
  ignore(self)
  None
}

///|
pub fn Path::is_oval(self : Path) -> @skia.Rect? {
  ignore(self)
  None
}

///|
pub fn Path::bounds(self : Path) -> @skia.Rect? {
  ignore(self)
  None
}

///|
pub fn Path::compute_tight_bounds(self : Path) -> @skia.Rect? {
  ignore(self)
  None
}
