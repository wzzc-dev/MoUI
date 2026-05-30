///|
extern "C" fn native_path_new() -> PathHandle = "moonbit_skia_path_new"

///|
#borrow(path)
extern "C" fn native_path_is_null(path : PathHandle) -> Bool = "moonbit_skia_path_is_null"

///|
#borrow(path)
extern "C" fn native_path_reset(path : PathHandle) -> Unit = "moonbit_skia_path_reset"

///|
#borrow(path)
extern "C" fn native_path_rewind(path : PathHandle) -> Unit = "moonbit_skia_path_rewind"

///|
#borrow(path)
extern "C" fn native_path_set_fill_type(
  path : PathHandle,
  fill_type : Int,
) -> Unit = "moonbit_skia_path_set_fill_type"

///|
#borrow(path)
extern "C" fn native_path_fill_type(path : PathHandle) -> Int = "moonbit_skia_path_fill_type"

///|
#borrow(path)
extern "C" fn native_path_is_inverse_fill_type(path : PathHandle) -> Bool = "moonbit_skia_path_is_inverse_fill_type"

///|
#borrow(path)
extern "C" fn native_path_move_to(
  path : PathHandle,
  x : Float,
  y : Float,
) -> Unit = "moonbit_skia_path_move_to"

///|
#borrow(path)
extern "C" fn native_path_line_to(
  path : PathHandle,
  x : Float,
  y : Float,
) -> Unit = "moonbit_skia_path_line_to"

///|
#borrow(path)
extern "C" fn native_path_quad_to(
  path : PathHandle,
  x1 : Float,
  y1 : Float,
  x2 : Float,
  y2 : Float,
) -> Unit = "moonbit_skia_path_quad_to"

///|
#borrow(path)
extern "C" fn native_path_conic_to(
  path : PathHandle,
  x1 : Float,
  y1 : Float,
  x2 : Float,
  y2 : Float,
  weight : Float,
) -> Unit = "moonbit_skia_path_conic_to"

///|
#borrow(path)
extern "C" fn native_path_cubic_to(
  path : PathHandle,
  x1 : Float,
  y1 : Float,
  x2 : Float,
  y2 : Float,
  x3 : Float,
  y3 : Float,
) -> Unit = "moonbit_skia_path_cubic_to"

///|
#borrow(path)
extern "C" fn native_path_close(path : PathHandle) -> Unit = "moonbit_skia_path_close"

///|
#borrow(path)
extern "C" fn native_path_add_rect(
  path : PathHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  direction : Int,
) -> Unit = "moonbit_skia_path_add_rect"

///|
#borrow(path)
extern "C" fn native_path_add_oval(
  path : PathHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  direction : Int,
) -> Unit = "moonbit_skia_path_add_oval"

///|
#borrow(path)
extern "C" fn native_path_add_circle(
  path : PathHandle,
  x : Float,
  y : Float,
  radius : Float,
  direction : Int,
) -> Unit = "moonbit_skia_path_add_circle"

///|
#borrow(path)
extern "C" fn native_path_add_round_rect(
  path : PathHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  rx : Float,
  ry : Float,
  direction : Int,
) -> Unit = "moonbit_skia_path_add_round_rect"

///|
#borrow(path)
extern "C" fn native_path_add_rrect(
  path : PathHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  upper_left_width : Float,
  upper_left_height : Float,
  upper_right_width : Float,
  upper_right_height : Float,
  lower_right_width : Float,
  lower_right_height : Float,
  lower_left_width : Float,
  lower_left_height : Float,
  direction : Int,
) -> Unit = "moonbit_skia_path_add_rrect"

///|
#borrow(path)
extern "C" fn native_path_transform(
  path : PathHandle,
  scale_x : Float,
  skew_x : Float,
  trans_x : Float,
  skew_y : Float,
  scale_y : Float,
  trans_y : Float,
  persp_0 : Float,
  persp_1 : Float,
  persp_2 : Float,
) -> Unit = "moonbit_skia_path_transform"

