///|
test "RenderFrame presents layer tree dirty pixels to a surface" {
  let frame = RenderFrame::new(4, 1)
  let surface = MemorySurface::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::white())

  let top = Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, Color::red())

  let tree = frame.get_layer_tree()
  ignore(tree.add_layer(background))
  assert_eq(tree.add_layer(top), 1)

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::red())
  assert_true(frame.get_canvas().get_dirty_region().is_empty())
  assert_true(frame.get_layer_tree().dirty_bounds() == None)
}

///|
test "RenderFrame retains layer tree mutations and redraws moved layers" {
  let frame = RenderFrame::new(4, 1)
  let surface = MemorySurface::new(4, 1)
  let background = Layer::new(4, 1)
  background.clear(Color::white())

  let top = Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, Color::blue())

  let tree = frame.get_layer_tree()
  ignore(tree.add_layer(background))
  assert_eq(tree.add_layer(top), 1)
  assert_true(frame.present_dirty_to(surface) == Ok(1))

  assert_true(frame.get_layer_tree().set_layer_position(1, 2, 0))
  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 2)
  assert_eq(surface.get_pixel(1, 0), Color::white())
  assert_eq(surface.get_pixel(2, 0), Color::blue())
}

///|
test "RenderFrame dirty rect limit controls partial present fallback" {
  let frame = RenderFrame::new(8, 1).set_dirty_rect_limit(2)
  let surface = MemorySurface::new(8, 1)

  let left = Layer::new(1, 1)
  left.get_canvas().draw_pixel(0, 0, Color::red())
  let middle = Layer::new(1, 1).set_position(3, 0)
  middle.get_canvas().draw_pixel(0, 0, Color::green())
  let right = Layer::new(1, 1).set_position(6, 0)
  right.get_canvas().draw_pixel(0, 0, Color::blue())

  let tree = frame.get_layer_tree()
  ignore(tree.add_layer(left))
  ignore(tree.add_layer(middle))
  ignore(tree.add_layer(right))

  assert_eq(frame.get_dirty_rect_limit(), 2)
  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(0, 0), Color::red())
  assert_eq(surface.get_pixel(3, 0), Color::green())
  assert_eq(surface.get_pixel(6, 0), Color::blue())
}

///|
test "RenderFrame::dirty_present_plan uses frame dirty rect limit" {
  let frame = RenderFrame::new(8, 1).set_dirty_rect_limit(2)
  frame.get_canvas().draw_pixel(0, 0, Color::red())

  let middle = Layer::new(1, 1).set_position(3, 0)
  middle.get_canvas().draw_pixel(0, 0, Color::green())
  let right = Layer::new(1, 1).set_position(6, 0)
  right.get_canvas().draw_pixel(0, 0, Color::blue())

  let tree = frame.get_layer_tree()
  ignore(tree.add_layer(middle))
  ignore(tree.add_layer(right))

  let plan = frame.dirty_present_plan(MemorySurface::new(8, 1))
  assert_true(plan.get_mode() == DirtyPresentPlanMode::Bounds)
  assert_eq(plan.get_rect_count(), 1)
  assert_true(
    plan.get_rects()[0] == PixelRect::new(x=0, y=0, width=7, height=1),
  )
  assert_true(frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes frame dirty without submitting" {
  let frame = RenderFrame::new(8, 1).set_dirty_rect_limit(2)
  frame.get_canvas().draw_pixel(0, 0, Color::red())

  let middle = Layer::new(1, 1).set_position(3, 0)
  middle.get_canvas().draw_pixel(0, 0, Color::green())
  let right = Layer::new(1, 1).set_position(6, 0)
  right.get_canvas().draw_pixel(0, 0, Color::blue())
  ignore(frame.get_layer_tree().add_layer(middle))
  ignore(frame.get_layer_tree().add_layer(right))

  let surface = MemorySurface::new(8, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 7)
      assert_eq(batch.get_present_byte_count(), 28)
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=0, y=0, width=7, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 28)
      assert_eq(pixels[0], Color::red().r)
      assert_eq(pixels[12], Color::green().r)
      assert_eq(pixels[24], Color::blue().r)
    }
    Err(_) => abort("expected render frame dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(3, 0),
    Color::transparent(),
  )
  assert_true(frame.has_dirty())
  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::present_dirty_to presents antialiased filtered shader path blend pixels" {
  let frame = RenderFrame::new(3, 1)
  let background = Color::new(r=100, g=150, b=200)
  frame.get_canvas().clear(background)
  let surface = MemorySurface::new(3, 1)
  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_pixel(2, 0), background)
  assert_true(!frame.has_dirty())
  surface.reset_present_telemetry()

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
    .set_blend_mode(BlendMode::Multiply)
  frame.get_canvas().fill_path(Path::new().add_rect(0.5, 0.0, 1.5, 1.0), paint)

  let edge = Color::new(r=62, g=150, b=175)
  let full = Color::new(r=75, g=150, b=50)
  let pixmap = frame.get_canvas().get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), edge)
  assert_eq(pixmap.get_pixel(1, 0), full)
  assert_eq(pixmap.get_pixel(2, 0), background)
  assert_true(
    frame.get_canvas().get_dirty_region().bounds() ==
    Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_present_pixel_count(), 2)
  assert_eq(surface.get_present_byte_count(), 8)
  assert_true(
    surface.get_present_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
  match surface.get_last_present_record() {
    Some(record) => {
      assert_true(
        record.get_rect() == PixelRect::new(x=0, y=0, width=2, height=1),
      )
      assert_eq(record.get_present_pixel_count(), 2)
      assert_eq(record.get_present_byte_count(), 8)
    }
    None => abort("expected antialiased path present record")
  }
  assert_eq(surface.get_pixel(0, 0), edge)
  assert_eq(surface.get_pixel(1, 0), full)
  assert_eq(surface.get_pixel(2, 0), background)
  assert_eq(pixmap.get_pixel(0, 0), surface.get_pixel(0, 0))
  assert_eq(pixmap.get_pixel(1, 0), surface.get_pixel(1, 0))
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes antialiased layer path through shader filter without submitting" {
  let frame = RenderFrame::new(4, 1)
  frame.get_canvas().clear(Color::white())
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  assert_true(!frame.has_dirty())

  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  let layer = Layer::new(2, 1)
    .set_position(1, 0)
    .set_shader(shader)
    .set_filter(PaintFilter::invert())
  let layer_canvas = layer.get_canvas()
  layer_canvas.fill_path(
    Path::new().add_rect(0.5, 0.0, 1.0, 1.0),
    Paint::new().set_color(Color::white()),
  )
  assert_eq(
    layer.get_pixmap().get_pixel(0, 0),
    Color::new(r=255, g=255, b=255, a=128),
  )
  assert_eq(
    layer.get_pixmap().get_pixel(1, 0),
    Color::new(r=255, g=255, b=255, a=128),
  )

  assert_eq(frame.get_layer_tree().add_layer(layer), 0)
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
  let surface = MemorySurface::new(4, 1)
  let left = Color::new(r=159, g=255, b=223)
  let right = Color::new(r=223, g=255, b=159)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], left.r)
      assert_eq(pixels[1], left.g)
      assert_eq(pixels[2], left.b)
      assert_eq(pixels[3], left.a)
      assert_eq(pixels[4], right.r)
      assert_eq(pixels[5], right.g)
      assert_eq(pixels[6], right.b)
      assert_eq(pixels[7], right.a)
    }
    Err(_) =>
      abort("expected antialiased path shader-filter render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::white())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), Color::white())
  assert_true(frame.get_canvas().get_dirty_region().is_empty())
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), left)
  assert_eq(surface.get_pixel(2, 0), right)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), left)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), right)
  assert_true(frame.get_canvas().get_dirty_region().is_empty())
  assert_true(frame.get_layer_tree().dirty_bounds() == None)
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes filtered layers without submitting" {
  let frame = RenderFrame::new(4, 1)
  frame.get_canvas().clear(Color::white())
  frame.get_canvas().clear_dirty_region()

  let layer = Layer::new(1, 1)
    .set_position(1, 0)
    .set_filter(PaintFilter::invert())
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  ignore(frame.get_layer_tree().add_layer(layer))

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let cyan = Color::new(r=0, g=255, b=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], cyan.r)
      assert_eq(pixels[1], cyan.g)
      assert_eq(pixels[2], cyan.b)
      assert_eq(pixels[3], cyan.a)
    }
    Err(_) => abort("expected filtered render frame dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::new(r=0, g=255, b=255))
  assert_true(!frame.has_dirty())
}

///|
fn make_render_frame_alpha_filter() -> PaintFilter {
  PaintFilter::color_matrix([
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 128.0,
  ])
}

