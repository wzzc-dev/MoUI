///|
test "Canvas::draw_mask composites coverage with paint opacity" {
  let canvas = Canvas::new(2, 2)
  canvas.clear(Color::white())
  let mask : FixedArray[Byte] = FixedArray::make(4, 0)
  mask[0] = 0
  mask[1] = 128
  mask[2] = 255
  mask[3] = 64
  let paint = Paint::new().set_color(Color::black()).set_opacity(0.5)
  canvas.draw_mask(0, 0, 2, 2, mask, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::white())
  assert_eq(pixmap.get_pixel(1, 0), Color::new(r=191, g=191, b=191, a=255))
  assert_eq(pixmap.get_pixel(0, 1), Color::new(r=127, g=127, b=127, a=255))
  assert_eq(pixmap.get_pixel(1, 1), Color::new(r=223, g=223, b=223, a=255))
}

///|
test "Canvas::draw_mask applies paint blend mode" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::new(r=100, g=150, b=200))
  let mask : FixedArray[Byte] = FixedArray::make(1, 128)
  let paint = Paint::new()
    .set_color(Color::new(r=200, g=100, b=50))
    .set_blend_mode(BlendMode::Screen)
  canvas.draw_mask(0, 0, 1, 1, mask, paint)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    Color::new(r=161, g=171, b=206),
  )
}

///|
test "Canvas::draw_mask destination blend ignores sampled source" {
  let canvas = Canvas::new(2, 1)
  let left = Color::new(r=20, g=40, b=60)
  let right = Color::new(r=200, g=150, b=100)
  canvas.get_pixmap().set_pixel(0, 0, left)
  canvas.get_pixmap().set_pixel(1, 0, right)
  canvas.clear_dirty_region()
  let mask : FixedArray[Byte] = FixedArray::make(2, 0)
  mask[0] = 255
  mask[1] = 128
  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  let paint = Paint::new()
    .set_shader(shader)
    .set_filter(PaintFilter::invert())
    .set_opacity(0.5)
    .set_blend_mode(BlendMode::Destination)

  canvas.draw_mask(0, 0, 2, 1, mask, paint)

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), left)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), right)
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::draw_pixmap destination blend ignores filtered source" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::red())

  canvas.draw_pixmap(
    src,
    0,
    0,
    Paint::new()
    .set_filter(PaintFilter::invert())
    .set_opacity(0.5)
    .set_blend_mode(BlendMode::Destination),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::white())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::draw_mask transparent source-over leaves dirty empty" {
  let canvas = Canvas::new(2, 1)
  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  let mask : FixedArray[Byte] = FixedArray::make(2, 255)
  canvas.draw_mask(
    0,
    0,
    2,
    1,
    mask,
    Paint::new().set_color(Color::transparent()),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::draw_mask excludes masked alpha zero from dirty bounds" {
  let canvas = Canvas::new(2, 1)
  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  let mask : FixedArray[Byte] = FixedArray::make(2, 0)
  mask[0] = 1
  mask[1] = 255
  canvas.draw_mask(
    0,
    0,
    2,
    1,
    mask,
    Paint::new().set_color(Color::new(r=0, g=0, b=0, a=1)),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    Color::new(r=254, g=254, b=254),
  )
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
}

///|
test "Canvas::draw_mask keeps transparent-source blends active" {
  let canvas = Canvas::new(2, 1)
  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  let mask : FixedArray[Byte] = FixedArray::make(2, 255)
  canvas.draw_mask(
    0,
    0,
    2,
    1,
    mask,
    Paint::new()
    .set_color(Color::transparent())
    .set_blend_mode(BlendMode::Clear),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), Color::transparent())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::draw_mask samples paint shader" {
  let canvas = Canvas::new(2, 1)
  canvas.clear(Color::white())
  let mask : FixedArray[Byte] = FixedArray::make(2, 255)
  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  canvas.draw_mask(0, 0, 2, 1, mask, Paint::new().set_shader(shader))
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::new(r=191, g=0, b=64))
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), Color::new(r=64, g=0, b=191))
}

///|
test "Canvas::draw_mask applies paint filter" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::transparent())
  let mask : FixedArray[Byte] = FixedArray::make(1, 255)
  let paint = Paint::new()
    .set_color(Color::new(r=100, g=50, b=200))
    .set_filter(PaintFilter::modulate(Color::new(r=0, g=255, b=128)))
  canvas.draw_mask(0, 0, 1, 1, mask, paint)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::new(r=0, g=50, b=100))
}

///|
test "Canvas::draw_mask samples shader filter and blend mode" {
  let canvas = Canvas::new(3, 1)
  let dst = Color::new(r=120, g=80, b=200)
  canvas.clear(dst)
  canvas.clear_dirty_region()
  let mask : FixedArray[Byte] = FixedArray::make(3, 0)
  mask[0] = 255
  mask[2] = 128
  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=3.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  let paint = Paint::new()
    .set_shader(shader)
    .set_filter(PaintFilter::invert())
    .set_blend_mode(BlendMode::Multiply)

  canvas.draw_mask(0, 0, 3, 1, mask, paint)

  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::new(r=20, g=80, b=166))
  assert_eq(pixmap.get_pixel(1, 0), dst)
  assert_eq(pixmap.get_pixel(2, 0), Color::new(r=110, g=80, b=116))
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=0, y=0, width=3, height=1)),
  )
}