///|
#borrow(path)
extern "C" fn native_path_offset(
  path : PathHandle,
  dx : Float,
  dy : Float,
) -> Unit = "moonbit_skia_path_offset"

///|
#borrow(path)
extern "C" fn native_path_contains(
  path : PathHandle,
  x : Float,
  y : Float,
) -> Bool = "moonbit_skia_path_contains"

///|
#borrow(path)
extern "C" fn native_path_is_empty(path : PathHandle) -> Bool = "moonbit_skia_path_is_empty"

///|
#borrow(path)
extern "C" fn native_path_is_finite(path : PathHandle) -> Bool = "moonbit_skia_path_is_finite"

///|
#borrow(path)
extern "C" fn native_path_count_points(path : PathHandle) -> Int = "moonbit_skia_path_count_points"

///|
#borrow(path)
extern "C" fn native_path_count_verbs(path : PathHandle) -> Int = "moonbit_skia_path_count_verbs"

///|
#borrow(path)
extern "C" fn native_path_segment_masks(path : PathHandle) -> Int = "moonbit_skia_path_segment_masks"

///|
#borrow(path)
extern "C" fn native_path_is_last_contour_closed(path : PathHandle) -> Bool = "moonbit_skia_path_is_last_contour_closed"

///|
#borrow(path)
extern "C" fn native_path_has_last_point(path : PathHandle) -> Bool = "moonbit_skia_path_has_last_point"

///|
#borrow(path)
extern "C" fn native_path_last_point_x(path : PathHandle) -> Float = "moonbit_skia_path_last_point_x"

///|
#borrow(path)
extern "C" fn native_path_last_point_y(path : PathHandle) -> Float = "moonbit_skia_path_last_point_y"

///|
#borrow(path)
extern "C" fn native_path_is_line(path : PathHandle) -> Bool = "moonbit_skia_path_is_line"

///|
#borrow(path)
extern "C" fn native_path_line_start_x(path : PathHandle) -> Float = "moonbit_skia_path_line_start_x"

///|
#borrow(path)
extern "C" fn native_path_line_start_y(path : PathHandle) -> Float = "moonbit_skia_path_line_start_y"

///|
#borrow(path)
extern "C" fn native_path_line_end_x(path : PathHandle) -> Float = "moonbit_skia_path_line_end_x"

///|
#borrow(path)
extern "C" fn native_path_line_end_y(path : PathHandle) -> Float = "moonbit_skia_path_line_end_y"

///|
#borrow(path)
extern "C" fn native_path_is_rect(path : PathHandle) -> Bool = "moonbit_skia_path_is_rect"

///|
#borrow(path)
extern "C" fn native_path_rect_left(path : PathHandle) -> Float = "moonbit_skia_path_rect_left"

///|
#borrow(path)
extern "C" fn native_path_rect_top(path : PathHandle) -> Float = "moonbit_skia_path_rect_top"

///|
#borrow(path)
extern "C" fn native_path_rect_right(path : PathHandle) -> Float = "moonbit_skia_path_rect_right"

///|
#borrow(path)
extern "C" fn native_path_rect_bottom(path : PathHandle) -> Float = "moonbit_skia_path_rect_bottom"

///|
#borrow(path)
extern "C" fn native_path_rect_is_closed(path : PathHandle) -> Bool = "moonbit_skia_path_rect_is_closed"

///|
#borrow(path)
extern "C" fn native_path_rect_direction(path : PathHandle) -> Int = "moonbit_skia_path_rect_direction"

///|
#borrow(path)
extern "C" fn native_path_is_oval(path : PathHandle) -> Bool = "moonbit_skia_path_is_oval"

///|
#borrow(path)
extern "C" fn native_path_oval_left(path : PathHandle) -> Float = "moonbit_skia_path_oval_left"

///|
#borrow(path)
extern "C" fn native_path_oval_top(path : PathHandle) -> Float = "moonbit_skia_path_oval_top"

