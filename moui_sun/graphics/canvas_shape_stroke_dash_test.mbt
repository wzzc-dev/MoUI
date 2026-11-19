///|
test "Canvas::stroke_path supports dotted strokes" {
  let canvas = @graphics.Canvas::new(8, 5)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().move_to(1.0, 2.0).line_to(7.0, 2.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_dotted_stroke()
  canvas.stroke_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_not_white(pixmap.get_pixel(1, 2))
  assert_eq(pixmap.get_pixel(3, 2), @graphics.Color::white())
  assert_not_white(pixmap.get_pixel(5, 2))
}

///|
fn assert_not_white(color : @graphics.Color) -> Unit raise {
  assert_true(color != @graphics.Color::white())
}

///|
fn assert_empty_stroke_width_skips_pixels(width : Double) -> Unit raise {
  let canvas = @graphics.Canvas::new(5, 4)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let path = @graphics.Path::new().move_to(0.0, 1.0).line_to(4.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(width)
  canvas.stroke_path(path, paint)
  assert_eq(paint.get_stroke_width(), 0.0)
  assert_eq(canvas.get_pixmap().get_pixel(2, 1), @graphics.Color::white())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
fn assert_same_pixmap(
  left : @graphics.Pixmap,
  right : @graphics.Pixmap,
) -> Unit raise {
  assert_eq(left.get_width(), right.get_width())
  assert_eq(left.get_height(), right.get_height())
  for y in 0..<left.get_height() {
    for x in 0..<left.get_width() {
      assert_eq(left.get_pixel(x, y), right.get_pixel(x, y))
    }
  }
}

///|
/// Largest per-channel difference allowed between two anti-aliased
/// rasterisations of the same geometry, in 1/255ths.
let antialias_sample_tolerance : Int32 = 24

///|
fn color_channel_delta(a : @graphics.Color, b : @graphics.Color) -> Int32 {
  let dr = (a.r.to_int() - b.r.to_int()).abs()
  let dg = (a.g.to_int() - b.g.to_int()).abs()
  let db = (a.b.to_int() - b.b.to_int()).abs()
  let da = (a.a.to_int() - b.a.to_int()).abs()
  dr.max(dg).max(db).max(da)
}

///|
/// A solid pixel is fully inked or fully background in every channel: nothing
/// about it depends on where inside that pixel a sampler put its probes.
fn is_solid_color(color : @graphics.Color) -> Bool {
  let channels = [color.r, color.g, color.b, color.a]
  for channel in channels {
    let value = channel.to_int()
    if value != 0 && value != 255 {
      return false
    }
  }
  true
}

///|
/// Compare two rasterisations of the same geometry across different samplers.
///
/// `fill_rounded_rect` / `stroke_rounded_rect` accumulate analytic row coverage
/// (exact horizontal spans, 16 vertical steps per row), while `fill_path` /
/// `stroke_path` probe the same shape on an adaptive 4x4/16x16 grid. Both
/// describe the same outline, so every pixel that is solid in both images must
/// be identical — a difference there is a shape or placement error, not
/// anti-aliasing. Only partially covered edge pixels may differ, because where
/// exactly a sampler puts its probes inside a pixel is a sampling choice; the
/// measured worst case on the parity cases is 16/255, so they get a 24/255
/// budget and a readable report when it is exceeded.
fn assert_pixmaps_match_within_sampling(
  left : @graphics.Pixmap,
  right : @graphics.Pixmap,
) -> Unit raise {
  assert_eq(left.get_width(), right.get_width())
  assert_eq(left.get_height(), right.get_height())
  for y in 0..<left.get_height() {
    for x in 0..<left.get_width() {
      let a = left.get_pixel(x, y)
      let b = right.get_pixel(x, y)
      if a != b {
        let delta = color_channel_delta(a, b)
        let both_solid = is_solid_color(a) && is_solid_color(b)
        if both_solid || delta > antialias_sample_tolerance {
          println(
            "pixel \{x},\{y}: helper=\{a} path=\{b} delta=\{delta} both_solid=\{both_solid}",
          )
        }
        assert_true(!both_solid && delta <= antialias_sample_tolerance)
      }
    }
  }
}

///|
test "Canvas::stroke_path ignores fill paint" {
  let canvas = @graphics.Canvas::new(3, 3)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().move_to(0.0, 1.0).line_to(3.0, 1.0)
  canvas.stroke_path(
    path,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(canvas.get_pixmap().get_pixel(1, 1), @graphics.Color::white())
}