///|
test "Canvas::draw_mask_rect composites atlas source rect" {
  let canvas = Canvas::new(3, 2)
  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  let mask : FixedArray[Byte] = FixedArray::make(6, 0)
  mask[0] = 255
  mask[1] = 128
  mask[2] = 0
  mask[3] = 64
  mask[4] = 255
  mask[5] = 0
  canvas.draw_mask_rect(
    1,
    0,
    3,
    2,
    mask,
    PixelRect::new(x=1, y=0, width=2, height=2),
    Paint::new().set_color(Color::black()),
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::white())
  assert_eq(pixmap.get_pixel(1, 0), Color::new(r=127, g=127, b=127, a=255))
  assert_eq(pixmap.get_pixel(2, 0), Color::white())
  assert_eq(pixmap.get_pixel(1, 1), Color::black())
  assert_eq(pixmap.get_pixel(2, 1), Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=2)),
  )
}

///|
test "Canvas::draw_mask_rect transparent source-over leaves dirty empty" {
  let canvas = Canvas::new(2, 1)
  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  let mask : FixedArray[Byte] = FixedArray::make(4, 255)
  canvas.draw_mask_rect(
    0,
    0,
    4,
    1,
    mask,
    PixelRect::new(x=1, y=0, width=2, height=1),
    Paint::new().set_color(Color::transparent()),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::draw_mask_rect keeps transparent-source blends active" {
  let canvas = Canvas::new(2, 1)
  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  let mask : FixedArray[Byte] = FixedArray::make(4, 255)
  canvas.draw_mask_rect(
    0,
    0,
    4,
    1,
    mask,
    PixelRect::new(x=1, y=0, width=2, height=1),
    Paint::new()
    .set_color(Color::transparent())
    .set_blend_mode(BlendMode::Clear),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), Color::transparent())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::draw_mask_rect samples shader filter and blend mode" {
  let canvas = Canvas::new(2, 1)
  canvas.clear(Color::new(r=10, g=20, b=30))
  let mask : FixedArray[Byte] = FixedArray::make(4, 0)
  mask[1] = 255
  mask[2] = 255
  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  let paint = Paint::new()
    .set_shader(shader)
    .set_filter(PaintFilter::modulate(Color::new(r=255, g=255, b=128)))
    .set_blend_mode(BlendMode::Add)
  canvas.draw_mask_rect(
    0,
    0,
    4,
    1,
    mask,
    PixelRect::new(x=1, y=0, width=2, height=1),
    paint,
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::new(r=201, g=20, b=62))
  assert_eq(pixmap.get_pixel(1, 0), Color::new(r=74, g=20, b=126))
}

///|
test "Canvas tracks dirty region for pixel and sampled pixmap" {
  let canvas = Canvas::new(4, 2)
  canvas.draw_pixel(3, 1, Color::red())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=3, y=1, width=1, height=1)),
  )
  canvas.clear_dirty_region()
  canvas.set_clip_rect(Rect::new(x=1.0, y=0.0, width=2.0, height=2.0))
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::blue())
  canvas.draw_sampled_pixmap(
    src,
    0,
    0,
    4,
    2,
    Paint::new(),
    ImageSampling::Nearest,
  )
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=1, y=0, width=2, height=2)),
  )
}

///|
test "Canvas::draw_mask ignores stroke paint" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::white())
  let mask : FixedArray[Byte] = FixedArray::make(1, 255)
  let paint = Paint::new()
    .set_color(Color::black())
    .set_style(PaintStyle::Stroke)
  canvas.draw_mask(0, 0, 1, 1, mask, paint)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::white())
}

///|
test "Canvas::draw_mask respects clip rect" {
  let canvas = Canvas::new(3, 1)
  canvas.clear(Color::white())
  canvas.set_clip_rect(Rect::new(x=1.0, y=0.0, width=1.0, height=1.0))
  let mask : FixedArray[Byte] = FixedArray::make(3, 255)
  let paint = Paint::new().set_color(Color::black())
  canvas.draw_mask(0, 0, 3, 1, mask, paint)
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::white())
  assert_eq(pixmap.get_pixel(1, 0), Color::black())
  assert_eq(pixmap.get_pixel(2, 0), Color::white())
}

///|
test "Canvas::draw_pixmap composites source pixels" {
  let canvas = Canvas::new(2, 1)
  canvas.clear(Color::white())
  let src = Pixmap::new(2, 1)
  src.set_pixel(0, 0, Color::new(r=255, g=0, b=0, a=128))
  src.set_pixel(1, 0, Color::blue())
  canvas.draw_pixmap(src, 0, 0, Paint::new())
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::new(r=255, g=127, b=127, a=255))
  assert_eq(pixmap.get_pixel(1, 0), Color::blue())
}

///|
test "Canvas::draw_pixmap applies paint blend mode" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::new(r=100, g=150, b=200))
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::new(r=200, g=100, b=50))
  canvas.draw_pixmap(src, 0, 0, Paint::new().set_blend_mode(BlendMode::Add))
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    Color::new(r=255, g=250, b=250),
  )
}

///|
test "Canvas::draw_pixmap applies clear to transparent source pixels" {
  let canvas = Canvas::new(2, 1)
  canvas.get_pixmap().set_pixel(0, 0, Color::new(r=10, g=20, b=30))
  canvas.get_pixmap().set_pixel(1, 0, Color::new(r=40, g=50, b=60))
  let src = Pixmap::new(2, 1)
  src.set_pixel(0, 0, Color::transparent())
  src.set_pixel(1, 0, Color::new(r=200, g=100, b=50, a=128))
  canvas.draw_pixmap(src, 0, 0, Paint::new().set_blend_mode(BlendMode::Clear))
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::transparent())
  assert_eq(pixmap.get_pixel(1, 0), Color::transparent())
}

///|
test "Canvas::draw_pixmap applies paint filter" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::transparent())
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::new(r=100, g=80, b=40))
  let paint = Paint::new().set_filter(
    PaintFilter::modulate(Color::new(r=0, g=255, b=128)),
  )
  canvas.draw_pixmap(src, 0, 0, paint)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::new(r=0, g=80, b=20))
}