///|
#borrow(path)
extern "C" fn native_path_oval_right(path : PathHandle) -> Float = "moonbit_skia_path_oval_right"

///|
#borrow(path)
extern "C" fn native_path_oval_bottom(path : PathHandle) -> Float = "moonbit_skia_path_oval_bottom"

///|
#borrow(path)
extern "C" fn native_path_bounds_left(path : PathHandle) -> Float = "moonbit_skia_path_bounds_left"

///|
#borrow(path)
extern "C" fn native_path_bounds_top(path : PathHandle) -> Float = "moonbit_skia_path_bounds_top"

///|
#borrow(path)
extern "C" fn native_path_bounds_right(path : PathHandle) -> Float = "moonbit_skia_path_bounds_right"

///|
#borrow(path)
extern "C" fn native_path_bounds_bottom(path : PathHandle) -> Float = "moonbit_skia_path_bounds_bottom"

///|
#borrow(path)
extern "C" fn native_path_tight_bounds_left(path : PathHandle) -> Float = "moonbit_skia_path_tight_bounds_left"

///|
#borrow(path)
extern "C" fn native_path_tight_bounds_top(path : PathHandle) -> Float = "moonbit_skia_path_tight_bounds_top"

///|
#borrow(path)
extern "C" fn native_path_tight_bounds_right(path : PathHandle) -> Float = "moonbit_skia_path_tight_bounds_right"

///|
#borrow(path)
extern "C" fn native_path_tight_bounds_bottom(path : PathHandle) -> Float = "moonbit_skia_path_tight_bounds_bottom"