///|
test "RenderFrame::dirty_present_batch materializes alpha-synthesizing filtered transparent layer without submitting" {
  let frame = RenderFrame::new(4, 1)
  frame.get_canvas().clear(Color::white())
  frame.get_canvas().clear_dirty_region()

  let layer = Layer::new(1, 1)
    .set_position(1, 0)
    .set_filter(make_render_frame_alpha_filter())
  ignore(frame.get_layer_tree().add_layer(layer))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let gray = Color::new(r=127, g=127, b=127, a=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], gray.r)
      assert_eq(pixels[1], gray.g)
      assert_eq(pixels[2], gray.b)
      assert_eq(pixels[3], gray.a)
    }
    Err(_) =>
      abort("expected alpha-synthesizing render frame dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::new(r=127, g=127, b=127, a=255))
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    Color::new(r=127, g=127, b=127, a=255),
  )
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes moved layer bounds without submitting" {
  let frame = RenderFrame::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::white())
  let moving = Layer::new(1, 1).set_position(1, 0)
  moving.get_canvas().draw_pixel(0, 0, Color::blue())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(moving), 1)
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::blue())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), Color::white())
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().set_layer_position(1, 2, 0))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], Color::white().r)
      assert_eq(pixels[1], Color::white().g)
      assert_eq(pixels[2], Color::white().b)
      assert_eq(pixels[3], Color::white().a)
      assert_eq(pixels[4], Color::blue().r)
      assert_eq(pixels[5], Color::blue().g)
      assert_eq(pixels[6], Color::blue().b)
      assert_eq(pixels[7], Color::blue().a)
    }
    Err(_) => abort("expected moved layer render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::blue())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), Color::white())
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::white())
  assert_eq(surface.get_pixel(2, 0), Color::blue())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::white())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), Color::blue())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes resized layer bounds without submitting" {
  let frame = RenderFrame::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::white())
  let resizing = Layer::new(2, 1).set_position(1, 0)
  resizing.get_canvas().draw_pixel(0, 0, Color::red())
  resizing.get_canvas().draw_pixel(1, 0, Color::blue())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(resizing), 1)
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), Color::blue())
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().resize_layer(1, 1, 1))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], Color::red().r)
      assert_eq(pixels[1], Color::red().g)
      assert_eq(pixels[2], Color::red().b)
      assert_eq(pixels[3], Color::red().a)
      assert_eq(pixels[4], Color::white().r)
      assert_eq(pixels[5], Color::white().g)
      assert_eq(pixels[6], Color::white().b)
      assert_eq(pixels[7], Color::white().a)
    }
    Err(_) => abort("expected resized layer render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), Color::blue())
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::red())
  assert_eq(surface.get_pixel(2, 0), Color::white())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), Color::white())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes hidden layer bounds without submitting" {
  let frame = RenderFrame::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::white())
  let top = Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, Color::red())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(top), 1)
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().set_layer_visible(1, false))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], Color::white().r)
      assert_eq(pixels[1], Color::white().g)
      assert_eq(pixels[2], Color::white().b)
      assert_eq(pixels[3], Color::white().a)
    }
    Err(_) => abort("expected hidden layer render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::white())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes removed layer bounds without submitting" {
  let frame = RenderFrame::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::white())
  let top = Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, Color::red())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(top), 1)
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(!frame.has_dirty())

  match frame.get_layer_tree().remove_layer(1) {
    Some(layer) => assert_eq(layer.get_x(), 1)
    None => abort("expected removed frame layer")
  }
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], Color::white().r)
      assert_eq(pixels[1], Color::white().g)
      assert_eq(pixels[2], Color::white().b)
      assert_eq(pixels[3], Color::white().a)
    }
    Err(_) => abort("expected removed layer render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::white())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes replaced layer bounds without submitting" {
  let frame = RenderFrame::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::white())
  let old_top = Layer::new(1, 1).set_position(1, 0)
  old_top.get_canvas().draw_pixel(0, 0, Color::red())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(old_top), 1)
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), Color::white())
  assert_true(!frame.has_dirty())

  let new_top = Layer::new(1, 1).set_position(2, 0)
  new_top.get_canvas().draw_pixel(0, 0, Color::green())
  match frame.replace_layer(1, new_top) {
    Some(layer) => assert_eq(layer.get_x(), 1)
    None => abort("expected replaced frame layer")
  }
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], Color::white().r)
      assert_eq(pixels[1], Color::white().g)
      assert_eq(pixels[2], Color::white().b)
      assert_eq(pixels[3], Color::white().a)
      assert_eq(pixels[4], Color::green().r)
      assert_eq(pixels[5], Color::green().g)
      assert_eq(pixels[6], Color::green().b)
      assert_eq(pixels[7], Color::green().a)
    }
    Err(_) => abort("expected replaced layer render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), Color::white())
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::white())
  assert_eq(surface.get_pixel(2, 0), Color::green())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::white())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), Color::green())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes reordered layer bounds without submitting" {
  let frame = RenderFrame::new(2, 1)

  let background = Layer::new(2, 1)
  background.clear(Color::white())
  let bottom = Layer::new(1, 1)
  bottom.get_canvas().draw_pixel(0, 0, Color::red())
  let top = Layer::new(1, 1)
  top.get_canvas().draw_pixel(0, 0, Color::blue())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(bottom), 1)
  assert_eq(frame.get_layer_tree().add_layer(top), 2)
  assert_true(frame.present_dirty_to(MemorySurface::new(2, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(0, 0), Color::blue())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().reorder_layer(2, 1))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )

  let surface = MemorySurface::new(2, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=0, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], Color::red().r)
      assert_eq(pixels[1], Color::red().g)
      assert_eq(pixels[2], Color::red().b)
      assert_eq(pixels[3], Color::red().a)
    }
    Err(_) => abort("expected reordered layer render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(0, 0), Color::blue())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(0, 0), Color::red())
  assert_eq(surface.get_pixel(1, 0), Color::transparent())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(0, 0), Color::red())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::white())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes opacity style invalidation without submitting" {
  let frame = RenderFrame::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::white())
  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(layer), 1)
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::blue())
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().set_layer_opacity(1, 0.5))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let half_blue = Color::new(r=127, g=127, b=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], half_blue.r)
      assert_eq(pixels[1], half_blue.g)
      assert_eq(pixels[2], half_blue.b)
      assert_eq(pixels[3], half_blue.a)
    }
    Err(_) => abort("expected opacity style invalidation render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::blue())
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    Color::new(r=127, g=127, b=255),
  )
  assert_eq(surface.get_pixel(1, 0), Color::new(r=127, g=127, b=255))
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes filter style invalidation without submitting" {
  let frame = RenderFrame::new(4, 1)
  frame.get_canvas().clear(Color::white())

  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().set_layer_filter(0, PaintFilter::invert()))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let cyan = Color::new(r=0, g=255, b=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], cyan.r)
      assert_eq(pixels[1], cyan.g)
      assert_eq(pixels[2], cyan.b)
      assert_eq(pixels[3], cyan.a)
    }
    Err(_) => abort("expected filtered style invalidation render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::new(r=0, g=255, b=255))
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes cleared filter invalidation without submitting" {
  let frame = RenderFrame::new(4, 1)
  frame.get_canvas().clear(Color::white())

  let layer = Layer::new(1, 1)
    .set_position(1, 0)
    .set_filter(PaintFilter::invert())
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  let cyan = Color::new(r=0, g=255, b=255)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), cyan)
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().clear_layer_filter(0))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], Color::red().r)
      assert_eq(pixels[1], Color::red().g)
      assert_eq(pixels[2], Color::red().b)
      assert_eq(pixels[3], Color::red().a)
    }
    Err(_) => abort("expected cleared filter invalidation render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), cyan)
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::red())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes shader style invalidation without submitting" {
  let frame = RenderFrame::new(4, 1)
  frame.get_canvas().clear(Color::white())

  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(!frame.has_dirty())

  let blue_shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=Color::blue(),
    end_color=Color::blue(),
  )
  assert_true(frame.get_layer_tree().set_layer_shader(0, blue_shader))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], Color::blue().r)
      assert_eq(pixels[1], Color::blue().g)
      assert_eq(pixels[2], Color::blue().b)
      assert_eq(pixels[3], Color::blue().a)
    }
    Err(_) => abort("expected shader style invalidation render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::blue())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes cleared shader invalidation without submitting" {
  let frame = RenderFrame::new(4, 1)
  frame.get_canvas().clear(Color::white())

  let blue_shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=Color::blue(),
    end_color=Color::blue(),
  )
  let layer = Layer::new(1, 1).set_position(1, 0).set_shader(blue_shader)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::blue())
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().clear_layer_shader(0))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], Color::red().r)
      assert_eq(pixels[1], Color::red().g)
      assert_eq(pixels[2], Color::red().b)
      assert_eq(pixels[3], Color::red().a)
    }
    Err(_) => abort("expected cleared shader invalidation render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::blue())
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::red())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes blend style invalidation without submitting" {
  let frame = RenderFrame::new(4, 1)

  let background = Layer::new(4, 1)
  background.clear(Color::blue())
  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(layer), 1)
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().set_layer_blend_mode(1, BlendMode::Screen))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let magenta = Color::new(r=255, g=0, b=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], magenta.r)
      assert_eq(pixels[1], magenta.g)
      assert_eq(pixels[2], magenta.b)
      assert_eq(pixels[3], magenta.a)
    }
    Err(_) => abort("expected blend style invalidation render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::new(r=255, g=0, b=255))
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch reblends Destination shader filter invalidation without submitting" {
  let frame = RenderFrame::new(4, 1)
  let background_left = Color::new(r=20, g=40, b=60)
  let background_right = Color::new(r=200, g=150, b=100)
  let cached_left = Color::new(r=42, g=148, b=126)
  let cached_right = Color::new(r=195, g=203, b=82)

  let background = Layer::new(4, 1)
  background.get_canvas().draw_pixel(0, 0, Color::white())
  background.get_canvas().draw_pixel(1, 0, background_left)
  background.get_canvas().draw_pixel(2, 0, background_right)
  background.get_canvas().draw_pixel(3, 0, Color::black())
  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  let layer = Layer::new(2, 1)
    .set_position(1, 0)
    .set_shader(shader)
    .set_filter(PaintFilter::invert())
    .set_opacity(0.5)
  layer.get_canvas().draw_pixel(0, 0, Color::white())
  layer.get_canvas().draw_pixel(1, 0, Color::white())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(layer), 1)
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), cached_left)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), cached_right)
  assert_true(!frame.has_dirty())

  assert_true(
    frame.get_layer_tree().set_layer_blend_mode(1, BlendMode::Destination),
  )
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], background_left.r)
      assert_eq(pixels[1], background_left.g)
      assert_eq(pixels[2], background_left.b)
      assert_eq(pixels[3], background_left.a)
      assert_eq(pixels[4], background_right.r)
      assert_eq(pixels[5], background_right.g)
      assert_eq(pixels[6], background_right.b)
      assert_eq(pixels[7], background_right.a)
    }
    Err(_) => abort("expected Destination shader filter render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), cached_left)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), cached_right)
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), background_left)
  assert_eq(surface.get_pixel(2, 0), background_right)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), background_left)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), background_right)
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::dirty_present_batch materializes transparent-source blend invalidation without submitting" {
  let frame = RenderFrame::new(4, 1)
  let background_color = Color::new(r=10, g=20, b=30)

  let background = Layer::new(4, 1)
  background.clear(background_color)
  let layer = Layer::new(1, 1).set_position(1, 0).set_opacity(0.0)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(layer), 1)
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), background_color)
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().set_layer_blend_mode(1, BlendMode::Clear))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let transparent = Color::transparent()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], transparent.r)
      assert_eq(pixels[1], transparent.g)
      assert_eq(pixels[2], transparent.b)
      assert_eq(pixels[3], transparent.a)
    }
    Err(_) =>
      abort("expected transparent blend invalidation render frame batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), background_color)
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::transparent())
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    Color::transparent(),
  )
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame present recomposition ignores canvas draw state" {
  let frame = RenderFrame::new(4, 1)
  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)
  assert_true(frame.present_dirty_to(MemorySurface::new(4, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(!frame.has_dirty())

  match frame.get_layer_tree().get_layer(0) {
    Some(value) => value.get_canvas().draw_pixel(0, 0, Color::blue())
    None => abort("expected layer")
  }
  assert_true(
    frame.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  let canvas = frame.get_canvas()
  let clipped_state = Rect::new(x=0.0, y=0.0, width=1.0, height=1.0)
  let transformed_state = Transform::translate(tx=2.0, ty=0.0)
  canvas.save()
  canvas.set_clip_rect(clipped_state)
  canvas.set_transform(transformed_state)
  assert_eq(canvas.get_save_count(), 1)
  assert_true(canvas.get_clip_rect() == Some(clipped_state))
  assert_true(canvas.get_transform() == transformed_state)

  let surface = MemorySurface::new(4, 1)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let pixels = batch.get_payloads()[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], Color::blue().r)
      assert_eq(pixels[1], Color::blue().g)
      assert_eq(pixels[2], Color::blue().b)
      assert_eq(pixels[3], Color::blue().a)
    }
    Err(_) => abort("expected draw-state-isolated dirty present batch")
  }
  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(frame.has_dirty())
  assert_eq(canvas.get_save_count(), 1)
  assert_true(canvas.get_clip_rect() == Some(clipped_state))
  assert_true(canvas.get_transform() == transformed_state)

  match frame.present_dirty_to(RenderFrameFailingSurface::new(4, 1)) {
    Err(PresentError::InvalidDimensions(0, 0)) => ()
    _ => abort("expected draw-state-isolated present error")
  }
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(frame.has_dirty())
  assert_eq(canvas.get_save_count(), 1)
  assert_true(canvas.get_clip_rect() == Some(clipped_state))
  assert_true(canvas.get_transform() == transformed_state)

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::blue())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::blue())
  assert_true(!frame.has_dirty())
  assert_eq(canvas.get_save_count(), 1)
  assert_true(canvas.get_clip_rect() == Some(clipped_state))
  assert_true(canvas.get_transform() == transformed_state)
  assert_true(canvas.restore())
  assert_eq(canvas.get_save_count(), 0)
  assert_true(canvas.get_clip_rect() == None)
  assert_true(canvas.get_transform() == Transform::identity())
}