///|
test "Canvas::draw_pixmap respects clip rect and paint opacity" {
  let canvas = Canvas::new(3, 1)
  canvas.clear(Color::white())
  canvas.set_clip_rect(Rect::new(x=1.0, y=0.0, width=1.0, height=1.0))
  let src = Pixmap::new(3, 1)
  src.set_pixel(0, 0, Color::red())
  src.set_pixel(1, 0, Color::blue())
  src.set_pixel(2, 0, Color::green())
  canvas.draw_pixmap(src, 0, 0, Paint::new().set_opacity(0.5))
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::white())
  assert_eq(pixmap.get_pixel(1, 0), Color::new(r=127, g=127, b=255, a=255))
  assert_eq(pixmap.get_pixel(2, 0), Color::white())
}

///|
test "Canvas::draw_pixmap ignores stroke paint" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::white())
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::black())
  canvas.draw_pixmap(src, 0, 0, Paint::new().set_style(PaintStyle::Stroke))
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::white())
}

///|
test "Canvas::draw_scaled_pixmap scales source pixels" {
  let canvas = Canvas::new(4, 2)
  canvas.clear(Color::white())
  let src = Pixmap::new(2, 1)
  src.set_pixel(0, 0, Color::red())
  src.set_pixel(1, 0, Color::blue())
  canvas.draw_scaled_pixmap(src, 0, 0, 4, 2, Paint::new())
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::red())
  assert_eq(pixmap.get_pixel(1, 1), Color::red())
  assert_eq(pixmap.get_pixel(2, 0), Color::blue())
  assert_eq(pixmap.get_pixel(3, 1), Color::blue())
}

///|
test "Canvas::draw_scaled_pixmap applies paint blend mode" {
  let canvas = Canvas::new(2, 1)
  canvas.clear(Color::new(r=100, g=150, b=200))
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::new(r=200, g=100, b=50))
  canvas.draw_scaled_pixmap(
    src,
    0,
    0,
    2,
    1,
    Paint::new().set_blend_mode(BlendMode::Multiply),
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::new(r=78, g=59, b=39))
  assert_eq(pixmap.get_pixel(1, 0), Color::new(r=78, g=59, b=39))
}

///|
test "Canvas::draw_scaled_pixmap skips dirty for transparent source-over no-op" {
  let canvas = Canvas::new(2, 1)
  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::transparent())

  canvas.draw_scaled_pixmap(src, 0, 0, 2, 1, Paint::new())

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::draw_scaled_pixmap clears transparent source pixels" {
  let canvas = Canvas::new(2, 1)
  canvas.clear(Color::new(r=10, g=20, b=30))
  canvas.clear_dirty_region()
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::transparent())

  canvas.draw_scaled_pixmap(
    src,
    0,
    0,
    2,
    1,
    Paint::new().set_blend_mode(BlendMode::Clear),
  )

  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::transparent())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), Color::transparent())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::scaled and sampled pixmaps keep transparent-source DestinationIn active" {
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::transparent())
  let paint = Paint::new().set_blend_mode(BlendMode::DestinationIn)

  let nearest = Canvas::new(1, 1)
  nearest.clear(Color::white())
  nearest.clear_dirty_region()
  nearest.draw_scaled_pixmap(src, 0, 0, 1, 1, paint)
  assert_eq(nearest.get_pixmap().get_pixel(0, 0), Color::transparent())
  assert_true(
    nearest.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )

  let bilinear = Canvas::new(1, 1)
  bilinear.clear(Color::white())
  bilinear.clear_dirty_region()
  bilinear.draw_scaled_pixmap_bilinear(src, 0, 0, 1, 1, paint)
  assert_eq(bilinear.get_pixmap().get_pixel(0, 0), Color::transparent())
  assert_true(
    bilinear.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )

  let bicubic = Canvas::new(1, 1)
  bicubic.clear(Color::white())
  bicubic.clear_dirty_region()
  bicubic.draw_scaled_pixmap_bicubic(src, 0, 0, 1, 1, paint)
  assert_eq(bicubic.get_pixmap().get_pixel(0, 0), Color::transparent())
  assert_true(
    bicubic.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )

  let sampled_rect = Canvas::new(1, 1)
  sampled_rect.clear(Color::white())
  sampled_rect.clear_dirty_region()
  sampled_rect.draw_sampled_pixmap_rect(
    src,
    PixelRect::new(x=0, y=0, width=1, height=1),
    0,
    0,
    1,
    1,
    paint,
    ImageSampling::Bicubic,
  )
  assert_eq(sampled_rect.get_pixmap().get_pixel(0, 0), Color::transparent())
  assert_true(
    sampled_rect.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
}

