///|
fn animation_approx_eq(left : Double, right : Double) -> Bool {
  let diff = left - right
  if diff < 0.0 {
    -diff < 0.0001
  } else {
    diff < 0.0001
  }
}

///|
test "animated_color fades a transparent endpoint without a dark mid-frame" {
  // Outline/Ghost hover: normal is fully transparent, hovered is an opaque
  // light tint. Straight RGBA lerp would hit `rgba(0.48,0.48,0.48,0.5)` at the
  // midpoint — a dark gray that flashes against a light surface.
  // Premultiplied interpolation keeps the hue at the destination tint and only
  // ramps coverage, so the midpoint stays the tint's color at half alpha.
  let from = @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)
  let to = @core.Color::rgba(r=0.957, g=0.957, b=0.961, a=1.0)
  let mid = @core.animated_color(
    from~,
    to~,
    progress=0.5,
    easing=@core.Easing::Linear,
  )
  // Hue must stay at the destination tint, not darken toward black.
  assert_true(mid.r > 0.9)
  assert_true(mid.g > 0.9)
  assert_true(mid.b > 0.9)
  assert_true(animation_approx_eq(mid.a, 0.5))
}

///|
test "animated_color is unchanged for opaque-to-opaque transitions" {
  // Premultiplied lerp reduces to straight lerp when both alphas are 1, so
  // existing opaque→opaque button hover transitions are unaffected.
  let from = @core.Color::rgba(r=0.1, g=0.2, b=0.3, a=1.0)
  let to = @core.Color::rgba(r=0.4, g=0.5, b=0.6, a=1.0)
  let mid = @core.animated_color(
    from~,
    to~,
    progress=0.5,
    easing=@core.Easing::Linear,
  )
  assert_true(animation_approx_eq(mid.r, 0.25))
  assert_true(animation_approx_eq(mid.g, 0.35))
  assert_true(animation_approx_eq(mid.b, 0.45))
  assert_true(animation_approx_eq(mid.a, 1.0))
}

///|
test "animated_color snaps to endpoints at progress bounds" {
  let from = @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)
  let to = @core.Color::rgba(r=0.957, g=0.957, b=0.961, a=1.0)
  let start = @core.animated_color(
    from~,
    to~,
    progress=0.0,
    easing=@core.Easing::Linear,
  )
  let end = @core.animated_color(
    from~,
    to~,
    progress=1.0,
    easing=@core.Easing::Linear,
  )
  // At progress 0 the result is fully transparent; we carry the destination
  // hue so a later alpha rise can't resurrect a stray color.
  assert_true(start.a == 0.0)
  assert_true(end == to)
}
