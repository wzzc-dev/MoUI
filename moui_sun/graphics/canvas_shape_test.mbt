///|
test "Canvas::fill_rect respects and clears clip rect" {
  let canvas = @graphics.Canvas::new(3, 1)
  canvas.clear(@graphics.Color::white())
  canvas.set_clip_rect(@graphics.Rect::new(x=1.0, y=0.0, width=1.0, height=1.0))
  canvas.fill_rect(
    0.0,
    0.0,
    3.0,
    1.0,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_true(
    canvas.get_clip_rect() ==
    Some(@graphics.Rect::new(x=1.0, y=0.0, width=1.0, height=1.0)),
  )
  let clipped = canvas.get_pixmap()
  assert_eq(clipped.get_pixel(0, 0), @graphics.Color::white())
  assert_eq(clipped.get_pixel(1, 0), @graphics.Color::black())
  assert_eq(clipped.get_pixel(2, 0), @graphics.Color::white())
  canvas.clear_clip()
  assert_true(canvas.get_clip_rect() == None)
  canvas.fill_rect(
    2.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::black())
}

///|
test "Canvas::fill_rect applies paint blend mode" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(Multiply)
  canvas.fill_rect(0.0, 0.0, 1.0, 1.0, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=78, g=59, b=39),
  )
}

///|
test "Canvas::fill_rect destination blend leaves shader fill clean" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )

  canvas.fill_rect(
    0.0,
    0.0,
    2.0,
    1.0,
    @graphics.Paint::new().set_shader(shader).set_blend_mode(Destination),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::fill_path destination blend leaves dirty empty" {
  let canvas = @graphics.Canvas::new(2, 2)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()

  canvas.fill_path(
    @graphics.Path::new().add_rect(0.0, 0.0, 2.0, 2.0),
    @graphics.Paint::new()
    .set_color(@graphics.Color::red())
    .set_blend_mode(Destination),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 1), @graphics.Color::white())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::fill_rect applies darken and lighten blend modes" {
  let darken = @graphics.Canvas::new(1, 1)
  darken.clear(@graphics.Color::new(r=100, g=150, b=200))
  darken.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(Darken),
  )
  assert_eq(
    darken.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=100, g=100, b=50),
  )

  let lighten = @graphics.Canvas::new(1, 1)
  lighten.clear(@graphics.Color::new(r=100, g=150, b=200))
  lighten.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(Lighten),
  )
  assert_eq(
    lighten.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=200, g=150, b=200),
  )
}

///|
test "Canvas::fill_rect applies difference blend mode" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  canvas.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(Difference),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=100, g=50, b=150),
  )
}

///|
test "Canvas::fill_rect applies exclusion blend mode" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  canvas.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(Exclusion),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=143, g=132, b=172),
  )
}

///|
test "Canvas::fill_rect applies overlay blend mode" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  canvas.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(Overlay),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=157, g=127, b=167),
  )
}

///|
test "Canvas::fill_rect applies hard-light blend mode" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  canvas.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(HardLight),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=188, g=118, b=78),
  )
}

///|
test "Canvas::fill_rect applies soft-light blend mode" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  canvas.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(SoftLight),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=134, g=137, b=174),
  )
}

///|
test "Canvas::fill_rect applies color-dodge and color-burn blend modes" {
  let dodge = @graphics.Canvas::new(1, 1)
  dodge.clear(@graphics.Color::new(r=100, g=150, b=200))
  dodge.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(ColorDodge),
  )
  assert_eq(
    dodge.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=255, g=247, b=249),
  )

  let burn = @graphics.Canvas::new(1, 1)
  burn.clear(@graphics.Color::new(r=100, g=150, b=200))
  burn.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(ColorBurn),
  )
  assert_eq(
    burn.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=57, g=0, b=0),
  )
}

///|
test "Canvas::fill_rect applies hue saturation color luminosity blend modes" {
  let hue = @graphics.Canvas::new(1, 1)
  hue.clear(@graphics.Color::new(r=100, g=150, b=200))
  hue.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(Hue),
  )
  assert_eq(
    hue.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=191, g=124, b=91),
  )

  let saturation = @graphics.Canvas::new(1, 1)
  saturation.clear(@graphics.Color::new(r=100, g=150, b=200))
  saturation.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(Saturation),
  )
  assert_eq(
    saturation.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=80, g=155, b=230),
  )

  let color = @graphics.Canvas::new(1, 1)
  color.clear(@graphics.Color::new(r=100, g=150, b=200))
  color.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(Color),
  )
  assert_eq(
    color.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=216, g=116, b=66),
  )

  let luminosity = @graphics.Canvas::new(1, 1)
  luminosity.clear(@graphics.Color::new(r=100, g=150, b=200))
  luminosity.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(Luminosity),
  )
  assert_eq(
    luminosity.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=84, g=134, b=184),
  )
}

///|
test "Canvas::fill_rect applies linear-burn blend mode" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  canvas.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(LinearBurn),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=45, g=0, b=0),
  )
}

///|
test "Canvas::fill_rect applies subtract blend mode" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  canvas.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(Subtract),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=0, g=50, b=150),
  )
}

///|
test "Canvas::fill_rect can replace pixels with source blend mode" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50, a=128))
    .set_blend_mode(Source)
  canvas.fill_rect(0.0, 0.0, 1.0, 1.0, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=200, g=100, b=50, a=128),
  )
}

///|
test "Canvas::fill_rect applies source mask blend modes" {
  let kept = @graphics.Canvas::new(1, 1)
  kept.clear(@graphics.Color::new(r=100, g=150, b=200, a=128))
  kept.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(SourceIn),
  )
  assert_eq(
    kept.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=200, g=100, b=50, a=128),
  )

  let clipped_out = @graphics.Canvas::new(1, 1)
  clipped_out.clear(@graphics.Color::new(r=100, g=150, b=200, a=128))
  clipped_out.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(SourceOut),
  )
  assert_eq(
    clipped_out.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=200, g=100, b=50, a=127),
  )
}

///|
test "Canvas::fill_rect applies destination mask blend modes" {
  let kept = @graphics.Canvas::new(1, 1)
  kept.clear(@graphics.Color::new(r=100, g=150, b=200))
  kept.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=0, g=0, b=0, a=128))
    .set_blend_mode(DestinationIn),
  )
  assert_eq(
    kept.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=100, g=150, b=200, a=128),
  )

  let erased = @graphics.Canvas::new(1, 1)
  erased.clear(@graphics.Color::new(r=100, g=150, b=200))
  erased.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=0, g=0, b=0, a=128))
    .set_blend_mode(DestinationOut),
  )
  assert_eq(
    erased.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=100, g=150, b=200, a=127),
  )
}

///|
test "Canvas::fill_rect applies Porter-Duff clear and xor blend modes" {
  let cleared = @graphics.Canvas::new(1, 1)
  cleared.clear(@graphics.Color::new(r=100, g=150, b=200, a=192))
  cleared.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50, a=128))
    .set_blend_mode(Clear),
  )
  assert_eq(
    cleared.get_pixmap().get_pixel(0, 0),
    @graphics.Color::transparent(),
  )

  let xor = @graphics.Canvas::new(1, 1)
  xor.clear(@graphics.Color::new(r=100, g=150, b=200, a=192))
  xor.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50, a=128))
    .set_blend_mode(Xor),
  )
  assert_eq(
    xor.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=124, g=137, b=162, a=128),
  )
}

///|
test "Canvas::fill_rect samples paint shader" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  canvas.fill_rect(
    0.0,
    0.0,
    2.0,
    1.0,
    @graphics.Paint::new().set_shader(shader),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=191, g=0, b=64),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=64, g=0, b=191),
  )
}

///|
test "Canvas::fill_rect uses subpixel coverage" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  canvas.fill_rect(
    0.5,
    0.0,
    0.5,
    1.0,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=127, g=127, b=127),
  )
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=1, height=1)),
  )
}