///|
test "Canvas::sampled pixmaps destination blend leaves dirty empty" {
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::red())
  let paint = Paint::new()
    .set_filter(PaintFilter::invert())
    .set_opacity(0.5)
    .set_blend_mode(BlendMode::Destination)

  let nearest = Canvas::new(2, 1)
  nearest.clear(Color::white())
  nearest.clear_dirty_region()
  nearest.draw_scaled_pixmap(src, 0, 0, 2, 1, paint)
  assert_eq(nearest.get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(nearest.get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(nearest.get_dirty_region().is_empty())

  let bilinear = Canvas::new(2, 1)
  bilinear.clear(Color::white())
  bilinear.clear_dirty_region()
  bilinear.draw_scaled_pixmap_bilinear(src, 0, 0, 2, 1, paint)
  assert_eq(bilinear.get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(bilinear.get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(bilinear.get_dirty_region().is_empty())

  let bicubic = Canvas::new(2, 1)
  bicubic.clear(Color::white())
  bicubic.clear_dirty_region()
  bicubic.draw_scaled_pixmap_bicubic(src, 0, 0, 2, 1, paint)
  assert_eq(bicubic.get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(bicubic.get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(bicubic.get_dirty_region().is_empty())

  let sampled_rect = Canvas::new(2, 1)
  sampled_rect.clear(Color::white())
  sampled_rect.clear_dirty_region()
  sampled_rect.draw_sampled_pixmap_rect(
    src,
    PixelRect::new(x=0, y=0, width=1, height=1),
    0,
    0,
    2,
    1,
    paint,
    ImageSampling::Bicubic,
  )
  assert_eq(sampled_rect.get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(sampled_rect.get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(sampled_rect.get_dirty_region().is_empty())
}

///|
test "Canvas::draw_scaled_pixmap applies paint filter" {
  let canvas = Canvas::new(2, 1)
  canvas.clear(Color::transparent())
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::new(r=100, g=80, b=40))
  let paint = Paint::new().set_filter(
    PaintFilter::modulate(Color::new(r=0, g=255, b=128)),
  )
  canvas.draw_scaled_pixmap(src, 0, 0, 2, 1, paint)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::new(r=0, g=80, b=20))
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), Color::new(r=0, g=80, b=20))
}

///|
test "Canvas::draw_scaled_pixmap respects clip rect and opacity" {
  let canvas = Canvas::new(4, 1)
  canvas.clear(Color::white())
  canvas.set_clip_rect(Rect::new(x=1.0, y=0.0, width=2.0, height=1.0))
  let src = Pixmap::new(2, 1)
  src.set_pixel(0, 0, Color::red())
  src.set_pixel(1, 0, Color::blue())
  canvas.draw_scaled_pixmap(src, 0, 0, 4, 1, Paint::new().set_opacity(0.5))
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::white())
  assert_eq(pixmap.get_pixel(1, 0), Color::new(r=255, g=127, b=127, a=255))
  assert_eq(pixmap.get_pixel(2, 0), Color::new(r=127, g=127, b=255, a=255))
  assert_eq(pixmap.get_pixel(3, 0), Color::white())
}

///|
test "Canvas::draw_scaled_pixmap ignores stroke paint and invalid size" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::white())
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::black())
  canvas.draw_scaled_pixmap(
    src,
    0,
    0,
    1,
    1,
    Paint::new().set_style(PaintStyle::Stroke),
  )
  canvas.draw_scaled_pixmap(src, 0, 0, 0, 1, Paint::new())
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::white())
}

///|
test "Canvas::draw_scaled_pixmap_bilinear interpolates source pixels" {
  let canvas = Canvas::new(3, 3)
  let src = Pixmap::new(2, 2)
  src.set_pixel(0, 0, Color::red())
  src.set_pixel(1, 0, Color::green())
  src.set_pixel(0, 1, Color::blue())
  src.set_pixel(1, 1, Color::white())
  canvas.draw_scaled_pixmap_bilinear(src, 0, 0, 3, 3, Paint::new())
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::red())
  assert_eq(pixmap.get_pixel(2, 0), Color::green())
  assert_eq(pixmap.get_pixel(1, 1), Color::new(r=128, g=128, b=128, a=255))
}

///|
test "Canvas::draw_scaled_pixmap_bilinear respects clip rect and opacity" {
  let canvas = Canvas::new(4, 1)
  canvas.clear(Color::white())
  canvas.set_clip_rect(Rect::new(x=1.0, y=0.0, width=2.0, height=1.0))
  let src = Pixmap::new(2, 1)
  src.set_pixel(0, 0, Color::red())
  src.set_pixel(1, 0, Color::blue())
  canvas.draw_scaled_pixmap_bilinear(
    src,
    0,
    0,
    4,
    1,
    Paint::new().set_opacity(0.5),
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::white())
  assert_eq(pixmap.get_pixel(1, 0), Color::new(r=223, g=127, b=159, a=255))
  assert_eq(pixmap.get_pixel(2, 0), Color::new(r=159, g=127, b=223, a=255))
  assert_eq(pixmap.get_pixel(3, 0), Color::white())
}

///|
test "Canvas::draw_scaled_pixmap_bicubic interpolates source pixels" {
  let canvas = Canvas::new(3, 1)
  let src = make_canvas_test_bicubic_source()
  canvas.draw_scaled_pixmap_bicubic(src, 0, 0, 3, 1, Paint::new())
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::new(r=34, g=0, b=0, a=255))
  assert_eq(pixmap.get_pixel(1, 0), Color::new(r=128, g=0, b=0, a=255))
  assert_eq(pixmap.get_pixel(2, 0), Color::new(r=221, g=0, b=0, a=255))
}

///|
test "Canvas::draw_scaled_pixmap_bilinear ignores stroke paint and invalid size" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::white())
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::black())
  canvas.draw_scaled_pixmap_bilinear(
    src,
    0,
    0,
    1,
    1,
    Paint::new().set_style(PaintStyle::Stroke),
  )
  canvas.draw_scaled_pixmap_bilinear(src, 0, 0, 0, 1, Paint::new())
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::white())
}