///|
test "RenderFrame::dirty_submit_plan snapshots dirty bounds and present plan" {
  let frame = RenderFrame::new(8, 1).set_dirty_rect_limit(2)
  frame.get_canvas().draw_pixel(0, 0, Color::red())

  let middle = Layer::new(1, 1).set_position(3, 0)
  middle.get_canvas().draw_pixel(0, 0, Color::green())
  let right = Layer::new(1, 1).set_position(6, 0)
  right.get_canvas().draw_pixel(0, 0, Color::blue())
  ignore(frame.get_layer_tree().add_layer(middle))
  ignore(frame.get_layer_tree().add_layer(right))

  let submit_plan = frame.dirty_submit_plan(MemorySurface::new(8, 1))
  assert_true(submit_plan.get_state() == DirtySubmitState::Present)
  assert_true(submit_plan.has_dirty())
  assert_true(submit_plan.needs_present())
  assert_true(submit_plan.uses_bounds_fallback())
  assert_eq(submit_plan.get_present_rect_count(), 1)
  assert_eq(submit_plan.get_present_pixel_count(), 7)
  assert_eq(submit_plan.get_present_byte_count(), 28)
  assert_true(submit_plan.saves_full_present_pixels(8, 1))
  assert_true(!submit_plan.saves_full_present_pixels(7, 1))
  assert_true(
    submit_plan.get_present_strategy(8, 1) == DirtyPresentStrategy::Partial,
  )
  assert_true(
    submit_plan.get_present_strategy(7, 1) == DirtyPresentStrategy::Full,
  )
  assert_true(
    submit_plan.get_dirty_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=7, height=1)),
  )
  assert_true(
    submit_plan.get_present_plan().get_rects()[0] ==
    PixelRect::new(x=0, y=0, width=7, height=1),
  )
  assert_true(frame.has_dirty())
}

///|
test "RenderFrame::dirty_submit_plan keeps clipped-away dirty visible to scheduler" {
  let frame = RenderFrame::new(4, 1)
  frame.mark_dirty_rect(PixelRect::new(x=3, y=0, width=1, height=1))

  let submit_plan = frame.dirty_submit_plan(MemorySurface::new(2, 1))
  assert_true(submit_plan.get_state() == DirtySubmitState::DirtyClippedAway)
  assert_true(submit_plan.has_dirty())
  assert_true(!submit_plan.needs_present())
  assert_eq(submit_plan.get_present_rect_count(), 0)
  assert_eq(submit_plan.get_present_pixel_count(), 0)
  assert_eq(submit_plan.get_present_byte_count(), 0)
  assert_true(!submit_plan.saves_full_present_pixels(2, 1))
  assert_true(
    submit_plan.get_present_strategy(2, 1) == DirtyPresentStrategy::Skip,
  )
  assert_true(
    submit_plan.get_dirty_bounds() ==
    Some(PixelRect::new(x=3, y=0, width=1, height=1)),
  )
  assert_true(
    submit_plan.get_present_plan().get_mode() == DirtyPresentPlanMode::Empty,
  )
  assert_true(frame.has_dirty())
}