///|
test "Canvas::fill_rect fractional shader matches rectangular path fill" {
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=3.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let paint = @graphics.Paint::new()
    .set_shader(shader)
    .set_filter(@graphics.PaintFilter::invert())
    .set_blend_mode(Multiply)

  let rect_canvas = @graphics.Canvas::new(3, 1)
  rect_canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  rect_canvas.clear_dirty_region()
  rect_canvas.fill_rect(0.5, 0.0, 1.5, 1.0, paint)

  let path_canvas = @graphics.Canvas::new(3, 1)
  path_canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  path_canvas.clear_dirty_region()
  path_canvas.fill_path(
    @graphics.Path::new().add_rect(0.5, 0.0, 1.5, 1.0),
    paint,
  )

  assert_same_pixmap(rect_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    rect_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
}

///|
test "Canvas::fill_rect keeps decal shader outside region transparent" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  let shader = @graphics.PaintShader::linear_gradient(
    x0=1.0,
    y0=0.0,
    x1=3.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  canvas.fill_rect(
    0.0,
    0.0,
    4.0,
    1.0,
    @graphics.Paint::new().set_shader(shader),
  )
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=191, g=0, b=64),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(2, 0),
    @graphics.Color::new(r=64, g=0, b=191),
  )
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::white())
}

///|
test "Canvas::fill_rect decal shader tracks tight dirty bounds" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=1.0,
    y0=0.0,
    x1=3.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  canvas.fill_rect(
    0.0,
    0.0,
    4.0,
    1.0,
    @graphics.Paint::new().set_shader(shader),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=191, g=0, b=64),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(2, 0),
    @graphics.Color::new(r=64, g=0, b=191),
  )
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::fill_rect all-transparent decal shader leaves dirty empty" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=10.0,
    y0=0.0,
    x1=12.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  canvas.fill_rect(
    0.0,
    0.0,
    2.0,
    1.0,
    @graphics.Paint::new().set_shader(shader),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::fill_rect transparent solid source-over leaves dirty empty" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  canvas.fill_rect(
    0.0,
    0.0,
    2.0,
    1.0,
    @graphics.Paint::new().set_color(@graphics.Color::transparent()),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::fill_rect transparent solid clear stays active" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  canvas.fill_rect(
    0.0,
    0.0,
    2.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::transparent())
    .set_blend_mode(Clear),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::transparent())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::fill_rect decal shader keeps transparent-source blends active" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=1.0,
    y0=0.0,
    x1=3.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  canvas.fill_rect(
    0.0,
    0.0,
    4.0,
    1.0,
    @graphics.Paint::new().set_shader(shader).set_blend_mode(Clear),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::transparent())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=1)),
  )
}

///|
test "Canvas::fill_rect transformed decal shader tracks tight dirty bounds" {
  let canvas = @graphics.Canvas::new(5, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  canvas.set_transform(@graphics.Transform::translate(tx=1.0, ty=0.0))
  let shader = @graphics.PaintShader::linear_gradient(
    x0=2.0,
    y0=0.0,
    x1=4.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  canvas.fill_rect(
    0.0,
    0.0,
    4.0,
    1.0,
    @graphics.Paint::new().set_shader(shader),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())
  assert_eq(
    canvas.get_pixmap().get_pixel(2, 0),
    @graphics.Color::new(r=191, g=0, b=64),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(3, 0),
    @graphics.Color::new(r=64, g=0, b=191),
  )
  assert_eq(canvas.get_pixmap().get_pixel(4, 0), @graphics.Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::fill_rect samples multi-stop paint shader" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  let shader = @graphics.PaintShader::linear_gradient_stops(
    x0=0.0,
    y0=0.0,
    x1=4.0,
    y1=0.0,
    stops=[
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(
        offset=0.5,
        color=@graphics.Color::green(),
      ),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
  )
  canvas.fill_rect(
    0.0,
    0.0,
    4.0,
    1.0,
    @graphics.Paint::new().set_shader(shader),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=191, g=64, b=0),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=64, g=191, b=0),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(2, 0),
    @graphics.Color::new(r=0, g=191, b=64),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(3, 0),
    @graphics.Color::new(r=0, g=64, b=191),
  )
}

///|
test "Canvas::fill_rect samples radial paint shader" {
  let canvas = @graphics.Canvas::new(3, 1)
  canvas.clear(@graphics.Color::white())
  let shader = @graphics.PaintShader::radial_gradient(
    cx=0.5,
    cy=0.5,
    radius=2.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  canvas.fill_rect(
    0.0,
    0.0,
    3.0,
    1.0,
    @graphics.Paint::new().set_shader(shader),
  )
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=128, g=0, b=128),
  )
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::blue())
}

///|
test "Canvas::fill_rect samples multi-stop radial paint shader" {
  let canvas = @graphics.Canvas::new(5, 1)
  canvas.clear(@graphics.Color::white())
  let shader = @graphics.PaintShader::radial_gradient_stops(
    cx=0.5,
    cy=0.5,
    radius=4.0,
    stops=[
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(
        offset=0.5,
        color=@graphics.Color::green(),
      ),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
  )
  canvas.fill_rect(
    0.0,
    0.0,
    5.0,
    1.0,
    @graphics.Paint::new().set_shader(shader),
  )
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=128, g=128, b=0),
  )
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())
  assert_eq(
    canvas.get_pixmap().get_pixel(3, 0),
    @graphics.Color::new(r=0, g=128, b=128),
  )
  assert_eq(canvas.get_pixmap().get_pixel(4, 0), @graphics.Color::blue())
}

///|
test "Canvas::fill_rect samples sweep paint shader" {
  let canvas = @graphics.Canvas::new(2, 2)
  canvas.clear(@graphics.Color::white())
  let shader = @graphics.PaintShader::sweep_gradient(
    cx=0.5,
    cy=0.5,
    start_angle=0.0,
    sweep_angle=@math.PI,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  canvas.fill_rect(
    0.0,
    0.0,
    2.0,
    2.0,
    @graphics.Paint::new().set_shader(shader),
  )
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 1),
    @graphics.Color::new(r=128, g=0, b=128),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 1),
    @graphics.Color::new(r=191, g=0, b=64),
  )
}

///|
test "Canvas::fill_rect samples multi-stop sweep paint shader" {
  let canvas = @graphics.Canvas::new(2, 2)
  canvas.clear(@graphics.Color::white())
  let shader = @graphics.PaintShader::sweep_gradient_stops(
    cx=0.5,
    cy=0.5,
    start_angle=0.0,
    sweep_angle=@math.PI,
    stops=[
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(
        offset=0.5,
        color=@graphics.Color::green(),
      ),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
  )
  canvas.fill_rect(
    0.0,
    0.0,
    2.0,
    2.0,
    @graphics.Paint::new().set_shader(shader),
  )
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(0, 1), @graphics.Color::green())
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 1),
    @graphics.Color::new(r=128, g=128, b=0),
  )
}

///|
test "Canvas::fill_rect applies paint filter" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::transparent())
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_filter(@graphics.PaintFilter::grayscale())
  canvas.fill_rect(0.0, 0.0, 1.0, 1.0, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=124, g=124, b=124),
  )
}

///|
test "Canvas::fill_rect applies invert paint filter" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::transparent())
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=10, g=20, b=30))
    .set_filter(@graphics.PaintFilter::invert())
  canvas.fill_rect(0.0, 0.0, 1.0, 1.0, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=245, g=235, b=225),
  )
}

///|
test "Canvas::fill_rect applies brightness paint filter" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::transparent())
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_filter(@graphics.PaintFilter::brightness(1.25))
  canvas.fill_rect(0.0, 0.0, 1.0, 1.0, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=250, g=125, b=63),
  )
}

///|
test "Canvas::fill_rect applies contrast paint filter" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::transparent())
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_filter(@graphics.PaintFilter::contrast(0.5))
  canvas.fill_rect(0.0, 0.0, 1.0, 1.0, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=164, g=114, b=89),
  )
}

///|
test "Canvas::fill_rect applies saturate paint filter" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::transparent())
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_filter(@graphics.PaintFilter::saturate(0.5))
  canvas.fill_rect(0.0, 0.0, 1.0, 1.0, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=162, g=112, b=87),
  )
}

///|
test "Canvas::fill_rect applies sepia paint filter" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::transparent())
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_filter(@graphics.PaintFilter::sepia())
  canvas.fill_rect(0.0, 0.0, 1.0, 1.0, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=165, g=147, b=114),
  )
}

///|
test "Canvas::fill_rect applies color-matrix paint filter" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::transparent())
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_filter(
      @graphics.PaintFilter::color_matrix([
        0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]),
    )
  canvas.fill_rect(0.0, 0.0, 1.0, 1.0, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=50, g=100, b=200),
  )
}

