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