///|
pub fn Path::new() -> Path? {
  let handle = native_path_new()
  if native_path_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Path::from_value(path : @skia.Path) -> Path? {
  match Path::new() {
    None => None
    Some(native_path) => {
      native_path.set_fill_type(path.fill_type)
      native_path.add_path_value(path)
      Some(native_path)
    }
  }
}

///|
pub fn Path::is_available(self : Path) -> Bool {
  !native_path_is_null(self.handle)
}

///|
pub fn Path::set_fill_type(self : Path, fill_type : @skia.PathFillType) -> Unit {
  native_path_set_fill_type(self.handle, fill_type.to_skia_ordinal())
}

///|
pub fn Path::fill_type(self : Path) -> @skia.PathFillType {
  match native_path_fill_type(self.handle) {
    1 => @skia.EvenOdd
    2 => @skia.InverseWinding
    3 => @skia.InverseEvenOdd
    _ => @skia.Winding
  }
}

///|
pub fn Path::is_inverse_fill_type(self : Path) -> Bool {
  native_path_is_inverse_fill_type(self.handle)
}

///|
pub fn Path::reset(self : Path) -> Unit {
  native_path_reset(self.handle)
}

///|
pub fn Path::rewind(self : Path) -> Unit {
  native_path_rewind(self.handle)
}

///|
pub fn Path::move_to(self : Path, point : @skia.Point) -> Unit {
  native_path_move_to(self.handle, point.x, point.y)
}

///|
pub fn Path::line_to(self : Path, point : @skia.Point) -> Unit {
  native_path_line_to(self.handle, point.x, point.y)
}

///|
pub fn Path::quad_to(
  self : Path,
  control : @skia.Point,
  end : @skia.Point,
) -> Unit {
  native_path_quad_to(self.handle, control.x, control.y, end.x, end.y)
}

///|
pub fn Path::conic_to(
  self : Path,
  control : @skia.Point,
  end : @skia.Point,
  weight : Float,
) -> Unit {
  native_path_conic_to(self.handle, control.x, control.y, end.x, end.y, weight)
}

///|
pub fn Path::cubic_to(
  self : Path,
  control0 : @skia.Point,
  control1 : @skia.Point,
  end : @skia.Point,
) -> Unit {
  native_path_cubic_to(
    self.handle,
    control0.x,
    control0.y,
    control1.x,
    control1.y,
    end.x,
    end.y,
  )
}

///|
pub fn Path::close(self : Path) -> Unit {
  native_path_close(self.handle)
}

///|
pub fn Path::add_path_value(
  self : Path,
  path : @skia.Path,
  matrix? : @skia.Matrix = @skia.Matrix::identity(),
  mode? : @skia.AddPathMode = @skia.Append,
) -> Unit {
  let path = path.transform(matrix)
  let start_index = if mode is @skia.Extend && !path.verbs.is_empty() {
    match (self.last_point(), path.verbs[0]) {
      (Some(_), @skia.MoveTo(point)) => {
        self.line_to(point)
        1
      }
      _ => 0
    }
  } else {
    0
  }
  for i = start_index; i < path.verbs.length(); i = i + 1 {
    let verb = path.verbs[i]
    match verb {
      @skia.MoveTo(point) => self.move_to(point)
      @skia.LineTo(point) => self.line_to(point)
      @skia.QuadTo(control, end) => self.quad_to(control, end)
      @skia.ConicTo(control, end, weight) => self.conic_to(control, end, weight)
      @skia.CubicTo(control0, control1, end) =>
        self.cubic_to(control0, control1, end)
      @skia.Close => self.close()
    }
  }
}

///|
pub fn Path::add_path_value_matrix(
  self : Path,
  path : @skia.Path,
  matrix : @skia.Matrix,
  mode? : @skia.AddPathMode = @skia.Append,
) -> Unit {
  self.add_path_value(path, matrix~, mode~)
}

///|
pub fn Path::add_path_value_offset(
  self : Path,
  path : @skia.Path,
  offset : @skia.Point,
  mode? : @skia.AddPathMode = @skia.Append,
) -> Unit {
  self.add_path_value(
    path,
    matrix=@skia.Matrix::translate(offset.x, offset.y),
    mode~,
  )
}

///|
pub fn Path::add_poly(
  self : Path,
  points : Array[@skia.Point],
  close? : Bool = false,
) -> Unit {
  if !points.is_empty() {
    self.move_to(points[0])
    for i = 1; i < points.length(); i = i + 1 {
      self.line_to(points[i])
    }
    if close {
      self.close()
    }
  }
}

///|
pub fn Path::add_rect(
  self : Path,
  rect : @skia.Rect,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  native_path_add_rect(
    self.handle,
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
    direction.to_skia_ordinal(),
  )
}

///|
pub fn Path::add_oval(
  self : Path,
  oval : @skia.Rect,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  native_path_add_oval(
    self.handle,
    oval.left,
    oval.top,
    oval.right,
    oval.bottom,
    direction.to_skia_ordinal(),
  )
}

///|
pub fn Path::add_circle(
  self : Path,
  center : @skia.Point,
  radius : Float,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  native_path_add_circle(
    self.handle,
    center.x,
    center.y,
    radius,
    direction.to_skia_ordinal(),
  )
}

///|
pub fn Path::add_round_rect(
  self : Path,
  rect : @skia.Rect,
  rx : Float,
  ry : Float,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  native_path_add_round_rect(
    self.handle,
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
    rx,
    ry,
    direction.to_skia_ordinal(),
  )
}

///|
pub fn Path::add_rrect(
  self : Path,
  rrect : @skia.RRect,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  native_path_add_rrect(
    self.handle,
    rrect.rect.left,
    rrect.rect.top,
    rrect.rect.right,
    rrect.rect.bottom,
    rrect.upper_left.width,
    rrect.upper_left.height,
    rrect.upper_right.width,
    rrect.upper_right.height,
    rrect.lower_right.width,
    rrect.lower_right.height,
    rrect.lower_left.width,
    rrect.lower_left.height,
    direction.to_skia_ordinal(),
  )
}

///|
pub fn Path::transform(self : Path, matrix : @skia.Matrix) -> Unit {
  native_path_transform(
    self.handle,
    matrix.scale_x,
    matrix.skew_x,
    matrix.trans_x,
    matrix.skew_y,
    matrix.scale_y,
    matrix.trans_y,
    matrix.persp_0,
    matrix.persp_1,
    matrix.persp_2,
  )
}

///|
pub fn Path::offset(self : Path, dx : Float, dy : Float) -> Unit {
  native_path_offset(self.handle, dx, dy)
}

///|
pub fn Path::contains(self : Path, point : @skia.Point) -> Bool {
  native_path_contains(self.handle, point.x, point.y)
}

///|
pub fn Path::is_empty(self : Path) -> Bool {
  native_path_is_empty(self.handle)
}

///|
pub fn Path::is_finite(self : Path) -> Bool {
  native_path_is_finite(self.handle)
}

///|
pub fn Path::count_points(self : Path) -> Int {
  native_path_count_points(self.handle)
}

///|
pub fn Path::count_verbs(self : Path) -> Int {
  native_path_count_verbs(self.handle)
}

///|
pub fn Path::segment_masks(self : Path) -> @skia.PathSegmentMask {
  @skia.PathSegmentMask::new(native_path_segment_masks(self.handle))
}

///|
pub fn Path::is_last_contour_closed(self : Path) -> Bool {
  native_path_is_last_contour_closed(self.handle)
}

///|
pub fn Path::last_point(self : Path) -> @skia.Point? {
  if native_path_has_last_point(self.handle) {
    Some(
      @skia.Point::new(
        native_path_last_point_x(self.handle),
        native_path_last_point_y(self.handle),
      ),
    )
  } else {
    None
  }
}

///|
pub fn Path::is_line(self : Path) -> @skia.PathLine? {
  if native_path_is_line(self.handle) {
    Some(
      @skia.PathLine::new(
        @skia.Point::new(
          native_path_line_start_x(self.handle),
          native_path_line_start_y(self.handle),
        ),
        @skia.Point::new(
          native_path_line_end_x(self.handle),
          native_path_line_end_y(self.handle),
        ),
      ),
    )
  } else {
    None
  }
}

///|
pub fn Path::is_rect(self : Path) -> @skia.PathRect? {
  if native_path_is_rect(self.handle) {
    let direction = match native_path_rect_direction(self.handle) {
      1 => @skia.CCW
      _ => @skia.CW
    }
    Some(
      @skia.PathRect::new(
        @skia.Rect::new(
          native_path_rect_left(self.handle),
          native_path_rect_top(self.handle),
          native_path_rect_right(self.handle),
          native_path_rect_bottom(self.handle),
        ),
        native_path_rect_is_closed(self.handle),
        direction,
      ),
    )
  } else {
    None
  }
}

///|
pub fn Path::is_oval(self : Path) -> @skia.Rect? {
  if native_path_is_oval(self.handle) {
    Some(
      @skia.Rect::new(
        native_path_oval_left(self.handle),
        native_path_oval_top(self.handle),
        native_path_oval_right(self.handle),
        native_path_oval_bottom(self.handle),
      ),
    )
  } else {
    None
  }
}

///|
pub fn Path::bounds(self : Path) -> @skia.Rect? {
  if self.is_empty() {
    None
  } else {
    Some(
      @skia.Rect::new(
        native_path_bounds_left(self.handle),
        native_path_bounds_top(self.handle),
        native_path_bounds_right(self.handle),
        native_path_bounds_bottom(self.handle),
      ),
    )
  }
}

///|
pub fn Path::compute_tight_bounds(self : Path) -> @skia.Rect? {
  if self.is_empty() {
    None
  } else {
    Some(
      @skia.Rect::new(
        native_path_tight_bounds_left(self.handle),
        native_path_tight_bounds_top(self.handle),
        native_path_tight_bounds_right(self.handle),
        native_path_tight_bounds_bottom(self.handle),
      ),
    )
  }
}