///|
test "Canvas::fill_rect applies transform helpers" {
  let canvas = @graphics.Canvas::new(5, 2)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  canvas.translate(tx=1.0, ty=0.0)
  canvas.scale(sx=2.0, sy=1.0)
  canvas.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(2, 0), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(3, 0), @graphics.Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::fill_rect clips transformed rectangles in device space" {
  let canvas = @graphics.Canvas::new(5, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  canvas.set_clip_rect(@graphics.Rect::new(x=2.0, y=0.0, width=1.0, height=1.0))
  canvas.translate(tx=1.0, ty=0.0)
  canvas.scale(sx=3.0, sy=1.0)
  canvas.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(2, 0), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(3, 0), @graphics.Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=0, width=1, height=1)),
  )
}

///|
test "Canvas::fill_path fills rectangular path" {
  let canvas = @graphics.Canvas::new(4, 4)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().add_rect(1.0, 1.0, 2.0, 2.0)
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())
  canvas.fill_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(2, 2), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(3, 3), @graphics.Color::white())
}

///|
test "Canvas::fill_path renders boolean intersections with tight dirty bounds" {
  let canvas = @graphics.Canvas::new(5, 3)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let left = @graphics.Path::new().add_rect(0.0, 0.0, 3.0, 2.0)
  let right = @graphics.Path::new().add_rect(2.0, 1.0, 3.0, 2.0)
  match left.intersection(right) {
    Some(path) => {
      canvas.fill_path(
        path,
        @graphics.Paint::new().set_color(@graphics.Color::black()),
      )
      let pixmap = canvas.get_pixmap()
      assert_eq(pixmap.get_pixel(2, 1), @graphics.Color::black())
      assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::white())
      assert_eq(pixmap.get_pixel(3, 1), @graphics.Color::white())
      assert_eq(pixmap.get_pixel(2, 0), @graphics.Color::white())
      assert_eq(pixmap.get_pixel(2, 2), @graphics.Color::white())
      assert_true(
        canvas.get_dirty_region().bounds() ==
        Some(@graphics.PixelRect::new(x=2, y=1, width=1, height=1)),
      )
    }
    None => abort("expected boolean intersection path")
  }
}

///|
test "Canvas::fill_path renders boolean difference holes" {
  let canvas = @graphics.Canvas::new(5, 5)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let outer = @graphics.Path::new().add_rect(0.0, 0.0, 5.0, 5.0)
  let hole = @graphics.Path::new().add_rect(1.0, 1.0, 3.0, 3.0)
  match outer.difference(hole) {
    Some(path) => {
      canvas.fill_path(
        path,
        @graphics.Paint::new().set_color(@graphics.Color::black()),
      )
      let pixmap = canvas.get_pixmap()
      assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::black())
      assert_eq(pixmap.get_pixel(4, 4), @graphics.Color::black())
      assert_eq(pixmap.get_pixel(2, 0), @graphics.Color::black())
      assert_eq(pixmap.get_pixel(0, 2), @graphics.Color::black())
      assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::white())
      assert_eq(pixmap.get_pixel(2, 2), @graphics.Color::white())
      assert_eq(pixmap.get_pixel(3, 3), @graphics.Color::white())
      assert_true(
        canvas.get_dirty_region().bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=5, height=5)),
      )
    }
    None => abort("expected boolean difference path")
  }
}

///|
test "Canvas::fill_path renders orthogonal boolean unions and intersections" {
  let l_shape = @graphics.Path::new()
    .move_to(0.0, 0.0)
    .line_to(4.0, 0.0)
    .line_to(4.0, 1.0)
    .line_to(1.0, 1.0)
    .line_to(1.0, 4.0)
    .line_to(0.0, 4.0)
    .close()

  let union_canvas = @graphics.Canvas::new(4, 4)
  union_canvas.clear(@graphics.Color::white())
  union_canvas.clear_dirty_region()
  let filler = @graphics.Path::new().add_rect(1.0, 1.0, 3.0, 3.0)
  match l_shape.union(filler) {
    Some(path) => {
      union_canvas.fill_path(
        path,
        @graphics.Paint::new().set_color(@graphics.Color::black()),
      )
      let pixmap = union_canvas.get_pixmap()
      assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::black())
      assert_eq(pixmap.get_pixel(3, 0), @graphics.Color::black())
      assert_eq(pixmap.get_pixel(0, 3), @graphics.Color::black())
      assert_eq(pixmap.get_pixel(3, 3), @graphics.Color::black())
      assert_true(
        union_canvas.get_dirty_region().bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=4)),
      )
    }
    None => abort("expected orthogonal boolean union path")
  }

  let canvas = @graphics.Canvas::new(4, 4)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let clip = @graphics.Path::new().add_rect(0.0, 0.0, 3.0, 3.0)
  match l_shape.intersection(clip) {
    Some(path) => {
      canvas.fill_path(
        path,
        @graphics.Paint::new().set_color(@graphics.Color::black()),
      )
      let pixmap = canvas.get_pixmap()
      assert_eq(pixmap.get_pixel(2, 0), @graphics.Color::black())
      assert_eq(pixmap.get_pixel(0, 2), @graphics.Color::black())
      assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::white())
      assert_eq(pixmap.get_pixel(2, 2), @graphics.Color::white())
      assert_eq(pixmap.get_pixel(3, 0), @graphics.Color::white())
      assert_true(
        canvas.get_dirty_region().bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=3, height=3)),
      )
    }
    None => abort("expected orthogonal boolean intersection path")
  }
}

///|
test "Canvas::fill_path samples paint shader" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  canvas.fill_path(
    @graphics.Path::new().add_rect(0.0, 0.0, 2.0, 1.0),
    @graphics.Paint::new().set_shader(shader),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=191, g=0, b=64),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=64, g=0, b=191),
  )
}

///|
test "Canvas::fill_path applies coverage to sweep paint shader" {
  let canvas = @graphics.Canvas::new(2, 2)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::sweep_gradient(
    cx=0.5,
    cy=0.5,
    start_angle=0.0,
    sweep_angle=@math.PI,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  canvas.fill_path(
    @graphics.Path::new().add_rect(0.0, 0.0, 2.0, 1.5),
    @graphics.Paint::new().set_shader(shader),
  )

  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::red())
  assert_eq(pixmap.get_pixel(0, 1), @graphics.Color::new(r=191, g=127, b=191))
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::new(r=223, g=127, b=159))
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=2)),
  )
}

///|
test "Canvas::fill_path samples shader in device space after transform" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  canvas.set_transform(@graphics.Transform::translate(tx=2.0, ty=0.0))
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=4.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  canvas.fill_path(
    @graphics.Path::new().add_rect(0.0, 0.0, 2.0, 1.0),
    @graphics.Paint::new().set_shader(shader),
  )
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())
  assert_eq(
    canvas.get_pixmap().get_pixel(2, 0),
    @graphics.Color::new(r=96, g=0, b=159),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(3, 0),
    @graphics.Color::new(r=32, g=0, b=223),
  )
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::fill_path samples duplicate-stop gradient hard edge" {
  let canvas = @graphics.Canvas::new(5, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient_stops(
    x0=0.0,
    y0=0.0,
    x1=5.0,
    y1=0.0,
    stops=[
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(offset=0.5, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(
        offset=0.5,
        color=@graphics.Color::blue(),
      ),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
  )
  canvas.fill_path(
    @graphics.Path::new().add_rect(0.0, 0.0, 5.0, 1.0),
    @graphics.Paint::new().set_shader(shader),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::blue())
  assert_eq(canvas.get_pixmap().get_pixel(4, 0), @graphics.Color::blue())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=5, height=1)),
  )
}

///|
test "Canvas::fill_path decal shader tracks tight dirty bounds" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=1.0,
    y0=0.0,
    x1=3.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  canvas.fill_path(
    @graphics.Path::new().add_rect(0.0, 0.0, 4.0, 1.0),
    @graphics.Paint::new().set_shader(shader),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=191, g=0, b=64),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(2, 0),
    @graphics.Color::new(r=64, g=0, b=191),
  )
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::fill_path all-transparent decal shader leaves dirty empty" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=10.0,
    y0=0.0,
    x1=12.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  canvas.fill_path(
    @graphics.Path::new().add_rect(0.0, 0.0, 2.0, 1.0),
    @graphics.Paint::new().set_shader(shader),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::fill_path filters transparent decal shader samples" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=1.0,
    y0=0.0,
    x1=3.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  let reveal_transparent_samples = @graphics.PaintFilter::color_matrix([
    1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 128.0,
  ])
  canvas.fill_path(
    @graphics.Path::new().add_rect(0.0, 0.0, 4.0, 1.0),
    @graphics.Paint::new()
    .set_shader(shader)
    .set_filter(reveal_transparent_samples),
  )

  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=127, g=127, b=127),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=191, g=0, b=64),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(2, 0),
    @graphics.Color::new(r=64, g=0, b=191),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(3, 0),
    @graphics.Color::new(r=127, g=127, b=127),
  )
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=1)),
  )
}