///|
test "Canvas::draw_sampled_pixmap dispatches sampling modes" {
  let src = make_canvas_test_bicubic_source()
  let nearest = Canvas::new(3, 1)
  let bilinear = Canvas::new(3, 1)
  let bicubic = Canvas::new(3, 1)
  nearest.draw_sampled_pixmap(
    src,
    0,
    0,
    3,
    1,
    Paint::new(),
    ImageSampling::Nearest,
  )
  bilinear.draw_sampled_pixmap(
    src,
    0,
    0,
    3,
    1,
    Paint::new(),
    ImageSampling::Bilinear,
  )
  bicubic.draw_sampled_pixmap(
    src,
    0,
    0,
    3,
    1,
    Paint::new(),
    ImageSampling::Bicubic,
  )
  assert_eq(nearest.get_pixmap().get_pixel(1, 0), Color::black())
  assert_eq(
    bilinear.get_pixmap().get_pixel(1, 0),
    Color::new(r=128, g=0, b=0, a=255),
  )
  assert_eq(
    bicubic.get_pixmap().get_pixel(0, 0),
    Color::new(r=34, g=0, b=0, a=255),
  )
}

///|
test "Canvas::draw_quality_pixmap dispatches quality strategies" {
  let src = make_canvas_test_bicubic_source()
  let fast = Canvas::new(3, 1)
  let balanced = Canvas::new(3, 1)
  let high = Canvas::new(3, 1)
  fast.draw_quality_pixmap(src, 0, 0, 3, 1, Paint::new(), ImageQuality::Fast)
  balanced.draw_quality_pixmap(
    src,
    0,
    0,
    3,
    1,
    Paint::new(),
    ImageQuality::Balanced,
  )
  high.draw_quality_pixmap(src, 0, 0, 3, 1, Paint::new(), ImageQuality::High)
  assert_eq(fast.get_pixmap().get_pixel(1, 0), Color::black())
  assert_eq(
    balanced.get_pixmap().get_pixel(1, 0),
    Color::new(r=128, g=0, b=0, a=255),
  )
  assert_eq(
    high.get_pixmap().get_pixel(0, 0),
    Color::new(r=34, g=0, b=0, a=255),
  )
}

///|
test "Canvas::draw_scaled_pixmap_rect scales atlas region" {
  let canvas = Canvas::new(4, 2)
  canvas.clear(Color::white())
  let src = Pixmap::new(4, 1)
  src.set_pixel(0, 0, Color::black())
  src.set_pixel(1, 0, Color::red())
  src.set_pixel(2, 0, Color::blue())
  src.set_pixel(3, 0, Color::green())
  canvas.draw_scaled_pixmap_rect(
    src,
    PixelRect::new(x=1, y=0, width=2, height=1),
    0,
    0,
    4,
    2,
    Paint::new(),
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::red())
  assert_eq(pixmap.get_pixel(1, 1), Color::red())
  assert_eq(pixmap.get_pixel(2, 0), Color::blue())
  assert_eq(pixmap.get_pixel(3, 1), Color::blue())
}

///|
test "Canvas::draw_scaled_pixmap_rect respects clip opacity and dirty region" {
  let canvas = Canvas::new(4, 1)
  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  canvas.set_clip_rect(Rect::new(x=1.0, y=0.0, width=2.0, height=1.0))
  let src = Pixmap::new(4, 1)
  src.set_pixel(0, 0, Color::red())
  src.set_pixel(1, 0, Color::green())
  src.set_pixel(2, 0, Color::blue())
  src.set_pixel(3, 0, Color::black())
  canvas.draw_scaled_pixmap_rect(
    src,
    PixelRect::new(x=1, y=0, width=2, height=1),
    0,
    0,
    4,
    1,
    Paint::new().set_opacity(0.5),
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::white())
  assert_eq(pixmap.get_pixel(1, 0), Color::new(r=127, g=255, b=127, a=255))
  assert_eq(pixmap.get_pixel(2, 0), Color::new(r=127, g=127, b=255, a=255))
  assert_eq(pixmap.get_pixel(3, 0), Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
}

///|
test "Canvas::draw_scaled_pixmap_rect_bilinear samples source rect" {
  let canvas = Canvas::new(3, 1)
  let src = Pixmap::new(4, 1)
  src.set_pixel(0, 0, Color::white())
  src.set_pixel(1, 0, Color::red())
  src.set_pixel(2, 0, Color::blue())
  src.set_pixel(3, 0, Color::white())
  canvas.draw_scaled_pixmap_rect_bilinear(
    src,
    PixelRect::new(x=1, y=0, width=2, height=1),
    0,
    0,
    3,
    1,
    Paint::new(),
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::red())
  assert_eq(pixmap.get_pixel(1, 0), Color::new(r=128, g=0, b=128, a=255))
  assert_eq(pixmap.get_pixel(2, 0), Color::blue())
}

///|
test "Canvas::draw_scaled_pixmap_rect_bicubic samples source rect" {
  let canvas = Canvas::new(3, 1)
  let src = make_canvas_test_bicubic_rect_source()
  canvas.draw_scaled_pixmap_rect_bicubic(
    src,
    PixelRect::new(x=1, y=0, width=4, height=1),
    0,
    0,
    3,
    1,
    Paint::new(),
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::new(r=34, g=0, b=0, a=255))
  assert_eq(pixmap.get_pixel(1, 0), Color::new(r=128, g=0, b=0, a=255))
  assert_eq(pixmap.get_pixel(2, 0), Color::new(r=221, g=0, b=0, a=255))
}

///|
test "Canvas::draw_sampled_pixmap_rect dispatches sampling modes" {
  let src = make_canvas_test_bicubic_rect_source()
  let nearest = Canvas::new(3, 1)
  let bilinear = Canvas::new(3, 1)
  let bicubic = Canvas::new(3, 1)
  let rect = PixelRect::new(x=1, y=0, width=4, height=1)
  nearest.draw_sampled_pixmap_rect(
    src,
    rect,
    0,
    0,
    3,
    1,
    Paint::new(),
    ImageSampling::Nearest,
  )
  bilinear.draw_sampled_pixmap_rect(
    src,
    rect,
    0,
    0,
    3,
    1,
    Paint::new(),
    ImageSampling::Bilinear,
  )
  bicubic.draw_sampled_pixmap_rect(
    src,
    rect,
    0,
    0,
    3,
    1,
    Paint::new(),
    ImageSampling::Bicubic,
  )
  assert_eq(nearest.get_pixmap().get_pixel(1, 0), Color::black())
  assert_eq(
    bilinear.get_pixmap().get_pixel(1, 0),
    Color::new(r=128, g=0, b=0, a=255),
  )
  assert_eq(
    bicubic.get_pixmap().get_pixel(0, 0),
    Color::new(r=34, g=0, b=0, a=255),
  )
}

///|
test "Canvas::draw_quality_pixmap_rect dispatches quality strategies" {
  let src = make_canvas_test_bicubic_rect_source()
  let fast = Canvas::new(3, 1)
  let balanced = Canvas::new(3, 1)
  let high = Canvas::new(3, 1)
  let rect = PixelRect::new(x=1, y=0, width=4, height=1)
  fast.draw_quality_pixmap_rect(
    src,
    rect,
    0,
    0,
    3,
    1,
    Paint::new(),
    ImageQuality::Fast,
  )
  balanced.draw_quality_pixmap_rect(
    src,
    rect,
    0,
    0,
    3,
    1,
    Paint::new(),
    ImageQuality::Balanced,
  )
  high.draw_quality_pixmap_rect(
    src,
    rect,
    0,
    0,
    3,
    1,
    Paint::new(),
    ImageQuality::High,
  )
  assert_eq(fast.get_pixmap().get_pixel(1, 0), Color::black())
  assert_eq(
    balanced.get_pixmap().get_pixel(1, 0),
    Color::new(r=128, g=0, b=0, a=255),
  )
  assert_eq(
    high.get_pixmap().get_pixel(0, 0),
    Color::new(r=34, g=0, b=0, a=255),
  )
}

///|
test "Canvas::draw_sampled_pixmap_rect ignores stroke paint and invalid size" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::white())
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::black())
  let rect = PixelRect::new(x=0, y=0, width=1, height=1)
  canvas.draw_sampled_pixmap_rect(
    src,
    rect,
    0,
    0,
    1,
    1,
    Paint::new().set_style(PaintStyle::Stroke),
    ImageSampling::Nearest,
  )
  canvas.draw_sampled_pixmap_rect(
    src,
    rect,
    0,
    0,
    0,
    1,
    Paint::new(),
    ImageSampling::Nearest,
  )
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::white())
}

