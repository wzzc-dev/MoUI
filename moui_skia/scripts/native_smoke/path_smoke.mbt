///|
fn run_native_path_smoke(canvas : @native.Canvas) -> Unit {
  guard @native.Path::new() is Some(native_path) else {
    fail_smoke("failed to create native path")
  }
  native_path.add_rect(@skia.Rect::from_xywh(16, 24, 4, 4))
  if !native_path.contains(@skia.Point::new(18, 26)) {
    fail_smoke("native path does not contain a point inside its rect")
  }
  guard native_path.bounds() is Some(native_path_bounds) else {
    fail_smoke("native path did not report bounds")
  }
  if native_path_bounds != @skia.Rect::from_xywh(16, 24, 4, 4) {
    fail_smoke("native path bounds do not match its rect")
  }
  canvas.draw_path(native_path, @skia.Paint::new(color=@skia.Color::magenta()))

  guard @native.Path::new() is Some(native_poly) else {
    fail_smoke("failed to create native polygon path")
  }
  native_poly.add_poly(
    [
      @skia.Point::new(12, 28),
      @skia.Point::new(16, 28),
      @skia.Point::new(16, 31),
    ],
    close=true,
  )
  if !native_poly.is_last_contour_closed() ||
    native_poly.count_verbs() != 4 ||
    native_poly.count_points() != 3 {
    fail_smoke("native polygon path did not record the expected contour")
  }
  if !native_poly.contains(@skia.Point::new(15, 29)) {
    fail_smoke("native polygon path does not contain an interior point")
  }
  canvas.draw_path(native_poly, @skia.Paint::new(color=@skia.Color::magenta()))

  let portable_path = @skia.Path::new().add_rect(
    @skia.Rect::from_xywh(22, 26, 4, 4),
  )
  guard @native.Path::from_value(portable_path) is Some(replayed_path) else {
    fail_smoke("failed to replay portable path into native path")
  }
  if !replayed_path.contains(@skia.Point::new(24, 28)) {
    fail_smoke("replayed portable path does not contain an interior point")
  }
  canvas.draw_path_value(
    portable_path,
    @skia.Paint::new(color=@skia.Color::yellow()),
  )
  let non_finite_portable_path = @skia.Path::new()
    .move_to(@skia.Point::new(0, 0))
    .line_to(@skia.Point::new(1.0 / 0.0, 1))
  if non_finite_portable_path.is_finite() ||
    @native.Path::from_value(non_finite_portable_path) is Some(_) {
    fail_smoke("non-finite portable path should not replay into native path")
  }

  guard @native.Path::new() is Some(appended_path) else {
    fail_smoke("failed to create native add-path target")
  }
  appended_path.add_rect(@skia.Rect::from_xywh(28, 22, 2, 2))
  appended_path.add_path_value(
    @skia.Path::new().add_poly(
      [@skia.Point::new(0, 0), @skia.Point::new(3, 0), @skia.Point::new(3, 3)],
      close=true,
    ),
    matrix=@skia.Matrix::translate(28, 26),
  )
  if appended_path.count_verbs() != 9 ||
    appended_path.count_points() != 7 ||
    appended_path.bounds() != Some(@skia.Rect::new(28, 22, 31, 29)) {
    fail_smoke("native add_path_value did not append the expected geometry")
  }
  if !appended_path.contains(@skia.Point::new(30, 27)) {
    fail_smoke("native add_path_value does not contain appended geometry")
  }
  let appended_path_verbs = appended_path.count_verbs()
  let appended_path_points = appended_path.count_points()
  let appended_path_bounds = appended_path.bounds()
  appended_path.add_path_value(non_finite_portable_path)
  appended_path.add_path_value(
    @skia.Path::new().add_rect(@skia.Rect::from_xywh(0, 0, 1, 1)),
    matrix=@skia.Matrix::translate(1.0 / 0.0, 0),
  )
  if !appended_path.is_finite() ||
    appended_path.count_verbs() != appended_path_verbs ||
    appended_path.count_points() != appended_path_points ||
    appended_path.bounds() != appended_path_bounds {
    fail_smoke("native add_path_value should skip non-finite inputs")
  }
  appended_path.move_to(@skia.Point::new(0.0 / 0.0, 0))
  appended_path.line_to(@skia.Point::new(0, 1.0 / 0.0))
  appended_path.add_poly(
    [@skia.Point::new(0, 0), @skia.Point::new(1.0 / 0.0, 1)],
    close=true,
  )
  appended_path.add_rect(@skia.Rect::new(0, 0, 1.0 / 0.0, 1))
  appended_path.add_circle(@skia.Point::new(0, 0), 1.0 / 0.0)
  appended_path.transform(@skia.Matrix::translate(1.0 / 0.0, 0))
  appended_path.offset(0.0 / 0.0, 0)
  if !appended_path.is_finite() ||
    appended_path.count_verbs() != appended_path_verbs ||
    appended_path.count_points() != appended_path_points ||
    appended_path.bounds() != appended_path_bounds {
    fail_smoke("native path direct mutations should skip non-finite inputs")
  }
  println("native smoke path verbs")
  println(appended_path.count_verbs())
  println("native smoke non-finite path from-value rejected")
  println(1)
  println("native smoke non-finite path add skipped")
  println(2)
  println("native smoke non-finite path direct mutations skipped")
  println(7)
  canvas.draw_path(appended_path, @skia.Paint::new(color=@skia.Color::cyan()))
}