///|
fn make_canvas_shape_alpha_synth_filter() -> @graphics.PaintFilter {
  @graphics.PaintFilter::color_matrix([
    1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 128.0,
  ])
}

///|
test "Canvas::fill_path filters transparent solid source" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  canvas.fill_path(
    @graphics.Path::new().add_rect(0.0, 0.0, 2.0, 1.0),
    @graphics.Paint::new()
    .set_color(@graphics.Color::transparent())
    .set_filter(make_canvas_shape_alpha_synth_filter()),
  )

  let revealed = @graphics.Color::new(r=127, g=127, b=127)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), revealed)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), revealed)
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::fill_path transparent solid source-over leaves dirty empty" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  canvas.fill_path(
    @graphics.Path::new().add_rect(0.0, 0.0, 2.0, 1.0),
    @graphics.Paint::new().set_color(@graphics.Color::transparent()),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::fill_path transparent solid clear stays active" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  canvas.fill_path(
    @graphics.Path::new().add_rect(0.0, 0.0, 2.0, 1.0),
    @graphics.Paint::new()
    .set_color(@graphics.Color::transparent())
    .set_blend_mode(Clear),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::transparent())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::fill_path decal shader keeps transparent-source blends active" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=1.0,
    y0=0.0,
    x1=3.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  canvas.fill_path(
    @graphics.Path::new().add_rect(0.0, 0.0, 4.0, 1.0),
    @graphics.Paint::new().set_shader(shader).set_blend_mode(Clear),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::transparent())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=1)),
  )
}

///|
test "Canvas::fill_path decal shader preserves source-in transparent source" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=1.0,
    y0=0.0,
    x1=3.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  canvas.fill_path(
    @graphics.Path::new().add_rect(0.0, 0.0, 4.0, 1.0),
    @graphics.Paint::new().set_shader(shader).set_blend_mode(SourceIn),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::transparent())
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=191, g=0, b=64),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(2, 0),
    @graphics.Color::new(r=64, g=0, b=191),
  )
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::transparent())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=1)),
  )
}