///|
test "Canvas::draw_transformed_sampled_pixmap_rect applies transform and clip" {
  let canvas = Canvas::new(5, 3)
  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  canvas.set_transform(
    Transform::translate(tx=1.0, ty=1.0).multiply(
      Transform::scale(sx=2.0, sy=1.0),
    ),
  )
  canvas.set_clip_rect(Rect::new(x=2.0, y=1.0, width=2.0, height=1.0))
  let src = Pixmap::new(2, 1)
  src.set_pixel(0, 0, Color::red())
  src.set_pixel(1, 0, Color::blue())
  canvas.draw_transformed_sampled_pixmap_rect(
    src,
    PixelRect::new(x=0, y=0, width=2, height=1),
    0.0,
    0.0,
    2.0,
    1.0,
    Paint::new(),
    ImageSampling::Nearest,
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(1, 1), Color::white())
  assert_eq(pixmap.get_pixel(2, 1), Color::red())
  assert_eq(pixmap.get_pixel(3, 1), Color::blue())
  assert_eq(pixmap.get_pixel(4, 1), Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=2, y=1, width=2, height=1)),
  )
}

///|
test "Canvas::draw_transformed_sampled_pixmap_rect maps rotation" {
  let canvas = Canvas::new(3, 3)
  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  canvas.set_transform(
    Transform::translate(tx=2.0, ty=0.0).multiply(
      Transform::rotate(1.5707963267948966),
    ),
  )
  let src = Pixmap::new(2, 1)
  src.set_pixel(0, 0, Color::red())
  src.set_pixel(1, 0, Color::blue())
  canvas.draw_transformed_sampled_pixmap_rect(
    src,
    PixelRect::new(x=0, y=0, width=2, height=1),
    0.0,
    0.0,
    2.0,
    1.0,
    Paint::new(),
    ImageSampling::Nearest,
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::white())
  assert_eq(pixmap.get_pixel(1, 0), Color::red())
  assert_eq(pixmap.get_pixel(1, 1), Color::blue())
  assert_eq(pixmap.get_pixel(2, 0), Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=2)),
  )
}

///|
test "Canvas::draw_transformed_sampled_pixmap_rect supports bilinear sampling" {
  let canvas = Canvas::new(5, 1)
  canvas.clear(Color::white())
  canvas.set_transform(Transform::translate(tx=1.0, ty=0.0))
  let src = Pixmap::new(2, 1)
  src.set_pixel(0, 0, Color::red())
  src.set_pixel(1, 0, Color::blue())
  canvas.draw_transformed_sampled_pixmap_rect(
    src,
    PixelRect::new(x=0, y=0, width=2, height=1),
    0.0,
    0.0,
    3.0,
    1.0,
    Paint::new(),
    ImageSampling::Bilinear,
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(1, 0), Color::red())
  assert_eq(pixmap.get_pixel(2, 0), Color::new(r=128, g=0, b=128, a=255))
  assert_eq(pixmap.get_pixel(3, 0), Color::blue())
}