///|
test "RenderFrame::submit_dirty_to reports scheduler result" {
  let frame = RenderFrame::new(2, 1)
  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  ignore(frame.get_layer_tree().add_layer(layer))

  let result = frame.submit_dirty_to(MemorySurface::new(2, 1))
  match result {
    Ok(submit_result) => {
      assert_true(submit_result.get_state() == DirtySubmitState::Present)
      assert_eq(submit_result.get_presented_rect_count(), 1)
      assert_true(submit_result.has_dirty())
      assert_true(submit_result.needs_present())
      assert_true(submit_result.did_present())
      assert_eq(submit_result.get_present_pixel_count(), 1)
      assert_eq(submit_result.get_present_byte_count(), 4)
      assert_true(submit_result.saves_full_present_pixels(2, 1))
      assert_true(
        submit_result.get_present_strategy(2, 1) ==
        DirtyPresentStrategy::Partial,
      )
      assert_true(!submit_result.was_clipped_away())
      assert_true(!submit_result.uses_bounds_fallback())
      assert_true(
        submit_result.get_dirty_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      assert_true(
        submit_result.get_present_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
    }
    Err(_) => abort("expected dirty submit result")
  }
  assert_true(!frame.has_dirty())

  let clean = frame.submit_dirty_to(MemorySurface::new(2, 1))
  match clean {
    Ok(submit_result) => {
      assert_true(submit_result.get_state() == DirtySubmitState::Clean)
      assert_eq(submit_result.get_presented_rect_count(), 0)
      assert_true(!submit_result.has_dirty())
      assert_true(!submit_result.needs_present())
      assert_true(!submit_result.did_present())
      assert_true(!submit_result.was_clipped_away())
      assert_eq(submit_result.get_present_pixel_count(), 0)
      assert_eq(submit_result.get_present_byte_count(), 0)
      assert_true(!submit_result.saves_full_present_pixels(2, 1))
      assert_true(
        submit_result.get_present_strategy(2, 1) == DirtyPresentStrategy::Skip,
      )
      assert_true(submit_result.get_dirty_bounds() == None)
      assert_true(submit_result.get_present_bounds() == None)
    }
    Err(_) => abort("expected clean submit result")
  }
}

///|
test "RenderFrame::submit_dirty_to consumes surface-clipped dirty" {
  let frame = RenderFrame::new(4, 1)
  let layer = Layer::new(1, 1).set_position(3, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  ignore(frame.get_layer_tree().add_layer(layer))

  let result = frame.submit_dirty_to(MemorySurface::new(2, 1))
  match result {
    Ok(submit_result) => {
      assert_true(
        submit_result.get_state() == DirtySubmitState::DirtyClippedAway,
      )
      assert_eq(submit_result.get_presented_rect_count(), 0)
      assert_true(submit_result.has_dirty())
      assert_true(!submit_result.needs_present())
      assert_true(!submit_result.did_present())
      assert_eq(submit_result.get_present_pixel_count(), 0)
      assert_eq(submit_result.get_present_byte_count(), 0)
      assert_true(!submit_result.saves_full_present_pixels(2, 1))
      assert_true(
        submit_result.get_present_strategy(2, 1) == DirtyPresentStrategy::Skip,
      )
      assert_true(submit_result.was_clipped_away())
      assert_true(
        submit_result.get_dirty_bounds() ==
        Some(PixelRect::new(x=3, y=0, width=1, height=1)),
      )
      assert_true(submit_result.get_present_bounds() == None)
    }
    Err(_) => abort("expected clipped-away submit result")
  }
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::submit_by_strategy_plan reports partial present cost" {
  let frame = RenderFrame::new(4, 1)
  frame.mark_dirty_rect(PixelRect::new(x=1, y=0, width=1, height=1))
  let surface = MemorySurface::new(4, 1)

  assert_true(frame.present_strategy(surface) == DirtyPresentStrategy::Partial)
  let plan = frame.submit_by_strategy_plan(surface)
  assert_true(plan.get_present_strategy() == DirtyPresentStrategy::Partial)
  assert_true(plan.get_state() == DirtySubmitState::Present)
  assert_true(plan.has_dirty())
  assert_true(plan.needs_present())
  assert_true(!plan.was_clipped_away())
  assert_true(!plan.uses_bounds_fallback())
  assert_eq(plan.get_present_rect_count(), 1)
  assert_eq(plan.get_present_pixel_count(), 1)
  assert_eq(plan.get_present_byte_count(), 4)
  assert_true(plan.saves_full_present_pixels())
  assert_true(
    plan.get_dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_true(
    plan.get_dirty_submit_plan().get_present_strategy(4, 1) ==
    DirtyPresentStrategy::Partial,
  )
  assert_true(frame.has_dirty())
  assert_eq(surface.get_present_count(), 0)
}

///|
test "RenderFrame::submit_schedule exposes dry-run event-loop actions" {
  let partial_frame = RenderFrame::new(4, 1)
  partial_frame.mark_dirty_rect(PixelRect::new(x=1, y=0, width=1, height=1))
  let partial_surface = MemorySurface::new(4, 1)
  let partial_schedule = partial_frame.submit_schedule(partial_surface)
  assert_true(
    partial_schedule.get_action() == RenderFrameScheduleAction::Present,
  )
  assert_true(partial_schedule.should_submit())
  assert_true(partial_schedule.needs_present())
  assert_true(partial_schedule.has_dirty())
  assert_true(!partial_schedule.was_clipped_away())
  assert_true(!partial_schedule.uses_bounds_fallback())
  assert_true(
    partial_schedule.get_present_strategy() == DirtyPresentStrategy::Partial,
  )
  assert_true(partial_schedule.get_state() == DirtySubmitState::Present)
  assert_true(
    partial_schedule.get_dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_true(
    partial_schedule.get_submit_plan().get_present_strategy() ==
    DirtyPresentStrategy::Partial,
  )
  assert_eq(partial_schedule.get_present_rect_count(), 1)
  assert_eq(partial_schedule.get_present_pixel_count(), 1)
  assert_eq(partial_schedule.get_present_byte_count(), 4)
  assert_true(partial_schedule.saves_full_present_pixels())
  assert_eq(partial_surface.get_present_count(), 0)
  assert_true(partial_frame.has_dirty())

  let full_frame = RenderFrame::new(2, 1)
  full_frame.mark_all_dirty()
  let full_surface = MemorySurface::new(2, 1)
  let full_schedule = full_frame.submit_schedule(full_surface)
  assert_true(full_schedule.get_action() == RenderFrameScheduleAction::Present)
  assert_true(full_schedule.should_submit())
  assert_true(full_schedule.needs_present())
  assert_true(full_schedule.has_dirty())
  assert_true(!full_schedule.was_clipped_away())
  assert_true(
    full_schedule.get_present_strategy() == DirtyPresentStrategy::Full,
  )
  assert_true(full_schedule.get_state() == DirtySubmitState::Present)
  assert_eq(full_schedule.get_present_rect_count(), 1)
  assert_eq(full_schedule.get_present_pixel_count(), 2)
  assert_eq(full_schedule.get_present_byte_count(), 8)
  assert_true(!full_schedule.saves_full_present_pixels())
  assert_eq(full_surface.get_present_count(), 0)
  assert_true(full_frame.has_dirty())

  let clipped_frame = RenderFrame::new(4, 1)
  clipped_frame.mark_dirty_rect(PixelRect::new(x=3, y=0, width=1, height=1))
  let clipped_surface = MemorySurface::new(2, 1)
  let clipped_schedule = clipped_frame.submit_schedule(clipped_surface)
  assert_true(
    clipped_schedule.get_action() ==
    RenderFrameScheduleAction::SubmitWithoutPresent,
  )
  assert_true(clipped_schedule.should_submit())
  assert_true(!clipped_schedule.needs_present())
  assert_true(clipped_schedule.has_dirty())
  assert_true(clipped_schedule.was_clipped_away())
  assert_true(
    clipped_schedule.get_present_strategy() == DirtyPresentStrategy::Skip,
  )
  assert_true(
    clipped_schedule.get_state() == DirtySubmitState::DirtyClippedAway,
  )
  assert_true(
    clipped_schedule.get_dirty_bounds() ==
    Some(PixelRect::new(x=3, y=0, width=1, height=1)),
  )
  assert_eq(clipped_schedule.get_present_rect_count(), 0)
  assert_eq(clipped_schedule.get_present_pixel_count(), 0)
  assert_eq(clipped_schedule.get_present_byte_count(), 0)
  assert_true(!clipped_schedule.saves_full_present_pixels())
  assert_eq(clipped_surface.get_present_count(), 0)
  assert_true(clipped_frame.has_dirty())

  let clean_frame = RenderFrame::new(2, 1)
  let clean_surface = MemorySurface::new(2, 1)
  let clean_schedule = clean_frame.submit_schedule(clean_surface)
  assert_true(clean_schedule.get_action() == RenderFrameScheduleAction::Skip)
  assert_true(!clean_schedule.should_submit())
  assert_true(!clean_schedule.needs_present())
  assert_true(!clean_schedule.has_dirty())
  assert_true(!clean_schedule.was_clipped_away())
  assert_true(
    clean_schedule.get_present_strategy() == DirtyPresentStrategy::Skip,
  )
  assert_true(clean_schedule.get_state() == DirtySubmitState::Clean)
  assert_true(clean_schedule.get_dirty_bounds() == None)
  assert_eq(clean_schedule.get_present_rect_count(), 0)
  assert_eq(clean_schedule.get_present_pixel_count(), 0)
  assert_eq(clean_schedule.get_present_byte_count(), 0)
  assert_true(!clean_schedule.saves_full_present_pixels())
  assert_eq(clean_surface.get_present_count(), 0)
  assert_true(!clean_frame.has_dirty())
}

///|
test "RenderFrame::submit_by_strategy_to submits partial dirty rects" {
  let frame = RenderFrame::new(4, 1)
  frame.get_canvas().draw_pixel(1, 0, Color::red())
  let surface = MemorySurface::new(4, 1)

  match frame.submit_by_strategy_to(surface) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == DirtyPresentStrategy::Partial,
      )
      assert_true(
        result.get_submit_plan().get_present_strategy() ==
        DirtyPresentStrategy::Partial,
      )
      assert_true(result.get_state() == DirtySubmitState::Present)
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_true(result.has_dirty())
      assert_true(result.needs_present())
      assert_true(result.did_present())
      assert_true(!result.was_clipped_away())
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
      assert_true(result.saves_full_present_pixels())
      assert_true(
        result.get_dirty_bounds() ==
        Some(PixelRect::new(x=1, y=0, width=1, height=1)),
      )
    }
    Err(_) => abort("expected partial strategy submit result")
  }
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::red())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::submit_by_strategy_to promotes full-frame cost" {
  let frame = RenderFrame::new(2, 1)
  frame.mark_all_dirty()
  let surface = MemorySurface::new(2, 1)

  let plan = frame.submit_by_strategy_plan(surface)
  assert_true(plan.get_present_strategy() == DirtyPresentStrategy::Full)
  assert_true(plan.get_state() == DirtySubmitState::Present)
  assert_true(plan.has_dirty())
  assert_true(plan.needs_present())
  assert_eq(plan.get_present_rect_count(), 1)
  assert_eq(plan.get_present_pixel_count(), 2)
  assert_eq(plan.get_present_byte_count(), 8)
  assert_true(!plan.saves_full_present_pixels())
  assert_true(frame.has_dirty())
  assert_eq(surface.get_present_count(), 0)

  match frame.submit_by_strategy_to(surface) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Full)
      assert_true(result.get_state() == DirtySubmitState::Present)
      assert_true(result.did_present())
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 2)
      assert_eq(result.get_present_byte_count(), 8)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected full strategy submit result")
  }
  assert_eq(surface.get_present_count(), 1)
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::submit_by_strategy_to consumes clipped-away dirty" {
  let frame = RenderFrame::new(4, 1)
  frame.mark_dirty_rect(PixelRect::new(x=3, y=0, width=1, height=1))
  let surface = MemorySurface::new(2, 1)

  let plan = frame.submit_by_strategy_plan(surface)
  assert_true(plan.get_present_strategy() == DirtyPresentStrategy::Skip)
  assert_true(plan.get_state() == DirtySubmitState::DirtyClippedAway)
  assert_true(plan.has_dirty())
  assert_true(!plan.needs_present())
  assert_true(plan.was_clipped_away())
  assert_eq(plan.get_present_rect_count(), 0)
  assert_eq(plan.get_present_pixel_count(), 0)
  assert_eq(plan.get_present_byte_count(), 0)
  assert_true(!plan.saves_full_present_pixels())
  assert_true(frame.has_dirty())
  assert_eq(surface.get_present_count(), 0)

  match frame.submit_by_strategy_to(surface) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Skip)
      assert_true(result.get_state() == DirtySubmitState::DirtyClippedAway)
      assert_true(result.has_dirty())
      assert_true(!result.needs_present())
      assert_true(result.was_clipped_away())
      assert_true(!result.did_present())
      assert_eq(result.get_present_rect_count(), 0)
      assert_eq(result.get_presented_rect_count(), 0)
      assert_eq(result.get_present_pixel_count(), 0)
      assert_eq(result.get_present_byte_count(), 0)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected clipped-away strategy submit result")
  }
  assert_eq(surface.get_present_count(), 0)
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::submit_by_strategy_to skips clean frames" {
  let frame = RenderFrame::new(2, 1)
  let surface = MemorySurface::new(2, 1)

  match frame.submit_by_strategy_to(surface) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Skip)
      assert_true(result.get_state() == DirtySubmitState::Clean)
      assert_true(!result.has_dirty())
      assert_true(!result.needs_present())
      assert_true(!result.was_clipped_away())
      assert_true(!result.did_present())
      assert_eq(result.get_present_rect_count(), 0)
      assert_eq(result.get_presented_rect_count(), 0)
      assert_eq(result.get_present_pixel_count(), 0)
      assert_eq(result.get_present_byte_count(), 0)
      assert_true(!result.saves_full_present_pixels())
      assert_true(result.get_dirty_bounds() == None)
    }
    Err(_) => abort("expected clean strategy submit result")
  }
  assert_eq(surface.get_present_count(), 0)
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::submit_scheduled_to consumes precomputed schedules" {
  let partial_frame = RenderFrame::new(4, 1)
  partial_frame.get_canvas().draw_pixel(1, 0, Color::red())
  let partial_surface = MemorySurface::new(4, 1)
  let partial_schedule = partial_frame.submit_schedule(partial_surface)
  match partial_frame.submit_scheduled_to(partial_surface, partial_schedule) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == DirtyPresentStrategy::Partial,
      )
      assert_true(result.get_state() == DirtySubmitState::Present)
      assert_true(result.did_present())
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected scheduled partial submit result")
  }
  assert_eq(partial_surface.get_present_count(), 1)
  assert_eq(partial_surface.get_pixel(1, 0), Color::red())
  assert_true(!partial_frame.has_dirty())

  let full_frame = RenderFrame::new(2, 1)
  full_frame.get_canvas().draw_pixel(0, 0, Color::green())
  full_frame.mark_all_dirty()
  let full_surface = MemorySurface::new(2, 1)
  let full_schedule = full_frame.submit_schedule(full_surface)
  match full_frame.submit_scheduled_to(full_surface, full_schedule) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Full)
      assert_true(result.get_state() == DirtySubmitState::Present)
      assert_true(result.did_present())
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 2)
      assert_eq(result.get_present_byte_count(), 8)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected scheduled full submit result")
  }
  assert_eq(full_surface.get_present_count(), 1)
  assert_eq(full_surface.get_pixel(0, 0), Color::green())
  assert_true(!full_frame.has_dirty())

  let clipped_frame = RenderFrame::new(4, 1)
  clipped_frame.mark_dirty_rect(PixelRect::new(x=3, y=0, width=1, height=1))
  let clipped_surface = MemorySurface::new(2, 1)
  let clipped_schedule = clipped_frame.submit_schedule(clipped_surface)
  match clipped_frame.submit_scheduled_to(clipped_surface, clipped_schedule) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Skip)
      assert_true(result.get_state() == DirtySubmitState::DirtyClippedAway)
      assert_true(result.has_dirty())
      assert_true(!result.needs_present())
      assert_true(result.was_clipped_away())
      assert_true(!result.did_present())
      assert_eq(result.get_present_rect_count(), 0)
      assert_eq(result.get_presented_rect_count(), 0)
      assert_eq(result.get_present_pixel_count(), 0)
      assert_eq(result.get_present_byte_count(), 0)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected scheduled clipped submit result")
  }
  assert_eq(clipped_surface.get_present_count(), 0)
  assert_true(!clipped_frame.has_dirty())

  let clean_frame = RenderFrame::new(2, 1)
  let clean_surface = MemorySurface::new(2, 1)
  let clean_schedule = clean_frame.submit_schedule(clean_surface)
  match clean_frame.submit_scheduled_to(clean_surface, clean_schedule) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Skip)
      assert_true(result.get_state() == DirtySubmitState::Clean)
      assert_true(!result.has_dirty())
      assert_true(!result.needs_present())
      assert_true(!result.did_present())
      assert_eq(result.get_presented_rect_count(), 0)
      assert_eq(result.get_present_pixel_count(), 0)
      assert_eq(result.get_present_byte_count(), 0)
    }
    Err(_) => abort("expected scheduled clean submit result")
  }
  assert_eq(clean_surface.get_present_count(), 0)
  assert_true(!clean_frame.has_dirty())
}