///|
test "Canvas::fill_path renders rounded rectangles" {
  let canvas = @graphics.Canvas::new(5, 5)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().add_rounded_rect(0.0, 0.0, 5.0, 5.0, 2.0)
  canvas.fill_path(
    path,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = canvas.get_pixmap()
  assert_true(pixmap.get_pixel(0, 0) != @graphics.Color::black())
  assert_eq(pixmap.get_pixel(2, 0), @graphics.Color::black())
  assert_true(pixmap.get_pixel(4, 0) != @graphics.Color::black())
  assert_eq(pixmap.get_pixel(0, 2), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(2, 2), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(4, 2), @graphics.Color::black())
  assert_true(pixmap.get_pixel(0, 4) != @graphics.Color::black())
  assert_eq(pixmap.get_pixel(2, 4), @graphics.Color::black())
}

///|
test "Canvas::fill_rounded_rect matches rounded path fill" {
  let helper_canvas = @graphics.Canvas::new(7, 5)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.clear_dirty_region()
  helper_canvas.set_clip_rect(
    @graphics.Rect::new(x=1.0, y=0.0, width=5.0, height=5.0),
  )
  helper_canvas.translate(tx=1.0, ty=0.0)
  helper_canvas.fill_rounded_rect(
    0.0,
    0.0,
    5.0,
    5.0,
    2.0,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  let path_canvas = @graphics.Canvas::new(7, 5)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.clear_dirty_region()
  path_canvas.set_clip_rect(
    @graphics.Rect::new(x=1.0, y=0.0, width=5.0, height=5.0),
  )
  path_canvas.translate(tx=1.0, ty=0.0)
  path_canvas.fill_path(
    @graphics.Path::new().add_rounded_rect(0.0, 0.0, 5.0, 5.0, 2.0),
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    helper_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(3, 0),
    @graphics.Color::black(),
  )
  assert_true(
    helper_canvas.get_pixmap().get_pixel(1, 0) != @graphics.Color::black(),
  )
}

///|
test "Canvas::fill_rounded_rect_corners matches corner path fill" {
  let helper_canvas = @graphics.Canvas::new(8, 6)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.clear_dirty_region()
  helper_canvas.set_clip_rect(
    @graphics.Rect::new(x=1.0, y=0.0, width=6.0, height=6.0),
  )
  helper_canvas.translate(tx=1.0, ty=0.0)
  helper_canvas.fill_rounded_rect_corners(
    0.0,
    0.0,
    6.0,
    5.0,
    2.0,
    0.0,
    2.0,
    0.0,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  let path_canvas = @graphics.Canvas::new(8, 6)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.clear_dirty_region()
  path_canvas.set_clip_rect(
    @graphics.Rect::new(x=1.0, y=0.0, width=6.0, height=6.0),
  )
  path_canvas.translate(tx=1.0, ty=0.0)
  path_canvas.fill_path(
    @graphics.Path::new().add_rounded_rect_corners(
      0.0, 0.0, 6.0, 5.0, 2.0, 0.0, 2.0, 0.0,
    ),
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    helper_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(4, 2),
    @graphics.Color::black(),
  )
  assert_true(
    helper_canvas.get_pixmap().get_pixel(1, 0) != @graphics.Color::black(),
  )
}

///|
test "Canvas::fill_circle matches circle path fill" {
  let helper_canvas = @graphics.Canvas::new(7, 7)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.clear_dirty_region()
  helper_canvas.set_clip_rect(
    @graphics.Rect::new(x=1.0, y=0.0, width=5.0, height=7.0),
  )
  helper_canvas.translate(tx=1.0, ty=0.0)
  helper_canvas.fill_circle(
    2.0,
    3.0,
    2.0,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  let path_canvas = @graphics.Canvas::new(7, 7)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.clear_dirty_region()
  path_canvas.set_clip_rect(
    @graphics.Rect::new(x=1.0, y=0.0, width=5.0, height=7.0),
  )
  path_canvas.translate(tx=1.0, ty=0.0)
  path_canvas.fill_path(
    @graphics.Path::new().add_circle(2.0, 3.0, 2.0),
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    helper_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(3, 3),
    @graphics.Color::black(),
  )
  assert_true(
    helper_canvas.get_pixmap().get_pixel(1, 1) != @graphics.Color::black(),
  )
}

///|
test "Canvas::fill_ellipse matches ellipse path fill" {
  let helper_canvas = @graphics.Canvas::new(9, 7)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.clear_dirty_region()
  helper_canvas.set_clip_rect(
    @graphics.Rect::new(x=1.0, y=0.0, width=7.0, height=7.0),
  )
  helper_canvas.translate(tx=1.0, ty=0.0)
  helper_canvas.fill_ellipse(
    3.0,
    3.0,
    3.0,
    2.0,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  let path_canvas = @graphics.Canvas::new(9, 7)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.clear_dirty_region()
  path_canvas.set_clip_rect(
    @graphics.Rect::new(x=1.0, y=0.0, width=7.0, height=7.0),
  )
  path_canvas.translate(tx=1.0, ty=0.0)
  path_canvas.fill_path(
    @graphics.Path::new().add_ellipse(3.0, 3.0, 3.0, 2.0),
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    helper_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(4, 3),
    @graphics.Color::black(),
  )
  assert_true(
    helper_canvas.get_pixmap().get_pixel(1, 1) != @graphics.Color::black(),
  )
}

///|
test "Canvas::fill_polygon matches polygon path fill" {
  let points = [
    @graphics.Point::new(x=1.0, y=1.0),
    @graphics.Point::new(x=5.0, y=1.0),
    @graphics.Point::new(x=3.0, y=5.0),
  ]

  let helper_canvas = @graphics.Canvas::new(8, 7)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.clear_dirty_region()
  helper_canvas.set_clip_rect(
    @graphics.Rect::new(x=2.0, y=0.0, width=5.0, height=7.0),
  )
  helper_canvas.translate(tx=1.0, ty=0.0)
  helper_canvas.fill_polygon(
    points,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  let path_canvas = @graphics.Canvas::new(8, 7)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.clear_dirty_region()
  path_canvas.set_clip_rect(
    @graphics.Rect::new(x=2.0, y=0.0, width=5.0, height=7.0),
  )
  path_canvas.translate(tx=1.0, ty=0.0)
  path_canvas.fill_path(
    @graphics.Path::new().add_polygon(points),
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    helper_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
  assert_not_white(helper_canvas.get_pixmap().get_pixel(4, 2))
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(1, 2),
    @graphics.Color::white(),
  )
}

///|
test "Canvas::fill_pie matches pie path fill" {
  let helper_canvas = @graphics.Canvas::new(8, 8)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.clear_dirty_region()
  helper_canvas.set_clip_rect(
    @graphics.Rect::new(x=1.0, y=0.0, width=7.0, height=8.0),
  )
  helper_canvas.translate(tx=1.0, ty=0.0)
  helper_canvas.fill_pie(
    3.0,
    3.0,
    3.0,
    0.0,
    1.5707963267948966,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  let path_canvas = @graphics.Canvas::new(8, 8)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.clear_dirty_region()
  path_canvas.set_clip_rect(
    @graphics.Rect::new(x=1.0, y=0.0, width=7.0, height=8.0),
  )
  path_canvas.translate(tx=1.0, ty=0.0)
  path_canvas.fill_path(
    @graphics.Path::new().add_pie(3.0, 3.0, 3.0, 0.0, 1.5707963267948966),
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    helper_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
  assert_not_white(helper_canvas.get_pixmap().get_pixel(5, 4))
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(1, 1),
    @graphics.Color::white(),
  )
}

///|
test "Canvas::fill_path composites paint opacity" {
  let canvas = @graphics.Canvas::new(2, 2)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().add_rect(0.0, 0.0, 2.0, 2.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_opacity(0.5)
  canvas.fill_path(path, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=127, g=127, b=127, a=255),
  )
}

///|
test "Canvas::fill_path applies paint blend mode" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  let path = @graphics.Path::new().add_rect(0.0, 0.0, 1.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_blend_mode(Multiply)
  canvas.fill_path(path, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=78, g=59, b=39),
  )
}

///|
test "Canvas::fill_path samples shader filter and blend mode" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let paint = @graphics.Paint::new()
    .set_shader(shader)
    .set_filter(@graphics.PaintFilter::invert())
    .set_blend_mode(Multiply)
  canvas.fill_path(@graphics.Path::new().add_rect(0.0, 0.0, 2.0, 1.0), paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::new(r=25, g=150, b=150))
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::new(r=75, g=150, b=50))
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::fill_path clipped-out shader filter blend leaves dirty empty" {
  let canvas = @graphics.Canvas::new(4, 1)
  let background = @graphics.Color::new(r=100, g=150, b=200)
  canvas.clear(background)
  canvas.clear_dirty_region()
  let clip = @graphics.Rect::new(x=3.0, y=0.0, width=1.0, height=1.0)
  canvas.set_clip_rect(clip)
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let paint = @graphics.Paint::new()
    .set_shader(shader)
    .set_filter(@graphics.PaintFilter::invert())
    .set_blend_mode(Multiply)

  canvas.fill_path(@graphics.Path::new().add_rect(0.0, 0.0, 2.0, 1.0), paint)

  assert_true(canvas.get_clip_rect() == Some(clip))
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), background)
  assert_eq(pixmap.get_pixel(1, 0), background)
  assert_eq(pixmap.get_pixel(2, 0), background)
  assert_eq(pixmap.get_pixel(3, 0), background)
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::fill_path uses subpixel coverage" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().add_rect(0.5, 0.0, 0.5, 1.0)
  canvas.fill_path(
    path,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(
    pixmap.get_pixel(0, 0),
    @graphics.Color::new(r=127, g=127, b=127, a=255),
  )
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::white())
}

///|
test "Canvas::fill_path implicitly closes open contours" {
  let canvas = @graphics.Canvas::new(5, 5)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new()
    .move_to(1.0, 1.0)
    .line_to(4.0, 1.0)
    .line_to(4.0, 4.0)
  canvas.fill_path(
    path,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(3, 2), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(1, 3), @graphics.Color::white())
}

///|
test "Canvas::fill_path applies transform" {
  let canvas = @graphics.Canvas::new(4, 4)
  canvas.clear(@graphics.Color::white())
  canvas.set_transform(@graphics.Transform::translate(tx=1.0, ty=1.0))
  let path = @graphics.Path::new().add_rect(0.0, 0.0, 1.0, 1.0)
  canvas.fill_path(
    path,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
}

///|
test "Canvas::fill_path supports even odd holes" {
  let canvas = @graphics.Canvas::new(5, 5)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new()
    .add_rect(0.0, 0.0, 5.0, 5.0)
    .add_rect(1.0, 1.0, 3.0, 3.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_fill_rule(EvenOdd)
  canvas.fill_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(2, 2), @graphics.Color::white())
}

///|
test "Canvas::fill_path supports non-zero reversed-winding holes" {
  let canvas = @graphics.Canvas::new(5, 5)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new()
    .add_rect(0.0, 0.0, 5.0, 5.0)
    .move_to(1.0, 1.0)
    .line_to(1.0, 4.0)
    .line_to(4.0, 4.0)
    .line_to(4.0, 1.0)
    .close()
  canvas.fill_path(
    path,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(2, 2), @graphics.Color::white())
}

///|
test "Canvas::fill_path respects clip rect" {
  let canvas = @graphics.Canvas::new(4, 2)
  canvas.clear(@graphics.Color::white())
  canvas.set_clip_rect(@graphics.Rect::new(x=1.0, y=0.0, width=2.0, height=2.0))
  let path = @graphics.Path::new().add_rect(0.0, 0.0, 4.0, 2.0)
  canvas.fill_path(
    path,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(2, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(3, 1), @graphics.Color::white())
}

///|
test "Canvas::stroke_path draws stroked lines" {
  let canvas = @graphics.Canvas::new(5, 4)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().move_to(0.0, 1.0).line_to(4.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
  canvas.stroke_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(2, 0), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(2, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(2, 3), @graphics.Color::white())
}

///|
test "Canvas::stroke_path ignores normalized empty stroke widths" {
  assert_empty_stroke_width_skips_pixels(0.0)
  assert_empty_stroke_width_skips_pixels(-2.0)
  assert_empty_stroke_width_skips_pixels(0.0 / 0.0)
}

///|
test "Canvas::stroke_path composites paint opacity" {
  let canvas = @graphics.Canvas::new(3, 3)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().move_to(0.0, 1.0).line_to(3.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_opacity(0.5)
  canvas.stroke_path(path, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 1),
    @graphics.Color::new(r=127, g=127, b=127, a=255),
  )
}

///|
test "Canvas::stroke_path transparent source-over leaves dirty empty" {
  let canvas = @graphics.Canvas::new(3, 3)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let path = @graphics.Path::new().move_to(0.0, 1.0).line_to(3.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::transparent())
    .set_style(Stroke)
    .set_stroke_width(2.0)
  canvas.stroke_path(path, paint)

  assert_eq(canvas.get_pixmap().get_pixel(1, 1), @graphics.Color::white())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::stroke_path filters transparent solid source" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::transparent())
    .set_style(Stroke)
    .set_stroke_width(1.0)
    .set_filter(make_canvas_shape_alpha_synth_filter())
  canvas.stroke_path(
    @graphics.Path::new().move_to(0.0, 0.5).line_to(2.0, 0.5),
    paint,
  )

  let revealed = @graphics.Color::new(r=127, g=127, b=127)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), revealed)
  assert_eq(pixmap.get_pixel(1, 0), revealed)
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::stroke_path transparent solid clear stays active" {
  let canvas = @graphics.Canvas::new(3, 3)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let path = @graphics.Path::new().move_to(0.0, 1.0).line_to(3.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::transparent())
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_blend_mode(Clear)
  canvas.stroke_path(path, paint)

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(0, 1), @graphics.Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(1, 1), @graphics.Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(2, 1), @graphics.Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(0, 2), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 2), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(2, 2), @graphics.Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=3, height=2)),
  )
}

///|
test "Canvas::stroke_path applies paint blend mode" {
  let canvas = @graphics.Canvas::new(3, 3)
  canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  let path = @graphics.Path::new().move_to(0.0, 1.0).line_to(3.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::new(r=200, g=100, b=50))
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_blend_mode(Screen)
  canvas.stroke_path(path, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 1),
    @graphics.Color::new(r=222, g=191, b=211),
  )
}