///|
test "Canvas::draw_transformed_sampled_pixmap_rect supports bicubic sampling" {
  let canvas = Canvas::new(5, 1)
  canvas.clear(Color::white())
  canvas.set_transform(Transform::translate(tx=1.0, ty=0.0))
  let src = make_canvas_test_bicubic_source()
  canvas.draw_transformed_sampled_pixmap_rect(
    src,
    PixelRect::new(x=0, y=0, width=4, height=1),
    0.0,
    0.0,
    3.0,
    1.0,
    Paint::new(),
    ImageSampling::Bicubic,
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(1, 0), Color::new(r=34, g=0, b=0, a=255))
  assert_eq(pixmap.get_pixel(2, 0), Color::new(r=128, g=0, b=0, a=255))
  assert_eq(pixmap.get_pixel(3, 0), Color::new(r=221, g=0, b=0, a=255))
}

///|
test "Canvas::draw_transformed_quality_pixmap_rect dispatches quality strategies" {
  let src = make_canvas_test_bicubic_source()
  let fast = Canvas::new(5, 1)
  let balanced = Canvas::new(5, 1)
  let high = Canvas::new(5, 1)
  fast.clear(Color::white())
  balanced.clear(Color::white())
  high.clear(Color::white())
  fast.set_transform(Transform::translate(tx=1.0, ty=0.0))
  balanced.set_transform(Transform::translate(tx=1.0, ty=0.0))
  high.set_transform(Transform::translate(tx=1.0, ty=0.0))
  let rect = PixelRect::new(x=0, y=0, width=4, height=1)
  fast.draw_transformed_quality_pixmap_rect(
    src,
    rect,
    0.0,
    0.0,
    3.0,
    1.0,
    Paint::new(),
    ImageQuality::Fast,
  )
  balanced.draw_transformed_quality_pixmap_rect(
    src,
    rect,
    0.0,
    0.0,
    3.0,
    1.0,
    Paint::new(),
    ImageQuality::Balanced,
  )
  high.draw_transformed_quality_pixmap_rect(
    src,
    rect,
    0.0,
    0.0,
    3.0,
    1.0,
    Paint::new(),
    ImageQuality::High,
  )
  assert_eq(fast.get_pixmap().get_pixel(2, 0), Color::black())
  assert_eq(
    balanced.get_pixmap().get_pixel(2, 0),
    Color::new(r=128, g=0, b=0, a=255),
  )
  assert_eq(
    high.get_pixmap().get_pixel(1, 0),
    Color::new(r=34, g=0, b=0, a=255),
  )
}

///|
test "Canvas::draw_transformed_sampled_pixmap covers full source pixmap" {
  let canvas = Canvas::new(3, 1)
  canvas.clear(Color::white())
  canvas.set_transform(Transform::translate(tx=1.0, ty=0.0))
  let src = Pixmap::new(2, 1)
  src.set_pixel(0, 0, Color::red())
  src.set_pixel(1, 0, Color::blue())
  canvas.draw_transformed_sampled_pixmap(
    src,
    0.0,
    0.0,
    2.0,
    1.0,
    Paint::new(),
    ImageSampling::Nearest,
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::white())
  assert_eq(pixmap.get_pixel(1, 0), Color::red())
  assert_eq(pixmap.get_pixel(2, 0), Color::blue())
}

///|
test "Canvas::draw_transformed_sampled_pixmap_rect applies paint blend mode" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::new(r=100, g=150, b=200))
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::new(r=200, g=100, b=50))
  canvas.draw_transformed_sampled_pixmap_rect(
    src,
    PixelRect::new(x=0, y=0, width=1, height=1),
    0.0,
    0.0,
    1.0,
    1.0,
    Paint::new().set_blend_mode(BlendMode::Screen),
    ImageSampling::Nearest,
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    Color::new(r=222, g=191, b=211),
  )
}

///|
test "Canvas::draw_transformed_sampled_pixmap_rect ignores invalid state" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  canvas.set_transform(Transform::scale(sx=0.0, sy=1.0))
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::black())
  canvas.draw_transformed_sampled_pixmap_rect(
    src,
    PixelRect::new(x=0, y=0, width=1, height=1),
    0.0,
    0.0,
    1.0,
    1.0,
    Paint::new(),
    ImageSampling::Nearest,
  )
  canvas.set_transform(Transform::identity())
  canvas.draw_transformed_sampled_pixmap_rect(
    src,
    PixelRect::new(x=0, y=0, width=1, height=1),
    0.0,
    0.0,
    1.0,
    1.0,
    Paint::new().set_style(PaintStyle::Stroke),
    ImageSampling::Nearest,
  )
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::white())
  assert_true(canvas.get_dirty_region().is_empty())
}

///|
test "Canvas::draw_tiled_pixmap_rect respects clip opacity and dirty region" {
  let canvas = Canvas::new(5, 1)
  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  canvas.set_clip_rect(Rect::new(x=1.0, y=0.0, width=3.0, height=1.0))
  let src = Pixmap::new(2, 1)
  src.set_pixel(0, 0, Color::red())
  src.set_pixel(1, 0, Color::blue())
  canvas.draw_tiled_pixmap_rect(
    src,
    PixelRect::new(x=0, y=0, width=2, height=1),
    0,
    0,
    5,
    1,
    Paint::new().set_opacity(0.5),
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::white())
  assert_eq(pixmap.get_pixel(1, 0), Color::new(r=127, g=127, b=255, a=255))
  assert_eq(pixmap.get_pixel(2, 0), Color::new(r=255, g=127, b=127, a=255))
  assert_eq(pixmap.get_pixel(3, 0), Color::new(r=127, g=127, b=255, a=255))
  assert_eq(pixmap.get_pixel(4, 0), Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=1, y=0, width=3, height=1)),
  )
}