///|
test "RenderFrame::submit_scheduled_to preserves dirty after surface error" {
  let frame = RenderFrame::new(2, 1)
  frame.mark_all_dirty()
  let surface = RenderFrameFailingSurface::new(2, 1)
  let schedule = frame.submit_schedule(surface)

  match frame.submit_scheduled_to(surface, schedule) {
    Err(PresentError::InvalidDimensions(0, 0)) => ()
    _ => abort("expected scheduled submit surface failure")
  }
  assert_true(frame.has_dirty())
  assert_true(
    frame.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "RenderFrame::redraw_schedule promotes clean redraw to full present" {
  let frame = RenderFrame::new(2, 1)
  let layer = Layer::new(2, 1)
  layer.clear(Color::white())
  layer.get_canvas().draw_pixel(1, 0, Color::blue())
  ignore(frame.get_layer_tree().add_layer(layer))
  assert_true(frame.present_dirty_to(MemorySurface::new(2, 1)) == Ok(1))
  assert_true(!frame.has_dirty())

  let dirty_surface = MemorySurface::new(2, 1)
  let dirty_schedule = frame.submit_schedule(dirty_surface)
  assert_true(dirty_schedule.get_action() == RenderFrameScheduleAction::Skip)
  assert_true(
    dirty_schedule.get_present_strategy() == DirtyPresentStrategy::Skip,
  )
  assert_true(dirty_schedule.get_state() == DirtySubmitState::Clean)
  assert_true(!dirty_schedule.needs_present())
  assert_eq(dirty_schedule.get_present_rect_count(), 0)
  assert_eq(dirty_schedule.get_present_pixel_count(), 0)

  let redraw_surface = MemorySurface::new(2, 1)
  let redraw_schedule = frame.redraw_schedule(redraw_surface)
  assert_true(
    redraw_schedule.get_action() == RenderFrameScheduleAction::Present,
  )
  assert_true(redraw_schedule.should_submit())
  assert_true(redraw_schedule.needs_present())
  assert_true(!redraw_schedule.has_dirty())
  assert_true(
    redraw_schedule.get_present_strategy() == DirtyPresentStrategy::Full,
  )
  assert_true(redraw_schedule.get_state() == DirtySubmitState::Clean)
  assert_true(redraw_schedule.get_dirty_bounds() == None)
  assert_eq(redraw_schedule.get_present_rect_count(), 1)
  assert_eq(redraw_schedule.get_present_pixel_count(), 2)
  assert_eq(redraw_schedule.get_present_byte_count(), 8)
  assert_true(!redraw_schedule.saves_full_present_pixels())
  assert_eq(redraw_surface.get_present_count(), 0)
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::submit_redraw_to presents cached clean frame" {
  let frame = RenderFrame::new(2, 1)
  let layer = Layer::new(2, 1)
  layer.clear(Color::white())
  layer.get_canvas().draw_pixel(1, 0, Color::blue())
  ignore(frame.get_layer_tree().add_layer(layer))
  assert_true(frame.present_dirty_to(MemorySurface::new(2, 1)) == Ok(1))
  assert_true(!frame.has_dirty())

  let surface = MemorySurface::new(2, 1)
  match frame.submit_redraw_to(surface) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Full)
      assert_true(result.get_state() == DirtySubmitState::Clean)
      assert_true(!result.has_dirty())
      assert_true(result.needs_present())
      assert_true(result.did_present())
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 2)
      assert_eq(result.get_present_byte_count(), 8)
    }
    Err(_) => abort("expected redraw submit result")
  }
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(0, 0), Color::white())
  assert_eq(surface.get_pixel(1, 0), Color::blue())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame cached redraw presents translucent pixels without reblending" {
  let frame = RenderFrame::new(1, 1)
  frame.get_canvas().clear(Color::white())
  let layer = Layer::new(1, 1).set_opacity(0.5)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  ignore(frame.get_layer_tree().add_layer(layer))
  let cached = Color::new(r=127, g=127, b=255, a=255)

  let first_surface = MemorySurface::new(1, 1)
  assert_true(frame.present_dirty_to(first_surface) == Ok(1))
  assert_eq(first_surface.get_pixel(0, 0), cached)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(0, 0), cached)
  assert_true(!frame.has_dirty())

  let redraw_surface = MemorySurface::new(1, 1)
  match frame.submit_redraw_to(redraw_surface) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Full)
      assert_true(result.get_state() == DirtySubmitState::Clean)
      assert_true(!result.has_dirty())
      assert_true(result.needs_present())
      assert_true(result.did_present())
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected cached translucent redraw submit result")
  }
  assert_eq(redraw_surface.get_present_count(), 1)
  assert_eq(redraw_surface.get_pixel(0, 0), cached)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(0, 0), cached)
  assert_true(!frame.has_dirty())

  let surface = MemorySurface::new(1, 1)
  let request = frame.submit_request_by_policy(
    surface,
    RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_true(request.get_policy() == RenderFrameSubmitPolicy::CachedRedraw)
  assert_true(request.get_action() == RenderFrameScheduleAction::Present)
  assert_true(request.should_submit())
  assert_true(request.needs_present())
  assert_true(!request.has_dirty())
  assert_true(request.get_present_strategy() == DirtyPresentStrategy::Full)
  assert_true(request.get_state() == DirtySubmitState::Clean)
  assert_true(request.get_dirty_bounds() == None)
  assert_true(
    request.get_present_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_eq(request.get_present_rect_count(), 1)
  assert_eq(request.get_present_pixel_count(), 1)
  assert_eq(request.get_present_byte_count(), 4)
  assert_true(!request.saves_full_present_pixels())

  match frame.submit_request_to(surface, request) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Full)
      assert_true(result.get_state() == DirtySubmitState::Clean)
      assert_true(!result.has_dirty())
      assert_true(result.needs_present())
      assert_true(result.did_present())
      assert_true(
        result.get_present_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=1, height=1)),
      )
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected cached translucent submit request result")
  }
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(0, 0), cached)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(0, 0), cached)
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame cached redraw restores clean dirty state after surface error" {
  let frame = RenderFrame::new(1, 1)
  frame.get_canvas().clear(Color::white())
  let layer = Layer::new(1, 1).set_opacity(0.5)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  ignore(frame.get_layer_tree().add_layer(layer))
  let cached = Color::new(r=127, g=127, b=255, a=255)

  assert_true(frame.present_dirty_to(MemorySurface::new(1, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(0, 0), cached)
  assert_true(!frame.has_dirty())

  match frame.submit_redraw_to(RenderFrameFailingSurface::new(1, 1)) {
    Err(PresentError::InvalidDimensions(0, 0)) => ()
    _ => abort("expected cached redraw surface failure")
  }
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(0, 0), cached)
  assert_true(frame.get_canvas().get_dirty_region().is_empty())
  assert_true(frame.get_layer_tree().dirty_bounds() == None)
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame policy schedules dirty-only cached and full redraw paths" {
  let clean_frame = RenderFrame::new(2, 1)
  let clean_surface = MemorySurface::new(2, 1)
  let dirty_only_schedule = clean_frame.submit_schedule_by_policy(
    clean_surface,
    RenderFrameSubmitPolicy::DirtyOnly,
  )
  assert_true(
    dirty_only_schedule.get_action() == RenderFrameScheduleAction::Skip,
  )
  assert_true(
    dirty_only_schedule.get_present_strategy() == DirtyPresentStrategy::Skip,
  )
  assert_true(dirty_only_schedule.get_state() == DirtySubmitState::Clean)
  assert_true(!dirty_only_schedule.needs_present())
  assert_true(dirty_only_schedule.get_present_bounds() == None)
  assert_eq(dirty_only_schedule.get_present_rect_count(), 0)

  let cached_schedule = clean_frame.submit_schedule_by_policy(
    clean_surface,
    RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_true(
    cached_schedule.get_action() == RenderFrameScheduleAction::Present,
  )
  assert_true(
    cached_schedule.get_present_strategy() == DirtyPresentStrategy::Full,
  )
  assert_true(cached_schedule.get_state() == DirtySubmitState::Clean)
  assert_true(cached_schedule.needs_present())
  assert_true(!cached_schedule.has_dirty())
  assert_true(
    cached_schedule.get_present_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
  assert_eq(cached_schedule.get_present_rect_count(), 1)
  assert_eq(cached_schedule.get_present_pixel_count(), 2)
  assert_eq(cached_schedule.get_present_byte_count(), 8)

  let dirty_frame = RenderFrame::new(4, 1)
  dirty_frame.get_canvas().draw_pixel(1, 0, Color::red())
  let dirty_surface = MemorySurface::new(4, 1)
  let cached_dirty_schedule = dirty_frame.submit_schedule_by_policy(
    dirty_surface,
    RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_true(
    cached_dirty_schedule.get_action() == RenderFrameScheduleAction::Present,
  )
  assert_true(
    cached_dirty_schedule.get_present_strategy() ==
    DirtyPresentStrategy::Partial,
  )
  assert_true(cached_dirty_schedule.get_state() == DirtySubmitState::Present)
  assert_true(cached_dirty_schedule.has_dirty())
  assert_true(
    cached_dirty_schedule.get_present_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_eq(cached_dirty_schedule.get_present_rect_count(), 1)
  assert_eq(cached_dirty_schedule.get_present_pixel_count(), 1)
  assert_eq(cached_dirty_schedule.get_present_byte_count(), 4)

  let full_dirty_schedule = dirty_frame.submit_schedule_by_policy(
    dirty_surface,
    RenderFrameSubmitPolicy::FullRedraw,
  )
  assert_true(
    full_dirty_schedule.get_action() == RenderFrameScheduleAction::Present,
  )
  assert_true(
    full_dirty_schedule.get_present_strategy() == DirtyPresentStrategy::Full,
  )
  assert_true(full_dirty_schedule.get_state() == DirtySubmitState::Present)
  assert_true(full_dirty_schedule.has_dirty())
  assert_true(full_dirty_schedule.needs_present())
  assert_true(
    full_dirty_schedule.get_present_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=4, height=1)),
  )
  assert_eq(full_dirty_schedule.get_present_rect_count(), 1)
  assert_eq(full_dirty_schedule.get_present_pixel_count(), 4)
  assert_eq(full_dirty_schedule.get_present_byte_count(), 16)
  assert_true(!full_dirty_schedule.saves_full_present_pixels())
  assert_true(dirty_frame.has_dirty())
  assert_eq(dirty_surface.get_present_count(), 0)
}

///|
test "RenderFrame::submit_to_by_policy executes requested policy" {
  let dirty_frame = RenderFrame::new(4, 1)
  dirty_frame.get_canvas().draw_pixel(1, 0, Color::red())
  let dirty_surface = MemorySurface::new(4, 1)

  match
    dirty_frame.submit_to_by_policy(
      dirty_surface,
      RenderFrameSubmitPolicy::FullRedraw,
    ) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Full)
      assert_true(result.get_state() == DirtySubmitState::Present)
      assert_true(result.has_dirty())
      assert_true(result.did_present())
      assert_true(
        result.get_present_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=4, height=1)),
      )
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 4)
      assert_eq(result.get_present_byte_count(), 16)
    }
    Err(_) => abort("expected policy submit result")
  }
  assert_eq(dirty_surface.get_present_count(), 1)
  assert_eq(dirty_surface.get_pixel(1, 0), Color::red())
  assert_true(!dirty_frame.has_dirty())

  let clean_frame = RenderFrame::new(2, 1)
  let clean_surface = MemorySurface::new(2, 1)
  match
    clean_frame.submit_to_by_policy(
      clean_surface,
      RenderFrameSubmitPolicy::DirtyOnly,
    ) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Skip)
      assert_true(result.get_state() == DirtySubmitState::Clean)
      assert_true(!result.has_dirty())
      assert_true(!result.needs_present())
      assert_true(!result.did_present())
      assert_eq(result.get_presented_rect_count(), 0)
    }
    Err(_) => abort("expected clean dirty-only policy submit result")
  }
  assert_eq(clean_surface.get_present_count(), 0)
}