///|
test "Canvas::stroke_path samples paint shader" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let paint = @graphics.Paint::new()
    .set_style(Stroke)
    .set_stroke_width(1.0)
    .set_shader(shader)
  canvas.stroke_line(0.0, 0.5, 2.0, 0.5, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=191, g=0, b=64),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=64, g=0, b=191),
  )
}

///|
test "Canvas::stroke_path samples radial paint shader" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::radial_gradient(
    cx=0.5,
    cy=0.5,
    radius=2.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let paint = @graphics.Paint::new()
    .set_style(Stroke)
    .set_stroke_width(1.0)
    .set_shader(shader)
  canvas.stroke_path(
    @graphics.Path::new().move_to(0.0, 0.5).line_to(2.0, 0.5),
    paint,
  )
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=128, g=0, b=128),
  )
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::stroke_path samples shader in device space after transform" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  canvas.set_transform(@graphics.Transform::translate(tx=2.0, ty=0.0))
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=4.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let paint = @graphics.Paint::new()
    .set_style(Stroke)
    .set_stroke_width(1.0)
    .set_shader(shader)
  canvas.stroke_path(
    @graphics.Path::new().move_to(0.0, 0.5).line_to(2.0, 0.5),
    paint,
  )
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())
  assert_eq(
    canvas.get_pixmap().get_pixel(2, 0),
    @graphics.Color::new(r=96, g=0, b=159),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(3, 0),
    @graphics.Color::new(r=32, g=0, b=223),
  )
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::stroke_path decal shader tracks tight dirty bounds" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=1.0,
    y0=0.0,
    x1=3.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  let paint = @graphics.Paint::new()
    .set_style(Stroke)
    .set_stroke_width(1.0)
    .set_shader(shader)
  canvas.stroke_path(
    @graphics.Path::new().move_to(0.0, 0.5).line_to(4.0, 0.5),
    paint,
  )

  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::new(r=191, g=0, b=64))
  assert_eq(pixmap.get_pixel(2, 0), @graphics.Color::new(r=64, g=0, b=191))
  assert_eq(pixmap.get_pixel(3, 0), @graphics.Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::stroke_path all-transparent decal shader leaves dirty empty" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=10.0,
    y0=0.0,
    x1=12.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  let paint = @graphics.Paint::new()
    .set_style(Stroke)
    .set_stroke_width(1.0)
    .set_shader(shader)
  canvas.stroke_path(
    @graphics.Path::new().move_to(0.0, 0.5).line_to(2.0, 0.5),
    paint,
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::stroke_path filters transparent decal shader samples" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=1.0,
    y0=0.0,
    x1=3.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  let reveal_transparent_samples = @graphics.PaintFilter::color_matrix([
    1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 128.0,
  ])
  let paint = @graphics.Paint::new()
    .set_style(Stroke)
    .set_stroke_width(1.0)
    .set_shader(shader)
    .set_filter(reveal_transparent_samples)
  canvas.stroke_path(
    @graphics.Path::new().move_to(0.0, 0.5).line_to(4.0, 0.5),
    paint,
  )

  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::new(r=127, g=127, b=127))
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::new(r=191, g=0, b=64))
  assert_eq(pixmap.get_pixel(2, 0), @graphics.Color::new(r=64, g=0, b=191))
  assert_eq(pixmap.get_pixel(3, 0), @graphics.Color::new(r=127, g=127, b=127))
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=1)),
  )
}

///|
test "Canvas::stroke_path decal shader keeps transparent-source blends active" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=1.0,
    y0=0.0,
    x1=3.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  let paint = @graphics.Paint::new()
    .set_style(Stroke)
    .set_stroke_width(1.0)
    .set_shader(shader)
    .set_blend_mode(Clear)
  canvas.stroke_path(
    @graphics.Path::new().move_to(0.0, 0.5).line_to(4.0, 0.5),
    paint,
  )

  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::transparent())
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::transparent())
  assert_eq(pixmap.get_pixel(2, 0), @graphics.Color::transparent())
  assert_eq(pixmap.get_pixel(3, 0), @graphics.Color::transparent())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=1)),
  )
}

///|
test "Canvas::stroke_path decal shader preserves source-in transparent source" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=1.0,
    y0=0.0,
    x1=3.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  let paint = @graphics.Paint::new()
    .set_style(Stroke)
    .set_stroke_width(1.0)
    .set_shader(shader)
    .set_blend_mode(SourceIn)
  canvas.stroke_path(
    @graphics.Path::new().move_to(0.0, 0.5).line_to(4.0, 0.5),
    paint,
  )

  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::transparent())
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::new(r=191, g=0, b=64))
  assert_eq(pixmap.get_pixel(2, 0), @graphics.Color::new(r=64, g=0, b=191))
  assert_eq(pixmap.get_pixel(3, 0), @graphics.Color::transparent())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=1)),
  )
}

///|
test "Canvas::stroke_path samples shader filter and blend mode" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::new(r=100, g=150, b=200))
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let paint = @graphics.Paint::new()
    .set_style(Stroke)
    .set_stroke_width(1.0)
    .set_shader(shader)
    .set_filter(@graphics.PaintFilter::invert())
    .set_blend_mode(Multiply)
  canvas.stroke_line(0.0, 0.5, 2.0, 0.5, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::new(r=25, g=150, b=150))
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::new(r=75, g=150, b=50))
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::stroke_path destination blend ignores sampled source" {
  let canvas = @graphics.Canvas::new(2, 1)
  let left = @graphics.Color::new(r=20, g=40, b=60)
  let right = @graphics.Color::new(r=200, g=150, b=100)
  canvas.get_pixmap().set_pixel(0, 0, left)
  canvas.get_pixmap().set_pixel(1, 0, right)
  canvas.clear_dirty_region()
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let paint = @graphics.Paint::new()
    .set_style(Stroke)
    .set_stroke_width(1.0)
    .set_shader(shader)
    .set_filter(@graphics.PaintFilter::invert())
    .set_opacity(0.5)
    .set_blend_mode(Destination)
  canvas.stroke_path(
    @graphics.Path::new().move_to(0.0, 0.5).line_to(2.0, 0.5),
    paint,
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), left)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), right)
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::stroke_path uses subpixel coverage" {
  let canvas = @graphics.Canvas::new(1, 1)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().move_to(0.0, 0.0).line_to(1.0, 0.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(1.0)
  canvas.stroke_path(path, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=127, g=127, b=127, a=255),
  )
}

///|
test "Canvas::stroke_path applies transform" {
  let canvas = @graphics.Canvas::new(4, 4)
  canvas.clear(@graphics.Color::white())
  canvas.set_transform(@graphics.Transform::translate(tx=0.0, ty=1.0))
  let path = @graphics.Path::new().move_to(0.0, 0.0).line_to(3.0, 0.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
  canvas.stroke_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(1, 3), @graphics.Color::white())
}

///|
test "Canvas::stroke_path scales stroke width with transform" {
  let canvas = @graphics.Canvas::new(7, 5)
  canvas.clear(@graphics.Color::white())
  canvas.set_transform(@graphics.Transform::scale(sx=2.0, sy=2.0))
  let path = @graphics.Path::new().move_to(0.0, 1.0).line_to(3.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_stroke_cap(Butt)
  canvas.stroke_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(3, 0), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(3, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(3, 2), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(3, 3), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(3, 4), @graphics.Color::white())
}

///|
test "Canvas::stroke_path uses normal-axis width under non-uniform transform" {
  let canvas = @graphics.Canvas::new(6, 5)
  let background = @graphics.Color::new(r=100, g=150, b=200)
  canvas.clear(background)
  canvas.clear_dirty_region()
  canvas.set_transform(@graphics.Transform::scale(sx=2.0, sy=1.0))
  let path = @graphics.Path::new().move_to(0.0, 2.0).line_to(3.0, 2.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_stroke_cap(Butt)
  canvas.stroke_path(path, paint)

  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(3, 0), background)
  assert_eq(pixmap.get_pixel(3, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(3, 2), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(3, 3), background)
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=1, width=6, height=2)),
  )
}

///|
test "Canvas::stroke_path scales dash metrics with transform" {
  let canvas = @graphics.Canvas::new(9, 5)
  canvas.clear(@graphics.Color::white())
  canvas.set_transform(@graphics.Transform::scale(sx=2.0, sy=2.0))
  let path = @graphics.Path::new().move_to(0.0, 1.0).line_to(4.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_stroke_cap(Butt)
    .set_stroke_dash([2.0, 2.0], 0.0)
  canvas.stroke_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(1, 2), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(3, 2), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(5, 2), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(7, 2), @graphics.Color::white())
}

