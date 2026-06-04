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
pub fn Path::add_poly(
  self : Path,
  points : Array[Point],
  close? : Bool = false,
) -> Path {
  if points.is_empty() {
    self
  } else {
    let path = for path = self.move_to(points[0]), i = 1
                   i < points.length()
                   i = i + 1 {
      continue path.line_to(points[i]), i + 1
    } nobreak {
      path
    }
    if close {
      path.close()
    } else {
      path
    }
  }
}

///|
fn Path::append_path_verbs(
  self : Path,
  path : Path,
  mode : AddPathMode,
) -> Path {
  if path.is_empty() {
    self
  } else {
    let (result, start_index) = if mode is Extend {
      match (self.current_point, path.verbs[0]) {
        (Some(_), MoveTo(point)) => (self.line_to(point), 1)
        _ => (self, 0)
      }
    } else {
      (self, 0)
    }
    for result = result, i = start_index; i < path.verbs.length(); i = i + 1 {
      let result = match path.verbs[i] {
        MoveTo(point) => result.move_to(point)
        LineTo(point) => result.line_to(point)
        QuadTo(control, end) => result.quad_to(control, end)
        ConicTo(control, end, weight) => result.conic_to(control, end, weight)
        CubicTo(control0, control1, end) =>
          result.cubic_to(control0, control1, end)
        Close => result.close()
      }
      continue result, i + 1
    } nobreak {
      result
    }
  }
}

///|
pub fn Path::add_path(
  self : Path,
  path : Path,
  matrix? : Matrix = Matrix::identity(),
  mode? : AddPathMode = Append,
) -> Path {
  self.append_path_verbs(path.transform(matrix), mode)
}

///|
pub fn Path::add_path_matrix(
  self : Path,
  path : Path,
  matrix : Matrix,
  mode? : AddPathMode = Append,
) -> Path {
  self.add_path(path, matrix~, mode~)
}

///|
pub fn Path::add_path_offset(
  self : Path,
  path : Path,
  offset : Point,
  mode? : AddPathMode = Append,
) -> Path {
  self.add_path(path, matrix=Matrix::translate(offset.x, offset.y), mode~)
}

///|
pub fn Path::with_offset(self : Path, offset : Point) -> Path {
  self.offset(offset.x, offset.y)
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