///|
test "RenderFrame::submit_to_by_policy full redraw presents resized frame" {
  let frame = RenderFrame::new(1, 1)
  frame.get_canvas().draw_pixel(0, 0, Color::red())
  frame.clear_dirty_regions()

  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  ignore(frame.get_layer_tree().add_layer(layer))
  ignore(frame.resize(2, 1))

  let surface = MemorySurface::new(2, 1)
  match
    frame.submit_to_by_policy(surface, RenderFrameSubmitPolicy::FullRedraw) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Full)
      assert_true(result.get_state() == DirtySubmitState::Present)
      assert_true(result.has_dirty())
      assert_true(result.needs_present())
      assert_true(result.did_present())
      assert_true(
        result.get_dirty_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=2, height=1)),
      )
      assert_true(
        result.get_present_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=2, height=1)),
      )
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 2)
      assert_eq(result.get_present_byte_count(), 8)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected resized full redraw policy submit result")
  }
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(0, 0), Color::red())
  assert_eq(surface.get_pixel(1, 0), Color::blue())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame submit requests preserve policy and schedule decisions" {
  let frame = RenderFrame::new(4, 1)
  frame.get_canvas().draw_pixel(1, 0, Color::red())
  let surface = MemorySurface::new(4, 1)

  let request = frame.submit_request_by_policy(
    surface,
    RenderFrameSubmitPolicy::FullRedraw,
  )
  assert_true(request.get_policy() == RenderFrameSubmitPolicy::FullRedraw)
  assert_true(request.get_action() == RenderFrameScheduleAction::Present)
  assert_true(request.should_submit())
  assert_true(request.needs_present())
  assert_true(request.has_dirty())
  assert_true(!request.was_clipped_away())
  assert_true(!request.uses_bounds_fallback())
  assert_true(request.get_present_strategy() == DirtyPresentStrategy::Full)
  assert_true(request.get_state() == DirtySubmitState::Present)
  assert_true(
    request.get_dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_true(
    request.get_present_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=4, height=1)),
  )
  assert_true(
    request.get_schedule().get_submit_plan().get_present_strategy() ==
    DirtyPresentStrategy::Full,
  )
  assert_eq(request.get_present_rect_count(), 1)
  assert_eq(request.get_present_pixel_count(), 4)
  assert_eq(request.get_present_byte_count(), 16)
  assert_true(!request.saves_full_present_pixels())
  assert_eq(surface.get_present_count(), 0)
  assert_true(frame.has_dirty())

  match frame.submit_request_to(surface, request) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Full)
      assert_true(result.get_state() == DirtySubmitState::Present)
      assert_true(result.did_present())
      assert_true(
        result.get_present_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=4, height=1)),
      )
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 4)
      assert_eq(result.get_present_byte_count(), 16)
    }
    Err(_) => abort("expected submit request result")
  }
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(1, 0), Color::red())
  assert_true(!frame.has_dirty())

  let clean_frame = RenderFrame::new(2, 1)
  let clean_surface = MemorySurface::new(2, 1)
  let clean_schedule = clean_frame.submit_schedule_by_policy(
    clean_surface,
    RenderFrameSubmitPolicy::DirtyOnly,
  )
  let clean_request = RenderFrameSubmitRequest::new(
    RenderFrameSubmitPolicy::DirtyOnly,
    clean_schedule,
  )
  assert_true(clean_request.get_policy() == RenderFrameSubmitPolicy::DirtyOnly)
  assert_true(clean_request.get_action() == RenderFrameScheduleAction::Skip)
  assert_true(!clean_request.should_submit())
  assert_true(!clean_request.needs_present())
  assert_true(!clean_request.has_dirty())
  assert_true(clean_request.get_dirty_bounds() == None)
  assert_true(clean_request.get_present_bounds() == None)
  match clean_frame.submit_request_to(clean_surface, clean_request) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Skip)
      assert_true(result.get_state() == DirtySubmitState::Clean)
      assert_true(!result.did_present())
      assert_eq(result.get_presented_rect_count(), 0)
    }
    Err(_) => abort("expected clean submit request result")
  }
  assert_eq(clean_surface.get_present_count(), 0)

  let cached_frame = RenderFrame::new(1, 1)
  cached_frame.get_canvas().draw_pixel(0, 0, Color::green())
  cached_frame.clear_dirty_regions()
  let clipped_surface = MemorySurface::new(0, 1)
  let clipped_request = cached_frame.submit_request_by_policy(
    clipped_surface,
    RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_true(
    clipped_request.get_policy() == RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_true(clipped_request.get_action() == RenderFrameScheduleAction::Skip)
  assert_true(
    clipped_request.get_present_strategy() == DirtyPresentStrategy::Full,
  )
  assert_true(clipped_request.get_state() == DirtySubmitState::Clean)
  assert_true(!clipped_request.needs_present())
  assert_true(!clipped_request.has_dirty())
  assert_eq(clipped_request.get_present_rect_count(), 0)

  let present_surface = MemorySurface::new(1, 1)
  match cached_frame.submit_request_to(present_surface, clipped_request) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Full)
      assert_true(result.get_state() == DirtySubmitState::Clean)
      assert_true(result.needs_present())
      assert_true(result.did_present())
      assert_true(!result.has_dirty())
      assert_true(
        result.get_present_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=1, height=1)),
      )
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
    }
    Err(_) => abort("expected cached redraw request to keep policy")
  }
  assert_eq(present_surface.get_present_count(), 1)
  assert_eq(present_surface.get_pixel(0, 0), Color::green())
  assert_true(!cached_frame.has_dirty())
}

///|
test "RenderFrame submit requests use resized full redraw telemetry" {
  let frame = RenderFrame::new(1, 1)
  frame.get_canvas().draw_pixel(0, 0, Color::red())
  frame.clear_dirty_regions()

  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  ignore(frame.get_layer_tree().add_layer(layer))
  ignore(frame.resize(2, 1))

  let surface = MemorySurface::new(2, 1)
  let request = frame.submit_request_by_policy(
    surface,
    RenderFrameSubmitPolicy::FullRedraw,
  )
  assert_true(request.get_policy() == RenderFrameSubmitPolicy::FullRedraw)
  assert_true(request.get_action() == RenderFrameScheduleAction::Present)
  assert_true(request.should_submit())
  assert_true(request.needs_present())
  assert_true(request.has_dirty())
  assert_true(!request.was_clipped_away())
  assert_true(!request.uses_bounds_fallback())
  assert_true(request.get_present_strategy() == DirtyPresentStrategy::Full)
  assert_true(request.get_state() == DirtySubmitState::Present)
  assert_true(
    request.get_dirty_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
  assert_true(
    request.get_present_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
  assert_eq(request.get_present_rect_count(), 1)
  assert_eq(request.get_present_pixel_count(), 2)
  assert_eq(request.get_present_byte_count(), 8)
  assert_true(!request.saves_full_present_pixels())
  assert_eq(surface.get_present_count(), 0)
  assert_true(frame.has_dirty())

  match frame.submit_request_to(surface, request) {
    Ok(result) => {
      assert_true(result.get_present_strategy() == DirtyPresentStrategy::Full)
      assert_true(result.get_state() == DirtySubmitState::Present)
      assert_true(result.did_present())
      assert_true(
        result.get_present_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=2, height=1)),
      )
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 2)
      assert_eq(result.get_present_byte_count(), 8)
    }
    Err(_) => abort("expected resized full redraw submit request result")
  }
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(0, 0), Color::red())
  assert_eq(surface.get_pixel(1, 0), Color::blue())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame dirty helpers cover canvas and layer tree dirtiness" {
  let frame = RenderFrame::new(4, 2)
  assert_true(!frame.has_dirty())
  assert_true(frame.dirty_bounds() == None)

  frame.mark_dirty_rect(PixelRect::new(x=1, y=0, width=1, height=1))
  assert_true(frame.has_dirty())
  assert_true(
    frame.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  let layer = Layer::new(1, 1).set_position(3, 1)
  layer.get_canvas().draw_pixel(0, 0, Color::green())
  ignore(frame.get_layer_tree().add_layer(layer))
  assert_true(
    frame.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=3, height=2)),
  )

  frame.clear_dirty_regions()
  frame.mark_all_dirty()
  assert_true(
    frame.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=4, height=2)),
  )
}

///|
test "RenderFrame::present_all_to marks and presents the whole frame" {
  let frame = RenderFrame::new(2, 1)
  let layer = Layer::new(2, 1)
  layer.clear(Color::white())
  layer.get_canvas().draw_pixel(1, 0, Color::blue())
  ignore(frame.get_layer_tree().add_layer(layer))
  assert_true(frame.present_dirty_to(MemorySurface::new(2, 1)) == Ok(1))
  assert_true(!frame.has_dirty())

  let surface = MemorySurface::new(2, 1)
  let result = frame.present_all_to(surface)
  assert_true(result == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(0, 0), Color::white())
  assert_eq(surface.get_pixel(1, 0), Color::blue())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::present_all_to preserves dirty state after surface error" {
  let frame = RenderFrame::new(2, 1)
  let layer = Layer::new(2, 1)
  layer.get_canvas().draw_pixel(0, 0, Color::red())
  ignore(frame.get_layer_tree().add_layer(layer))
  assert_true(frame.present_dirty_to(MemorySurface::new(2, 1)) == Ok(1))

  match frame.present_all_to(RenderFrameFailingSurface::new(2, 1)) {
    Err(PresentError::InvalidDimensions(0, 0)) => ()
    _ => abort("expected surface failure")
  }
  assert_true(frame.has_dirty())
  assert_true(
    frame.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "RenderFrame::resize preserves overlapping pixels and marks new frame dirty" {
  let frame = RenderFrame::new(2, 1)
  frame.get_canvas().draw_pixel(0, 0, Color::red())
  frame.get_canvas().draw_pixel(1, 0, Color::blue())
  frame.clear_dirty_regions()

  ignore(frame.resize(3, 2))
  assert_eq(frame.get_width(), 3)
  assert_eq(frame.get_height(), 2)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(0, 0), Color::red())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::blue())
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 1),
    Color::transparent(),
  )
  assert_true(
    frame.get_canvas().get_dirty_region().bounds() ==
    Some(PixelRect::new(x=0, y=0, width=3, height=2)),
  )

  ignore(frame.resize(1, 1))
  assert_eq(frame.get_width(), 1)
  assert_eq(frame.get_height(), 1)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(0, 0), Color::red())
  assert_true(
    frame.get_canvas().get_dirty_region().bounds() ==
    Some(PixelRect::new(x=0, y=0, width=1, height=1)),
  )
}