///|
test "Canvas::stroke_path keeps dash metrics local under non-uniform transform" {
  let canvas = @graphics.Canvas::new(4, 7)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  canvas.set_transform(@graphics.Transform::scale(sx=2.0, sy=1.0))
  let path = @graphics.Path::new().move_to(1.0, 0.0).line_to(1.0, 6.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(1.0)
    .set_stroke_cap(Butt)
    .set_stroke_dash([2.0, 2.0], 0.0)
  canvas.stroke_path(path, paint)

  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(2, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(2, 3), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(2, 5), @graphics.Color::black())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=6)),
  )
}

///|
test "Canvas::stroke_path scales square caps with transform" {
  let canvas = @graphics.Canvas::new(8, 5)
  canvas.clear(@graphics.Color::white())
  canvas.set_transform(@graphics.Transform::scale(sx=2.0, sy=2.0))
  let path = @graphics.Path::new().move_to(1.0, 1.0).line_to(2.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_stroke_cap(Square)
  canvas.stroke_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 2), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(5, 2), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(6, 2), @graphics.Color::white())
}

///|
test "Canvas::stroke_path respects clip rect" {
  let canvas = @graphics.Canvas::new(5, 3)
  canvas.clear(@graphics.Color::white())
  canvas.set_clip_rect(@graphics.Rect::new(x=1.0, y=0.0, width=2.0, height=3.0))
  let path = @graphics.Path::new().move_to(0.0, 1.0).line_to(5.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
  canvas.stroke_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 1), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(2, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(3, 1), @graphics.Color::white())
}

///|
test "Canvas::stroke_line matches line path stroke" {
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)

  let helper_canvas = @graphics.Canvas::new(6, 3)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.clear_dirty_region()
  helper_canvas.stroke_line(0.0, 1.0, 5.0, 1.0, paint)

  let path_canvas = @graphics.Canvas::new(6, 3)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.clear_dirty_region()
  path_canvas.stroke_path(
    @graphics.Path::new().move_to(0.0, 1.0).line_to(5.0, 1.0),
    paint,
  )

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    helper_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(2, 1),
    @graphics.Color::black(),
  )
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(2, 2),
    @graphics.Color::white(),
  )
}

///|
test "Canvas::stroke_line applies transform and clip" {
  let canvas = @graphics.Canvas::new(7, 3)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  canvas.set_clip_rect(@graphics.Rect::new(x=2.0, y=0.0, width=3.0, height=3.0))
  canvas.translate(tx=1.0, ty=0.0)
  canvas.stroke_line(
    0.0,
    1.0,
    5.0,
    1.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0),
  )

  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(2, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(4, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(5, 1), @graphics.Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=0, width=3, height=2)),
  )
}

///|
test "Canvas::stroke_polyline matches polyline path stroke" {
  let points = [
    @graphics.Point::new(x=0.0, y=1.0),
    @graphics.Point::new(x=3.0, y=1.0),
    @graphics.Point::new(x=3.0, y=4.0),
  ]
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(1.0)

  let helper_canvas = @graphics.Canvas::new(6, 6)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.clear_dirty_region()
  helper_canvas.stroke_polyline(points, paint)

  let path_canvas = @graphics.Canvas::new(6, 6)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.clear_dirty_region()
  path_canvas.stroke_path(@graphics.Path::new().add_polyline(points), paint)

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    helper_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
  assert_not_white(helper_canvas.get_pixmap().get_pixel(2, 1))
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(1, 4),
    @graphics.Color::white(),
  )
}

///|
test "Canvas::stroke_circle matches circle path stroke" {
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(1.0)

  let helper_canvas = @graphics.Canvas::new(7, 7)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.clear_dirty_region()
  helper_canvas.stroke_circle(3.0, 3.0, 2.0, paint)

  let path_canvas = @graphics.Canvas::new(7, 7)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.clear_dirty_region()
  path_canvas.stroke_path(
    @graphics.Path::new().add_circle(3.0, 3.0, 2.0),
    paint,
  )

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    helper_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
  assert_not_white(helper_canvas.get_pixmap().get_pixel(3, 1))
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(3, 3),
    @graphics.Color::white(),
  )
}

///|
test "Canvas::stroke_ellipse matches ellipse path stroke" {
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(1.0)

  let helper_canvas = @graphics.Canvas::new(9, 7)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.clear_dirty_region()
  helper_canvas.stroke_ellipse(4.0, 3.0, 3.0, 2.0, paint)

  let path_canvas = @graphics.Canvas::new(9, 7)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.clear_dirty_region()
  path_canvas.stroke_path(
    @graphics.Path::new().add_ellipse(4.0, 3.0, 3.0, 2.0),
    paint,
  )

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    helper_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
  assert_not_white(helper_canvas.get_pixmap().get_pixel(4, 1))
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(4, 3),
    @graphics.Color::white(),
  )
}

///|
test "Canvas::stroke_polygon matches polygon path stroke" {
  let points = [
    @graphics.Point::new(x=1.0, y=1.0),
    @graphics.Point::new(x=7.0, y=1.0),
    @graphics.Point::new(x=4.0, y=7.0),
  ]
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(1.0)

  let helper_canvas = @graphics.Canvas::new(9, 9)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.clear_dirty_region()
  helper_canvas.stroke_polygon(points, paint)

  let path_canvas = @graphics.Canvas::new(9, 9)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.clear_dirty_region()
  path_canvas.stroke_path(@graphics.Path::new().add_polygon(points), paint)

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    helper_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
  assert_not_white(helper_canvas.get_pixmap().get_pixel(4, 1))
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(8, 8),
    @graphics.Color::white(),
  )
}

///|
test "Canvas::stroke_arc matches arc path stroke" {
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(1.0)

  let helper_canvas = @graphics.Canvas::new(8, 8)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.clear_dirty_region()
  helper_canvas.set_clip_rect(
    @graphics.Rect::new(x=1.0, y=0.0, width=7.0, height=8.0),
  )
  helper_canvas.translate(tx=1.0, ty=0.0)
  helper_canvas.stroke_arc(3.0, 3.0, 3.0, 0.0, 1.5707963267948966, paint)

  let path_canvas = @graphics.Canvas::new(8, 8)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.clear_dirty_region()
  path_canvas.set_clip_rect(
    @graphics.Rect::new(x=1.0, y=0.0, width=7.0, height=8.0),
  )
  path_canvas.translate(tx=1.0, ty=0.0)
  path_canvas.stroke_path(
    @graphics.Path::new().add_arc(3.0, 3.0, 3.0, 0.0, 1.5707963267948966),
    paint,
  )

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    helper_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
  assert_not_white(helper_canvas.get_pixmap().get_pixel(7, 3))
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(2, 2),
    @graphics.Color::white(),
  )
}

///|
test "Canvas::stroke_rect matches rectangular path stroke" {
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(1.0)

  let helper_canvas = @graphics.Canvas::new(6, 6)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.clear_dirty_region()
  helper_canvas.stroke_rect(1.0, 1.0, 4.0, 4.0, paint)

  let path_canvas = @graphics.Canvas::new(6, 6)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.clear_dirty_region()
  path_canvas.stroke_path(
    @graphics.Path::new().add_rect(1.0, 1.0, 4.0, 4.0),
    paint,
  )

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    helper_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
  assert_not_white(helper_canvas.get_pixmap().get_pixel(3, 1))
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(3, 3),
    @graphics.Color::white(),
  )
}

///|
test "Canvas::stroke_rect applies transform and clip" {
  let canvas = @graphics.Canvas::new(7, 5)
  canvas.clear(@graphics.Color::white())
  canvas.clear_dirty_region()
  canvas.set_clip_rect(@graphics.Rect::new(x=2.0, y=0.0, width=3.0, height=5.0))
  canvas.translate(tx=1.0, ty=0.0)
  canvas.stroke_rect(
    0.0,
    0.0,
    4.0,
    4.0,
    @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(1.0),
  )

  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::white())
  assert_not_white(pixmap.get_pixel(2, 0))
  assert_not_white(pixmap.get_pixel(4, 0))
  assert_eq(pixmap.get_pixel(5, 0), @graphics.Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=0, width=3, height=5)),
  )
}

///|
test "Canvas::stroke_rounded_rect matches rounded path stroke" {
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(1.0)

  let helper_canvas = @graphics.Canvas::new(7, 7)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.stroke_rounded_rect(1.0, 1.0, 5.0, 5.0, 2.0, paint)

  let path_canvas = @graphics.Canvas::new(7, 7)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.stroke_path(
    @graphics.Path::new().add_rounded_rect(1.0, 1.0, 5.0, 5.0, 2.0),
    paint,
  )

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_not_white(helper_canvas.get_pixmap().get_pixel(3, 1))
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(3, 3),
    @graphics.Color::white(),
  )
}

