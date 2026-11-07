///|
/// Smoke tests for slider and progress.

///|
test "slider smoke" {
  let view : @core.View[Unit] = @views.slider(
    0.5,
    on_change=Some(fn(_v) { () }),
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "slider range smoke" {
  let view : @core.View[Unit] = @views.slider(
    0.3,
    min=0.0,
    max=1.0,
    on_change=Some(fn(_v) { () }),
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "progress smoke" {
  let view : @core.View[Unit] = @views.progress(0.6)
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "range slider smoke" {
  let view : @core.View[Unit] = @views.range_slider(
    { start: 0.25, end: 0.75, },
    min=0.0,
    max=1.0,
    on_change=Some(fn(_range) { () }),
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