///|
test "RenderFrame::resize retains layer tree and dirty present policy" {
  let frame = RenderFrame::new(2, 1).set_dirty_rect_limit(2)
  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::green())
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)

  ignore(frame.resize(3, 2))
  assert_eq(frame.get_dirty_rect_limit(), 2)
  assert_eq(frame.get_layer_tree().get_layer_count(), 1)
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=1, y=0, width=1, height=1)),
  )
}

///|
test "RenderFrame::resize presents resized frame and retained dirty layers" {
  let frame = RenderFrame::new(1, 1)
  frame.get_canvas().draw_pixel(0, 0, Color::red())
  frame.clear_dirty_regions()

  let layer = Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, Color::blue())
  ignore(frame.get_layer_tree().add_layer(layer))

  ignore(frame.resize(2, 1))
  let surface = MemorySurface::new(2, 1)
  let white = Pixmap::new(2, 1)
  white.clear(Color::white())
  assert_true(white.present_to(surface) == Ok(()))

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 2)
  assert_eq(surface.get_pixel(0, 0), Color::red())
  assert_eq(surface.get_pixel(1, 0), Color::blue())
  assert_true(frame.get_canvas().get_dirty_region().is_empty())
  assert_true(frame.get_layer_tree().dirty_bounds() == None)
}

