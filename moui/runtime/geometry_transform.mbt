///|
/// Compose two affine transforms: apply `inner`, then `outer`.
fn runtime_transform_compose(
  outer : @core.Transform2D,
  inner : @core.Transform2D,
) -> @core.Transform2D {
  {
    a: outer.a * inner.a + outer.c * inner.b,
    b: outer.b * inner.a + outer.d * inner.b,
    c: outer.a * inner.c + outer.c * inner.d,
    d: outer.b * inner.c + outer.d * inner.d,
    tx: outer.a * inner.tx + outer.c * inner.ty + outer.tx,
    ty: outer.b * inner.tx + outer.d * inner.ty + outer.ty,
  }
}

///|
fn runtime_transform_point(
  transform : @core.Transform2D,
  point : @core.Point,
) -> @core.Point {
  @core.Point::new(
    x=transform.a * point.x + transform.c * point.y + transform.tx,
    y=transform.b * point.x + transform.d * point.y + transform.ty,
  )
}

///|
/// Axis-aligned bounds of a transformed rectangle. This is intentionally
/// conservative for rotation/skew: hit testing and damage may cover more pixels
/// than the exact shape, but must never cover fewer.
fn runtime_transform_rect(
  transform : @core.Transform2D,
  rect : @core.Rect,
) -> @core.Rect {
  let right = rect.origin.x + rect.size.width
  let bottom = rect.origin.y + rect.size.height
  let first = runtime_transform_point(transform, rect.origin)
  let second = runtime_transform_point(
    transform,
    @core.Point::new(x=right, y=rect.origin.y),
  )
  let third = runtime_transform_point(
    transform,
    @core.Point::new(x=rect.origin.x, y=bottom),
  )
  let fourth = runtime_transform_point(
    transform,
    @core.Point::new(x=right, y=bottom),
  )
  let mut min_x = first.x
  let mut max_x = first.x
  let mut min_y = first.y
  let mut max_y = first.y
  for point in [second, third, fourth] {
    if point.x < min_x {
      min_x = point.x
    }
    if point.x > max_x {
      max_x = point.x
    }
    if point.y < min_y {
      min_y = point.y
    }
    if point.y > max_y {
      max_y = point.y
    }
  }
  @core.Rect::new(x=min_x, y=min_y, width=max_x - min_x, height=max_y - min_y)
}

///|
fn runtime_transform_is_identity(transform : @core.Transform2D) -> Bool {
  transform.a == 1.0 &&
  transform.b == 0.0 &&
  transform.c == 0.0 &&
  transform.d == 1.0 &&
  transform.tx == 0.0 &&
  transform.ty == 0.0
}

///|
fn runtime_screen_frame(
  node_to_screen : @core.Transform2D,
  frame : @core.Rect,
) -> @core.Rect {
  runtime_transform_rect(
    node_to_screen,
    @core.Rect::new(
      x=0.0,
      y=0.0,
      width=frame.size.width,
      height=frame.size.height,
    ),
  )
}

///|
fn runtime_child_to_screen(
  node_to_screen : @core.Transform2D,
  child_transform : @core.Transform2D,
  child_frame : @core.Rect,
) -> @core.Transform2D {
  runtime_transform_compose(
    runtime_transform_compose(node_to_screen, child_transform),
    @core.Transform2D::translation(
      dx=child_frame.origin.x,
      dy=child_frame.origin.y,
    ),
  )
}

///|
fn runtime_overlay_to_screen(frame : @core.Rect) -> @core.Transform2D {
  @core.Transform2D::translation(dx=frame.origin.x, dy=frame.origin.y)
}

///|
fn runtime_clip_intersection(
  outer : @core.Rect?,
  inner : @core.Rect,
) -> @core.Rect {
  match outer {
    Some(clip) =>
      match clip.intersection(inner) {
        Some(intersection) => intersection
        None => @core.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0)
      }
    None => inner
  }
}

///|
fn runtime_point_hits_frame(
  point : @core.Point,
  frame : @core.Rect,
  clip : @core.Rect?,
) -> Bool {
  frame.contains(point) &&
  (match clip {
    Some(value) => value.contains(point)
    None => true
  })
}