///|
test "Canvas::draw_tiled_pixmap_rect applies paint filter and blend mode" {
  let canvas = Canvas::new(3, 1)
  canvas.clear(Color::new(r=100, g=150, b=200))
  canvas.clear_dirty_region()
  let src = Pixmap::new(2, 1)
  src.set_pixel(0, 0, Color::red())
  src.set_pixel(1, 0, Color::blue())
  let paint = Paint::new()
    .set_filter(PaintFilter::invert())
    .set_blend_mode(BlendMode::Multiply)
  canvas.draw_tiled_pixmap_rect(
    src,
    PixelRect::new(x=0, y=0, width=2, height=1),
    0,
    0,
    3,
    1,
    paint,
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::new(r=0, g=150, b=200))
  assert_eq(pixmap.get_pixel(1, 0), Color::new(r=100, g=150, b=0))
  assert_eq(pixmap.get_pixel(2, 0), Color::new(r=0, g=150, b=200))
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=0, y=0, width=3, height=1)),
  )
}

///|
test "Canvas::draw_tiled_pixmap_rect ignores stroke paint and invalid size" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::white())
  let src = Pixmap::new(1, 1)
  src.set_pixel(0, 0, Color::black())
  let rect = PixelRect::new(x=0, y=0, width=1, height=1)
  canvas.draw_tiled_pixmap_rect(
    src,
    rect,
    0,
    0,
    1,
    1,
    Paint::new().set_style(PaintStyle::Stroke),
  )
  canvas.draw_tiled_pixmap_rect(src, rect, 0, 0, 0, 1, Paint::new())
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::white())
}

///|
test "Canvas::draw_nine_patch_pixmap respects clip and dirty region" {
  let canvas = Canvas::new(5, 5)
  canvas.clear(Color::white())
  canvas.clear_dirty_region()
  canvas.set_clip_rect(Rect::new(x=1.0, y=1.0, width=3.0, height=3.0))
  let src = make_canvas_test_nine_patch_source()
  canvas.draw_nine_patch_pixmap(
    src,
    0,
    0,
    5,
    5,
    NinePatchInsets::new(left=1, top=1, right=1, bottom=1),
    Paint::new(),
    ImageSampling::Nearest,
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::white())
  assert_eq(pixmap.get_pixel(1, 1), Color::new(r=50, g=0, b=0))
  assert_eq(pixmap.get_pixel(3, 3), Color::new(r=50, g=0, b=0))
  assert_eq(pixmap.get_pixel(4, 4), Color::white())
  assert_true(
    canvas.get_dirty_region().bounds() ==
    Some(PixelRect::new(x=1, y=1, width=3, height=3)),
  )
}

///|
test "Canvas::draw_quality_nine_patch_pixmap composes with quality strategy" {
  let canvas = Canvas::new(5, 5)
  canvas.clear(Color::white())
  let src = make_canvas_test_nine_patch_source()
  canvas.draw_quality_nine_patch_pixmap(
    src,
    0,
    0,
    5,
    5,
    NinePatchInsets::new(left=1, top=1, right=1, bottom=1),
    Paint::new(),
    ImageQuality::High,
  )
  let pixmap = canvas.get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), Color::new(r=10, g=0, b=0))
  assert_eq(pixmap.get_pixel(2, 2), Color::new(r=50, g=0, b=0))
  assert_eq(pixmap.get_pixel(4, 4), Color::new(r=90, g=0, b=0))
}

///|
test "Canvas::draw_nine_patch_pixmap ignores stroke paint and invalid size" {
  let canvas = Canvas::new(1, 1)
  canvas.clear(Color::white())
  let src = make_canvas_test_nine_patch_source()
  let insets = NinePatchInsets::new(left=1, top=1, right=1, bottom=1)
  canvas.draw_nine_patch_pixmap(
    src,
    0,
    0,
    1,
    1,
    insets,
    Paint::new().set_style(PaintStyle::Stroke),
    ImageSampling::Nearest,
  )
  canvas.draw_nine_patch_pixmap(
    src,
    0,
    0,
    0,
    1,
    insets,
    Paint::new(),
    ImageSampling::Nearest,
  )
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), Color::white())
}

///|
fn make_canvas_test_nine_patch_source() -> Pixmap {
  let src = Pixmap::new(3, 3)
  src.set_pixel(0, 0, Color::new(r=10, g=0, b=0))
  src.set_pixel(1, 0, Color::new(r=20, g=0, b=0))
  src.set_pixel(2, 0, Color::new(r=30, g=0, b=0))
  src.set_pixel(0, 1, Color::new(r=40, g=0, b=0))
  src.set_pixel(1, 1, Color::new(r=50, g=0, b=0))
  src.set_pixel(2, 1, Color::new(r=60, g=0, b=0))
  src.set_pixel(0, 2, Color::new(r=70, g=0, b=0))
  src.set_pixel(1, 2, Color::new(r=80, g=0, b=0))
  src.set_pixel(2, 2, Color::new(r=90, g=0, b=0))
  src
}

///|
fn make_canvas_test_bicubic_source() -> Pixmap {
  let src = Pixmap::new(4, 1)
  src.set_pixel(0, 0, Color::black())
  src.set_pixel(1, 0, Color::red())
  src.set_pixel(2, 0, Color::black())
  src.set_pixel(3, 0, Color::red())
  src
}

///|
fn make_canvas_test_bicubic_rect_source() -> Pixmap {
  let src = Pixmap::new(6, 1)
  src.set_pixel(0, 0, Color::white())
  src.set_pixel(1, 0, Color::black())
  src.set_pixel(2, 0, Color::red())
  src.set_pixel(3, 0, Color::black())
  src.set_pixel(4, 0, Color::red())
  src.set_pixel(5, 0, Color::black())
  src
}