///|
test "RenderFrame::resize_and_clear_layer resizes frame background layer" {
  let frame = RenderFrame::new(2, 1)
  let background = Layer::new(2, 1)
  background.clear(Color::white())
  let top = Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, Color::red())

  let tree = frame.get_layer_tree()
  assert_eq(tree.add_layer(background), 0)
  assert_eq(tree.add_layer(top), 1)
  assert_true(frame.present_dirty_to(MemorySurface::new(2, 1)) == Ok(1))
  assert_true(!frame.has_dirty())

  assert_true(frame.resize_and_clear_layer(0, 3, 2, Color::blue()))
  assert_eq(frame.get_width(), 3)
  assert_eq(frame.get_height(), 2)
  match tree.get_layer(0) {
    Some(resized_background) => {
      assert_eq(resized_background.get_width(), 3)
      assert_eq(resized_background.get_height(), 2)
      assert_eq(resized_background.get_pixmap().get_pixel(0, 0), Color::blue())
      assert_eq(resized_background.get_pixmap().get_pixel(2, 1), Color::blue())
      assert_true(
        resized_background.dirty_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=3, height=2)),
      )
    }
    None => abort("expected resized background layer")
  }
  assert_true(
    frame.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=3, height=2)),
  )

  let surface = MemorySurface::new(3, 2)
  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_pixel(0, 0), Color::blue())
  assert_eq(surface.get_pixel(1, 0), Color::red())
  assert_eq(surface.get_pixel(2, 1), Color::blue())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::resize_and_clear_layer clears same-size layer" {
  let frame = RenderFrame::new(2, 1)
  let background = Layer::new(2, 1)
  background.clear(Color::white())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_true(frame.present_dirty_to(MemorySurface::new(2, 1)) == Ok(1))
  assert_true(!frame.has_dirty())

  assert_true(frame.resize_and_clear_layer(0, 2, 1, Color::green()))
  assert_eq(frame.get_width(), 2)
  assert_eq(frame.get_height(), 1)
  match frame.get_layer_tree().get_layer(0) {
    Some(layer) => {
      assert_eq(layer.get_pixmap().get_pixel(0, 0), Color::green())
      assert_eq(layer.get_pixmap().get_pixel(1, 0), Color::green())
      assert_true(
        layer.dirty_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=2, height=1)),
      )
    }
    None => abort("expected background layer")
  }
  assert_true(
    frame.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "RenderFrame::resize_and_clear_layers resizes multiple frame layers" {
  let frame = RenderFrame::new(2, 1)
  let background = Layer::new(2, 1)
  background.clear(Color::white())
  let overlay = Layer::new(2, 1)
  overlay.clear(Color::transparent())
  let tree = frame.get_layer_tree()
  assert_eq(tree.add_layer(background), 0)
  assert_eq(tree.add_layer(overlay), 1)
  assert_true(frame.present_dirty_to(MemorySurface::new(2, 1)) == Ok(1))
  assert_true(!frame.has_dirty())

  assert_true(
    frame.resize_and_clear_layers(3, 2, [
      RenderFrameLayerClearRequest::new(0, Color::blue()),
      RenderFrameLayerClearRequest::new(1, Color::green()),
    ]),
  )
  assert_eq(frame.get_width(), 3)
  assert_eq(frame.get_height(), 2)
  match tree.get_layer(0) {
    Some(layer) => {
      assert_eq(layer.get_width(), 3)
      assert_eq(layer.get_height(), 2)
      assert_eq(layer.get_pixmap().get_pixel(0, 0), Color::blue())
      assert_eq(layer.get_pixmap().get_pixel(2, 1), Color::blue())
      assert_true(
        layer.dirty_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=3, height=2)),
      )
    }
    None => abort("expected background layer")
  }
  match tree.get_layer(1) {
    Some(layer) => {
      assert_eq(layer.get_width(), 3)
      assert_eq(layer.get_height(), 2)
      assert_eq(layer.get_pixmap().get_pixel(0, 0), Color::green())
      assert_eq(layer.get_pixmap().get_pixel(2, 1), Color::green())
      assert_true(
        layer.dirty_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=3, height=2)),
      )
    }
    None => abort("expected overlay layer")
  }
  assert_true(
    frame.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=3, height=2)),
  )

  let surface = MemorySurface::new(3, 2)
  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_pixel(0, 0), Color::green())
  assert_eq(surface.get_pixel(2, 1), Color::green())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::resize_and_clear_layers validates all layers before mutation" {
  let frame = RenderFrame::new(2, 1)
  let background = Layer::new(2, 1)
  background.clear(Color::white())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_true(frame.present_dirty_to(MemorySurface::new(2, 1)) == Ok(1))
  assert_true(!frame.has_dirty())

  assert_true(
    !frame.resize_and_clear_layers(3, 2, [
      RenderFrameLayerClearRequest::new(0, Color::blue()),
      RenderFrameLayerClearRequest::new(3, Color::red()),
    ]),
  )
  assert_eq(frame.get_width(), 2)
  assert_eq(frame.get_height(), 1)
  match frame.get_layer_tree().get_layer(0) {
    Some(layer) => {
      assert_eq(layer.get_width(), 2)
      assert_eq(layer.get_height(), 1)
      assert_eq(layer.get_pixmap().get_pixel(0, 0), Color::white())
      assert_true(layer.dirty_bounds() == None)
    }
    None => abort("expected background layer")
  }
  assert_true(!frame.has_dirty())

  assert_true(!frame.resize_and_clear_layers(2, 1, []))
  assert_true(
    !frame.resize_and_clear_layers(0, 1, [
      RenderFrameLayerClearRequest::new(0, Color::blue()),
    ]),
  )
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::replace_layer invalidates old and new layer bounds" {
  let frame = RenderFrame::new(4, 1)
  let background = Layer::new(4, 1)
  background.clear(Color::white())
  let old_top = Layer::new(1, 1).set_position(1, 0)
  old_top.get_canvas().draw_pixel(0, 0, Color::red())
  let tree = frame.get_layer_tree()
  assert_eq(tree.add_layer(background), 0)
  assert_eq(tree.add_layer(old_top), 1)
  let surface = MemorySurface::new(4, 1)
  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_true(!frame.has_dirty())

  let new_top = Layer::new(1, 1).set_position(2, 0)
  new_top.get_canvas().draw_pixel(0, 0, Color::green())
  match frame.replace_layer(1, new_top) {
    Some(replaced) => {
      assert_eq(replaced.get_x(), 1)
      assert_eq(replaced.get_pixmap().get_pixel(0, 0), Color::red())
    }
    None => abort("expected replaced frame layer")
  }
  assert_true(
    frame.dirty_bounds() == Some(PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_pixel(0, 0), Color::white())
  assert_eq(surface.get_pixel(1, 0), Color::white())
  assert_eq(surface.get_pixel(2, 0), Color::green())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::replace_layers validates all layers before mutation" {
  let frame = RenderFrame::new(3, 1)
  let background = Layer::new(3, 1)
  background.clear(Color::white())
  let left = Layer::new(1, 1)
  left.get_canvas().draw_pixel(0, 0, Color::red())
  let middle = Layer::new(1, 1).set_position(1, 0)
  middle.get_canvas().draw_pixel(0, 0, Color::green())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(left), 1)
  assert_eq(frame.get_layer_tree().add_layer(middle), 2)
  assert_true(frame.present_dirty_to(MemorySurface::new(3, 1)) == Ok(1))
  assert_true(!frame.has_dirty())

  let new_left = Layer::new(1, 1)
  new_left.get_canvas().draw_pixel(0, 0, Color::blue())
  let invalid_layer = Layer::new(1, 1).set_position(2, 0)
  invalid_layer.get_canvas().draw_pixel(0, 0, Color::black())
  assert_true(
    !frame.replace_layers([
      RenderFrameLayerReplacementRequest::new(1, new_left),
      RenderFrameLayerReplacementRequest::new(4, invalid_layer),
    ]),
  )
  match frame.get_layer_tree().get_layer(1) {
    Some(layer) => assert_eq(layer.get_pixmap().get_pixel(0, 0), Color::red())
    None => abort("expected original left layer")
  }
  assert_true(!frame.has_dirty())
  assert_true(!frame.replace_layers([]))

  let replacement_left = Layer::new(1, 1)
  replacement_left.get_canvas().draw_pixel(0, 0, Color::blue())
  let replacement_middle = Layer::new(1, 1).set_position(2, 0)
  replacement_middle.get_canvas().draw_pixel(0, 0, Color::black())
  assert_true(
    frame.replace_layers([
      RenderFrameLayerReplacementRequest::new(1, replacement_left),
      RenderFrameLayerReplacementRequest::new(2, replacement_middle),
    ]),
  )
  assert_true(
    frame.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=3, height=1)),
  )
  let surface = MemorySurface::new(3, 1)
  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_pixel(0, 0), Color::blue())
  assert_eq(surface.get_pixel(1, 0), Color::white())
  assert_eq(surface.get_pixel(2, 0), Color::black())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::resize_clear_and_replace_layers applies GUI redraw lifecycle" {
  let frame = RenderFrame::new(2, 1)
  let background = Layer::new(2, 1)
  background.clear(Color::white())
  let text = Layer::new(1, 1).set_position(1, 0)
  text.get_canvas().draw_pixel(0, 0, Color::red())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(text), 1)
  assert_true(frame.present_dirty_to(MemorySurface::new(2, 1)) == Ok(1))
  assert_true(!frame.has_dirty())

  let new_text = Layer::new(1, 1).set_position(2, 1)
  new_text.get_canvas().draw_pixel(0, 0, Color::green())
  assert_true(
    frame.resize_clear_and_replace_layers(
      3,
      2,
      [RenderFrameLayerClearRequest::new(0, Color::blue())],
      [RenderFrameLayerReplacementRequest::new(1, new_text)],
    ),
  )
  assert_eq(frame.get_width(), 3)
  assert_eq(frame.get_height(), 2)
  match frame.get_layer_tree().get_layer(0) {
    Some(layer) => {
      assert_eq(layer.get_width(), 3)
      assert_eq(layer.get_height(), 2)
      assert_eq(layer.get_pixmap().get_pixel(0, 0), Color::blue())
      assert_eq(layer.get_pixmap().get_pixel(2, 1), Color::blue())
    }
    None => abort("expected resized background layer")
  }
  match frame.get_layer_tree().get_layer(1) {
    Some(layer) => {
      assert_eq(layer.get_x(), 2)
      assert_eq(layer.get_y(), 1)
      assert_eq(layer.get_pixmap().get_pixel(0, 0), Color::green())
    }
    None => abort("expected replacement layer")
  }
  assert_true(
    frame.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=3, height=2)),
  )

  let surface = MemorySurface::new(3, 2)
  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_pixel(0, 0), Color::blue())
  assert_eq(surface.get_pixel(1, 0), Color::blue())
  assert_eq(surface.get_pixel(2, 1), Color::green())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::resize_clear_and_replace_layers materializes full-frame dirty batch" {
  let frame = RenderFrame::new(2, 1)
  let background = Layer::new(2, 1)
  background.clear(Color::white())
  let text = Layer::new(1, 1).set_position(1, 0)
  text.get_canvas().draw_pixel(0, 0, Color::red())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(text), 1)
  assert_true(frame.present_dirty_to(MemorySurface::new(2, 1)) == Ok(1))
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_true(!frame.has_dirty())

  let new_text = Layer::new(1, 1).set_position(2, 1)
  new_text.get_canvas().draw_pixel(0, 0, Color::green())
  assert_true(
    frame.resize_clear_and_replace_layers(
      3,
      2,
      [RenderFrameLayerClearRequest::new(0, Color::blue())],
      [RenderFrameLayerReplacementRequest::new(1, new_text)],
    ),
  )
  assert_true(
    frame.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=3, height=2)),
  )

  let plan_surface = MemorySurface::new(3, 2)
  let submit_plan = frame.dirty_submit_plan(plan_surface)
  assert_true(submit_plan.get_state() == DirtySubmitState::Present)
  assert_true(submit_plan.has_dirty())
  assert_true(submit_plan.needs_present())
  assert_true(
    submit_plan.get_dirty_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=3, height=2)),
  )
  assert_true(
    submit_plan.get_present_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=3, height=2)),
  )
  assert_true(
    submit_plan.get_present_strategy(3, 2) == DirtyPresentStrategy::Full,
  )
  assert_eq(submit_plan.get_present_rect_count(), 1)
  assert_eq(submit_plan.get_present_pixel_count(), 6)
  assert_eq(submit_plan.get_present_byte_count(), 24)
  assert_true(!submit_plan.saves_full_present_pixels(3, 2))
  assert_true(!submit_plan.uses_bounds_fallback())
  let present_plan = submit_plan.get_present_plan()
  assert_true(present_plan.get_mode() == DirtyPresentPlanMode::Rects)
  assert_true(
    present_plan.get_rects()[0] == PixelRect::new(x=0, y=0, width=3, height=2),
  )

  let surface = MemorySurface::new(3, 2)
  match frame.dirty_present_batch(surface) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 6)
      assert_eq(batch.get_present_byte_count(), 24)
      assert_true(
        batch.get_present_bounds() ==
        Some(PixelRect::new(x=0, y=0, width=3, height=2)),
      )
      assert_true(
        batch.get_present_strategy(3, 2) == DirtyPresentStrategy::Full,
      )
      assert_true(!batch.saves_full_present_pixels(3, 2))
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() == PixelRect::new(x=0, y=0, width=3, height=2),
      )
      assert_eq(payloads[0].get_row_bytes(), 12)
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 24)
      assert_eq(pixels[0], Color::blue().r)
      assert_eq(pixels[1], Color::blue().g)
      assert_eq(pixels[2], Color::blue().b)
      assert_eq(pixels[3], Color::blue().a)
      assert_eq(pixels[4], Color::blue().r)
      assert_eq(pixels[5], Color::blue().g)
      assert_eq(pixels[6], Color::blue().b)
      assert_eq(pixels[7], Color::blue().a)
      assert_eq(pixels[20], Color::green().r)
      assert_eq(pixels[21], Color::green().g)
      assert_eq(pixels[22], Color::green().b)
      assert_eq(pixels[23], Color::green().a)
    }
    Err(_) => abort("expected resize lifecycle dirty present batch")
  }

  assert_eq(surface.get_present_count(), 0)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(0, 0), Color::white())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::red())
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 1),
    Color::transparent(),
  )
  assert_true(frame.has_dirty())

  assert_true(frame.present_dirty_to(surface) == Ok(1))
  assert_eq(surface.get_present_count(), 1)
  assert_eq(surface.get_pixel(0, 0), Color::blue())
  assert_eq(surface.get_pixel(1, 0), Color::blue())
  assert_eq(surface.get_pixel(2, 1), Color::green())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(0, 0), Color::blue())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), Color::blue())
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 1), Color::green())
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::resize_clear_and_replace_layers validates before mutation" {
  let frame = RenderFrame::new(2, 1)
  let background = Layer::new(2, 1)
  background.clear(Color::white())
  let text = Layer::new(1, 1).set_position(1, 0)
  text.get_canvas().draw_pixel(0, 0, Color::red())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(text), 1)
  assert_true(frame.present_dirty_to(MemorySurface::new(2, 1)) == Ok(1))
  assert_true(!frame.has_dirty())

  let invalid_text = Layer::new(1, 1)
  invalid_text.get_canvas().draw_pixel(0, 0, Color::green())
  assert_true(
    !frame.resize_clear_and_replace_layers(
      3,
      2,
      [RenderFrameLayerClearRequest::new(0, Color::blue())],
      [RenderFrameLayerReplacementRequest::new(3, invalid_text)],
    ),
  )
  assert_eq(frame.get_width(), 2)
  assert_eq(frame.get_height(), 1)
  match frame.get_layer_tree().get_layer(0) {
    Some(layer) => {
      assert_eq(layer.get_width(), 2)
      assert_eq(layer.get_height(), 1)
      assert_eq(layer.get_pixmap().get_pixel(0, 0), Color::white())
      assert_true(layer.dirty_bounds() == None)
    }
    None => abort("expected original background layer")
  }
  match frame.get_layer_tree().get_layer(1) {
    Some(layer) => {
      assert_eq(layer.get_x(), 1)
      assert_eq(layer.get_pixmap().get_pixel(0, 0), Color::red())
      assert_true(layer.dirty_bounds() == None)
    }
    None => abort("expected original text layer")
  }
  assert_true(!frame.has_dirty())

  assert_true(!frame.resize_clear_and_replace_layers(2, 1, [], []))
  assert_true(
    !frame.resize_clear_and_replace_layers(
      0,
      1,
      [RenderFrameLayerClearRequest::new(0, Color::blue())],
      [],
    ),
  )
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame::resize_and_clear_layer rejects invalid lifecycle requests" {
  let frame = RenderFrame::new(2, 1)
  let background = Layer::new(2, 1)
  background.clear(Color::white())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_true(frame.present_dirty_to(MemorySurface::new(2, 1)) == Ok(1))
  assert_true(!frame.has_dirty())

  assert_true(!frame.resize_and_clear_layer(2, 3, 2, Color::blue()))
  assert_eq(frame.get_width(), 2)
  assert_eq(frame.get_height(), 1)
  match frame.get_layer_tree().get_layer(0) {
    Some(layer) => {
      assert_eq(layer.get_width(), 2)
      assert_eq(layer.get_height(), 1)
      assert_eq(layer.get_pixmap().get_pixel(0, 0), Color::white())
      assert_true(layer.dirty_bounds() == None)
    }
    None => abort("expected background layer")
  }
  assert_true(!frame.has_dirty())

  assert_true(!frame.resize_and_clear_layer(0, 0, 2, Color::blue()))
  assert_eq(frame.get_width(), 2)
  assert_eq(frame.get_height(), 1)
  assert_true(!frame.has_dirty())
}

///|
test "RenderFrame preserves dirty state after surface error" {
  let frame = RenderFrame::new(2, 1)
  let surface = RenderFrameFailingSurface::new(2, 1)
  let layer = Layer::new(2, 1)
  layer.get_canvas().draw_pixel(1, 0, Color::red())
  ignore(frame.get_layer_tree().add_layer(layer))

  match frame.present_dirty_to(surface) {
    Err(PresentError::InvalidDimensions(0, 0)) => ()
    _ => abort("expected surface failure")
  }
  assert_true(frame.get_canvas().get_dirty_region().is_empty())
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
  assert_true(
    frame.dirty_bounds() == Some(PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
struct RenderFrameFailingSurface {
  width : Int
  height : Int
} derive(Debug)

///|
fn RenderFrameFailingSurface::new(
  width : Int,
  height : Int,
) -> RenderFrameFailingSurface {
  { width, height }
}

///|
impl Surface for RenderFrameFailingSurface with fn get_width(self) {
  self.width
}

///|
impl Surface for RenderFrameFailingSurface with fn get_height(self) {
  self.height
}

///|
impl Surface for RenderFrameFailingSurface with fn present_pixels(
  self,
  width,
  height,
  row_bytes,
  pixels,
) {
  ignore(self)
  ignore(width)
  ignore(height)
  ignore(row_bytes)
  ignore(pixels)
  Err(PresentError::InvalidDimensions(0, 0))
}

///|
impl Surface for RenderFrameFailingSurface with fn present_pixels_rect(
  self,
  x,
  y,
  width,
  height,
  row_bytes,
  pixels,
) {
  ignore(self)
  ignore(x)
  ignore(y)
  ignore(width)
  ignore(height)
  ignore(row_bytes)
  ignore(pixels)
  Err(PresentError::InvalidDimensions(0, 0))
}