///|
test "Canvas::stroke_rounded_rect_corners matches corner path stroke" {
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(1.0)

  let helper_canvas = @graphics.Canvas::new(8, 7)
  helper_canvas.clear(@graphics.Color::white())
  helper_canvas.clear_dirty_region()
  helper_canvas.stroke_rounded_rect_corners(
    1.0, 1.0, 6.0, 5.0, 2.0, 0.0, 2.0, 0.0, paint,
  )

  let path_canvas = @graphics.Canvas::new(8, 7)
  path_canvas.clear(@graphics.Color::white())
  path_canvas.clear_dirty_region()
  path_canvas.stroke_path(
    @graphics.Path::new().add_rounded_rect_corners(
      1.0, 1.0, 6.0, 5.0, 2.0, 0.0, 2.0, 0.0,
    ),
    paint,
  )

  assert_same_pixmap(helper_canvas.get_pixmap(), path_canvas.get_pixmap())
  assert_true(
    helper_canvas.get_dirty_region().bounds() ==
    path_canvas.get_dirty_region().bounds(),
  )
  assert_not_white(helper_canvas.get_pixmap().get_pixel(4, 1))
  assert_eq(
    helper_canvas.get_pixmap().get_pixel(4, 3),
    @graphics.Color::white(),
  )
}

///|
test "Canvas::stroke_path uses butt caps by default" {
  let canvas = @graphics.Canvas::new(6, 3)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().move_to(2.0, 1.0).line_to(4.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
  canvas.stroke_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(2, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(4, 1), @graphics.Color::white())
}

///|
test "Canvas::stroke_path supports square caps" {
  let canvas = @graphics.Canvas::new(6, 3)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().move_to(2.0, 1.0).line_to(4.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_stroke_cap(Square)
  canvas.stroke_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_not_white(pixmap.get_pixel(1, 1))
  assert_not_white(pixmap.get_pixel(4, 1))
}

///|
test "Canvas::stroke_path supports round caps" {
  let canvas = @graphics.Canvas::new(6, 3)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().move_to(2.0, 1.0).line_to(4.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_stroke_cap(Round)
  canvas.stroke_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_not_white(pixmap.get_pixel(1, 1))
  assert_eq(pixmap.get_pixel(0, 1), @graphics.Color::white())
  assert_true(pixmap.get_pixel(1, 0) != @graphics.Color::black())
}

///|
test "Canvas::stroke_path round caps keep corners lighter than square caps" {
  let square_canvas = @graphics.Canvas::new(6, 3)
  square_canvas.clear(@graphics.Color::white())
  let round_canvas = @graphics.Canvas::new(6, 3)
  round_canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().move_to(2.0, 1.0).line_to(4.0, 1.0)
  let base = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
  square_canvas.stroke_path(path, base.set_stroke_cap(Square))
  round_canvas.stroke_path(path, base.set_stroke_cap(Round))
  assert_true(
    square_canvas.get_pixmap().get_pixel(1, 0).r <
    round_canvas.get_pixmap().get_pixel(1, 0).r,
  )
}

///|
test "Canvas::stroke_path ignores cap style on closed paths" {
  let butt_canvas = @graphics.Canvas::new(5, 5)
  butt_canvas.clear(@graphics.Color::white())
  let square_canvas = @graphics.Canvas::new(5, 5)
  square_canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new()
    .move_to(1.0, 1.0)
    .line_to(3.0, 1.0)
    .line_to(3.0, 3.0)
    .close()
  let butt_paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
  let square_paint = butt_paint.set_stroke_cap(Square)
  butt_canvas.stroke_path(path, butt_paint)
  square_canvas.stroke_path(path, square_paint)
  assert_same_pixmap(butt_canvas.get_pixmap(), square_canvas.get_pixmap())
}

///|
test "Canvas::stroke_path restores caps for open segments after close" {
  let canvas = @graphics.Canvas::new(8, 5)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new()
    .move_to(2.0, 1.0)
    .line_to(2.0, 3.0)
    .line_to(3.0, 3.0)
    .close()
    .line_to(6.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_stroke_cap(Square)
  canvas.stroke_path(path, paint)
  assert_not_white(canvas.get_pixmap().get_pixel(6, 1))
}

///|
test "Canvas::stroke_path supports round joins" {
  let canvas = @graphics.Canvas::new(6, 6)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new()
    .move_to(1.0, 3.0)
    .line_to(3.0, 3.0)
    .line_to(3.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_stroke_join(Round)
  canvas.stroke_path(path, paint)
  assert_not_white(canvas.get_pixmap().get_pixel(3, 3))
}

///|
test "Canvas::stroke_path round joins cover more outer corner than bevel joins" {
  let bevel_canvas = @graphics.Canvas::new(6, 6)
  bevel_canvas.clear(@graphics.Color::white())
  let round_canvas = @graphics.Canvas::new(6, 6)
  round_canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new()
    .move_to(1.0, 3.0)
    .line_to(3.0, 3.0)
    .line_to(3.0, 1.0)
  let base = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
  bevel_canvas.stroke_path(path, base.set_stroke_join(Bevel))
  round_canvas.stroke_path(path, base.set_stroke_join(Round))
  assert_true(
    round_canvas.get_pixmap().get_pixel(3, 3).r <
    bevel_canvas.get_pixmap().get_pixel(3, 3).r,
  )
}

///|
test "Canvas::stroke_path miter joins extend past bevel joins" {
  let bevel_canvas = @graphics.Canvas::new(6, 6)
  bevel_canvas.clear(@graphics.Color::white())
  let miter_canvas = @graphics.Canvas::new(6, 6)
  miter_canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new()
    .move_to(1.0, 3.0)
    .line_to(3.0, 3.0)
    .line_to(3.0, 1.0)
  let base = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
  bevel_canvas.stroke_path(path, base.set_stroke_join(Bevel))
  miter_canvas.stroke_path(path, base.set_stroke_join(Miter))
  assert_true(
    miter_canvas.get_pixmap().get_pixel(3, 3).r <
    bevel_canvas.get_pixmap().get_pixel(3, 3).r,
  )
}

///|
test "Canvas::stroke_path miter limit falls back to bevel joins" {
  let bevel_canvas = @graphics.Canvas::new(6, 6)
  bevel_canvas.clear(@graphics.Color::white())
  let limited_canvas = @graphics.Canvas::new(6, 6)
  limited_canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new()
    .move_to(1.0, 3.0)
    .line_to(3.0, 3.0)
    .line_to(3.0, 1.0)
  let base = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
  bevel_canvas.stroke_path(path, base.set_stroke_join(Bevel))
  limited_canvas.stroke_path(
    path,
    base.set_stroke_join(Miter).set_miter_limit(1.0),
  )
  assert_same_pixmap(bevel_canvas.get_pixmap(), limited_canvas.get_pixmap())
}

///|
test "Canvas::stroke_path supports dashed strokes" {
  let canvas = @graphics.Canvas::new(9, 3)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().move_to(0.0, 1.0).line_to(8.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_stroke_cap(Butt)
    .set_stroke_dash([2.0, 2.0], 0.0)
  canvas.stroke_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(3, 1), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(5, 1), @graphics.Color::black())
}

///|
test "Canvas::stroke_path applies dash offset" {
  let canvas = @graphics.Canvas::new(6, 3)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new().move_to(0.0, 1.0).line_to(6.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_stroke_cap(Butt)
    .set_stroke_dash([2.0, 2.0], 2.0)
  canvas.stroke_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(3, 1), @graphics.Color::black())
}

///|
test "Canvas::stroke_path resets dash phase at MoveTo" {
  let canvas = @graphics.Canvas::new(7, 3)
  canvas.clear(@graphics.Color::white())
  let path = @graphics.Path::new()
    .move_to(0.0, 1.0)
    .line_to(3.0, 1.0)
    .move_to(3.0, 1.0)
    .line_to(6.0, 1.0)
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::black())
    .set_style(Stroke)
    .set_stroke_width(2.0)
    .set_stroke_cap(Butt)
    .set_stroke_dash([2.0, 2.0], 0.0)
  canvas.stroke_path(path, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(2, 1), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(3, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(4, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(5, 1), @graphics.Color::white())
}

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
