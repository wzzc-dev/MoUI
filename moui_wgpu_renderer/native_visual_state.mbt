///|
fn native_paint_state_default() -> NativePaintState {
  {
    opacity: 1.0,
    transform: @core.Transform2D::identity(),
    clip: None,
    clip_radius: 0.0,
    clip_empty: false,
  }
}

///|
fn native_scoped_child_paint_state(
  state : NativePaintState,
) -> NativePaintState {
  { ..state, opacity: 1.0 }
}

///|
fn pop_native_paint_state(
  stack : Array[NativePaintState],
  fallback : NativePaintState,
) -> NativePaintState {
  match stack.pop() {
    Some(state) => state
    None => fallback
  }
}

///|
fn clamp_opacity(value : Double) -> Double {
  value.max(0.0).min(1.0)
}

///|
fn native_paint_state_visible(state : NativePaintState) -> Bool {
  !state.clip_empty
}

///|
fn push_clip_state(
  state : NativePaintState,
  rect : @core.Rect,
) -> NativePaintState {
  if state.clip_empty || rect.size.width <= 0.0 || rect.size.height <= 0.0 {
    { ..state, clip: None, clip_empty: true }
  } else {
    match intersect_clip(state.clip, transform_rect(rect, state.transform)) {
      Some(clip) => { ..state, clip: Some(clip), clip_empty: false }
      None => { ..state, clip: None, clip_empty: true }
    }
  }
}

///|
fn push_rounded_clip_state(
  state : NativePaintState,
  rounded : @core.RoundedRect,
) -> NativePaintState {
  if state.clip_empty ||
    rounded.rect.size.width <= 0.0 ||
    rounded.rect.size.height <= 0.0 {
    { ..state, clip: None, clip_radius: 0.0, clip_empty: true }
  } else {
    match
      intersect_clip(state.clip, transform_rect(rounded.rect, state.transform)) {
      Some(clip) => {
        let new_radius = if state.clip_radius > 0.0 {
          state.clip_radius.min(rounded.radius)
        } else {
          rounded.radius
        }
        {
          ..state,
          clip: Some(clip),
          clip_radius: new_radius,
          clip_empty: false,
        }
      }
      None => { ..state, clip: None, clip_radius: 0.0, clip_empty: true }
    }
  }
}

///|
fn multiply_transform(
  a : @core.Transform2D,
  b : @core.Transform2D,
) -> @core.Transform2D {
  {
    a: a.a * b.a + a.c * b.b,
    b: a.b * b.a + a.d * b.b,
    c: a.a * b.c + a.c * b.d,
    d: a.b * b.c + a.d * b.d,
    tx: a.a * b.tx + a.c * b.ty + a.tx,
    ty: a.b * b.tx + a.d * b.ty + a.ty,
  }
}

///|
fn transform_point(
  transform : @core.Transform2D,
  x : Double,
  y : Double,
) -> @core.Point {
  @core.Point::new(
    x=transform.a * x + transform.c * y + transform.tx,
    y=transform.b * x + transform.d * y + transform.ty,
  )
}

///|
fn transform_rect(
  rect : @core.Rect,
  transform : @core.Transform2D,
) -> @core.Rect {
  let p0 = transform_point(transform, rect.origin.x, rect.origin.y)
  let p1 = transform_point(
    transform,
    rect.origin.x + rect.size.width,
    rect.origin.y,
  )
  let p2 = transform_point(
    transform,
    rect.origin.x + rect.size.width,
    rect.origin.y + rect.size.height,
  )
  let p3 = transform_point(
    transform,
    rect.origin.x,
    rect.origin.y + rect.size.height,
  )
  let min_x = p0.x.min(p1.x).min(p2.x).min(p3.x)
  let max_x = p0.x.max(p1.x).max(p2.x).max(p3.x)
  let min_y = p0.y.min(p1.y).min(p2.y).min(p3.y)
  let max_y = p0.y.max(p1.y).max(p2.y).max(p3.y)
  @core.Rect::new(x=min_x, y=min_y, width=max_x - min_x, height=max_y - min_y)
}

///|
fn intersect_clip(current : @core.Rect?, next : @core.Rect) -> @core.Rect? {
  match current {
    Some(current) => rect_intersection(current, next)
    None => Some(next)
  }
}

///|
fn rect_intersection(a : @core.Rect, b : @core.Rect) -> @core.Rect? {
  let x0 = a.origin.x.max(b.origin.x)
  let y0 = a.origin.y.max(b.origin.y)
  let x1 = (a.origin.x + a.size.width).min(b.origin.x + b.size.width)
  let y1 = (a.origin.y + a.size.height).min(b.origin.y + b.size.height)
  if x1 <= x0 || y1 <= y0 {
    None
  } else {
    Some(@core.Rect::new(x=x0, y=y0, width=x1 - x0, height=y1 - y0))
  }
}

///|
fn native_scissor_for_state(
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
) -> NativeScissor? {
  match state.clip {
    Some(clip) => Some(native_scissor_for_rect(clip, size, scale_factor))
    None => None
  }
}

///|
fn native_layer_scissor(
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
  mask : NativeLayerMask?,
) -> NativeScissor? {
  let scissor = native_scissor_for_state(state, size, scale_factor)
  match mask {
    None => scissor
    Some(mask) =>
      native_scissor_for_optional_rect(
        intersect_clip(state.clip, mask.rect),
        size,
        scale_factor,
      )
  }
}

///|
fn native_layer_mask_for_state(
  state : NativePaintState,
  mask : @core.LayerMask,
) -> NativeLayerMask? {
  match mask {
    @core.LayerMask::NoMask => None
    @core.LayerMask::RectMask(rect) =>
      Some({
        rect: transform_rect(rect, state.transform),
        radius: 0.0,
        rounded: false,
      })
    @core.LayerMask::RoundedMask(rounded) =>
      Some({
        rect: transform_rect(rounded.rect, state.transform),
        radius: rounded.radius.max(0.0),
        rounded: true,
      })
  }
}

///|
fn native_scissor_for_optional_rect(
  rect : @core.Rect?,
  size : @core.Size,
  scale_factor : Double,
) -> NativeScissor? {
  match rect {
    Some(rect) => Some(native_scissor_for_rect(rect, size, scale_factor))
    None => Some({ x: 0, y: 0, width: 0, height: 0 })
  }
}

///|
fn native_scissor_for_rect(
  rect : @core.Rect,
  size : @core.Size,
  scale_factor : Double,
) -> NativeScissor {
  let scale = native_scissor_scale(scale_factor)
  let x0 = rect.origin.x.max(0.0).min(size.width.max(0.0))
  let y0 = rect.origin.y.max(0.0).min(size.height.max(0.0))
  let x1 = (rect.origin.x + rect.size.width).max(0.0).min(size.width.max(0.0))
  let y1 = (rect.origin.y + rect.size.height).max(0.0).min(size.height.max(0.0))
  {
    x: (x0 * scale).floor().to_int(),
    y: (y0 * scale).floor().to_int(),
    width: ((x1 - x0) * scale).ceil().max(0.0).to_int(),
    height: ((y1 - y0) * scale).ceil().max(0.0).to_int(),
  }
}

///|
fn native_scissor_visible(scissor : NativeScissor?) -> Bool {
  match scissor {
    Some(scissor) => scissor.width > 0 && scissor.height > 0
    None => true
  }
}

///|
fn native_scissor_scale(scale_factor : Double) -> Double {
  if scale_factor > 0.0 {
    scale_factor
  } else {
    1.0
  }
}
