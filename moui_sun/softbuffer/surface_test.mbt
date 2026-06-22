///|
test "NativeSurface exposes size and handle" {
  let surface = NativeSurface::new(42, 3, 2)
  assert_eq(surface.get_width(), 3)
  assert_eq(surface.get_height(), 2)
  assert_eq(surface.handle(), 42)
  surface.resize(4, 5)
  assert_eq(surface.get_width(), 4)
  assert_eq(surface.get_height(), 5)
}

///|
test "NativeSurface normalizes invalid stored dimensions" {
  let count = Ref(0)
  let surface = NativeSurface::new(42, -2, 3).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_eq(surface.get_width(), 0)
  assert_eq(surface.get_height(), 3)
  assert_eq(surface.handle(), 42)

  let pixels : FixedArray[Byte] = FixedArray::make(12, 0)
  assert_true(
    surface.present(pixels) ==
    Err(@graphics.PresentError::InvalidDimensions(0, 3)),
  )
  assert_eq(count.val, 0)

  surface.resize(-4, -5)
  assert_eq(surface.get_width(), 0)
  assert_eq(surface.get_height(), 0)
  let empty_pixels : FixedArray[Byte] = FixedArray::make(0, 0)
  assert_true(
    surface.present(empty_pixels) ==
    Err(@graphics.PresentError::InvalidDimensions(0, 0)),
  )
  assert_eq(count.val, 0)

  surface.resize(2, 1)
  assert_eq(surface.get_width(), 2)
  assert_eq(surface.get_height(), 1)
  let valid_pixels : FixedArray[Byte] = FixedArray::make(8, 0)
  assert_true(surface.present(valid_pixels) == Ok(()))
  assert_eq(count.val, 1)
}

///|
test "NativeSurface syncs RenderFrame dimensions" {
  let surface = NativeSurface::new(42, 1, 1)
  let frame = @graphics.RenderFrame::new(3, 2)
  assert_true(!surface.matches_frame(frame))
  assert_true(surface.sync_frame_size(frame))
  assert_true(surface.matches_frame(frame))
  assert_eq(surface.get_width(), 3)
  assert_eq(surface.get_height(), 2)
  assert_true(!surface.sync_frame_size(frame))

  ignore(frame.resize(4, 1))
  assert_true(!surface.matches_frame(frame))
  assert_true(surface.sync_frame_size(frame))
  assert_true(surface.matches_frame(frame))
  assert_eq(surface.get_width(), 4)
  assert_eq(surface.get_height(), 1)
}

///|
test "NativeSurface validates present parameters" {
  let surface = NativeSurface::new(42, 2, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(16, 0)
  assert_true(
    surface.present_pixels(0, 2, 8, pixels) ==
    Err(@graphics.PresentError::InvalidDimensions(0, 2)),
  )
  assert_true(
    surface.present_pixels(1, 2, 4, pixels) ==
    Err(@graphics.PresentError::SizeMismatch(2, 2, 1, 2)),
  )
  assert_true(
    surface.present_pixels_rect(2, 1, 1, 1, 4, pixels) ==
    Err(@graphics.PresentError::RectOutOfBounds(2, 1, 1, 1, 2, 2)),
  )
  assert_true(
    surface.present_pixels(2, 2, 4, pixels) ==
    Err(@graphics.PresentError::InvalidRowBytes(4, 8)),
  )
  assert_true(
    surface.present_pixels_rect(0, 0, 2, 2, 4, pixels) ==
    Err(@graphics.PresentError::InvalidRowBytes(4, 8)),
  )
  let short_pixels : FixedArray[Byte] = FixedArray::make(15, 0)
  assert_true(
    surface.present_pixels(2, 2, 8, short_pixels) ==
    Err(@graphics.PresentError::PixelBufferTooSmall(15, 16)),
  )
  let short_rect_pixels : FixedArray[Byte] = FixedArray::make(19, 0)
  assert_true(
    surface.present_pixels_rect(0, 0, 2, 2, 12, short_rect_pixels) ==
    Err(@graphics.PresentError::PixelBufferTooSmall(19, 20)),
  )
}

///|
test "NativeSurface dispatches through graphics Surface trait" {
  let surface = NativeSurface::new(42, 2, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(16, 0)
  let result = @graphics.present_pixels(surface, 2, 2, 4, pixels)
  assert_true(result == Err(@graphics.PresentError::InvalidRowBytes(4, 8)))
  let rect_result = @graphics.present_pixels_rect(
    surface, 1, 1, 1, 1, 4, pixels,
  )
  assert_true(rect_result == Ok(()))
}

///|
test "NativeSurface accepts padded row bytes through shared validation" {
  let surface = NativeSurface::new(42, 1, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(12, 0)
  let result = surface.present_pixels(1, 2, 8, pixels)
  assert_true(result == Ok(()))
}

///|
test "NativeSurface::present uses validated full-frame present path" {
  let count = Ref(0)
  let surface = NativeSurface::new(42, 2, 2).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  let pixels : FixedArray[Byte] = FixedArray::make(16, 0)
  assert_true(surface.present(pixels) == Ok(()))
  assert_eq(count.val, 1)

  let short_pixels : FixedArray[Byte] = FixedArray::make(15, 0)
  assert_true(
    surface.present(short_pixels) ==
    Err(@graphics.PresentError::PixelBufferTooSmall(15, 16)),
  )
  assert_eq(count.val, 1)

  let zero = NativeSurface::new(42, 0, 2).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(
    zero.present(pixels) == Err(@graphics.PresentError::InvalidDimensions(0, 2)),
  )
  assert_eq(count.val, 1)
}

///|
test "NativeSurface calls pre-present hook only after validation" {
  let count = Ref(0)
  let surface = NativeSurface::new(42, 2, 2).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  let pixels : FixedArray[Byte] = FixedArray::make(16, 0)

  assert_true(
    surface.present_pixels(2, 2, 4, pixels) ==
    Err(@graphics.PresentError::InvalidRowBytes(4, 8)),
  )
  assert_eq(count.val, 0)

  assert_true(
    surface.present_pixels_rect(0, 0, 2, 2, 4, pixels) ==
    Err(@graphics.PresentError::InvalidRowBytes(4, 8)),
  )
  assert_eq(count.val, 0)

  let short_rect_pixels : FixedArray[Byte] = FixedArray::make(19, 0)
  assert_true(
    surface.present_pixels_rect(0, 0, 2, 2, 12, short_rect_pixels) ==
    Err(@graphics.PresentError::PixelBufferTooSmall(19, 20)),
  )
  assert_eq(count.val, 0)

  assert_true(surface.present_pixels(2, 2, 8, pixels) == Ok(()))
  assert_eq(count.val, 1)

  assert_true(surface.present_pixels_rect(1, 1, 1, 1, 4, pixels) == Ok(()))
  assert_eq(count.val, 2)

  let padded : FixedArray[Byte] = FixedArray::make(12, 0)
  assert_true(surface.present_pixels_rect(0, 0, 1, 2, 8, padded) == Ok(()))
  assert_eq(count.val, 3)

  let without_hook = surface.clear_pre_present_hook()
  assert_true(without_hook.present_pixels(2, 2, 8, pixels) == Ok(()))
  assert_eq(count.val, 3)
}

///|
test "NativeSurface builds from RenderFrame dimensions" {
  let frame = @graphics.RenderFrame::new(3, 2)
  let surface = NativeSurface::from_frame(42, frame)
  assert_eq(surface.handle(), 42)
  assert_eq(surface.get_width(), 3)
  assert_eq(surface.get_height(), 2)
}

///|
test "NativeSurface present_frame_all calls hook and consumes full-frame lifecycle" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(2, 1)
  let layer = @graphics.Layer::new(2, 1)
  layer.clear(@graphics.Color::white())
  layer.get_canvas().draw_pixel(1, 0, @graphics.Color::blue())
  ignore(frame.get_layer_tree().add_layer(layer))

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_eq(count.val, 0)
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::white(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::blue(),
  )
  assert_true(!frame.has_dirty())
  assert_true(surface.present_frame_dirty(frame) == Ok(0))
  assert_eq(count.val, 1)
  assert_true(surface.present_frame_all(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_true(!frame.has_dirty())
  assert_true(surface.present_frame_all(frame) == Ok(1))
  assert_eq(count.val, 3)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface exposes RenderFrame dirty submit plans" {
  let frame = @graphics.RenderFrame::new(8, 1).set_dirty_rect_limit(2)
  frame.get_canvas().draw_pixel(0, 0, @graphics.Color::red())

  let middle = @graphics.Layer::new(1, 1).set_position(3, 0)
  middle.get_canvas().draw_pixel(0, 0, @graphics.Color::green())
  let right = @graphics.Layer::new(1, 1).set_position(6, 0)
  right.get_canvas().draw_pixel(0, 0, @graphics.Color::blue())
  ignore(frame.get_layer_tree().add_layer(middle))
  ignore(frame.get_layer_tree().add_layer(right))

  let surface = NativeSurface::from_frame(42, frame)
  let submit_plan = surface.dirty_frame_submit_plan(frame)
  assert_true(submit_plan.get_state() == @graphics.DirtySubmitState::Present)
  assert_true(submit_plan.has_dirty())
  assert_true(submit_plan.needs_present())
  assert_true(submit_plan.uses_bounds_fallback())
  assert_eq(submit_plan.get_present_rect_count(), 1)
  assert_eq(submit_plan.get_present_pixel_count(), 7)
  assert_eq(submit_plan.get_present_byte_count(), 28)
  assert_true(submit_plan.saves_full_present_pixels(8, 1))
  assert_true(!submit_plan.saves_full_present_pixels(7, 1))
  assert_true(
    submit_plan.get_present_strategy(8, 1) ==
    @graphics.DirtyPresentStrategy::Partial,
  )
  assert_true(
    submit_plan.get_present_strategy(7, 1) ==
    @graphics.DirtyPresentStrategy::Full,
  )
  assert_true(
    submit_plan.get_present_plan().get_rects()[0] ==
    @graphics.PixelRect::new(x=0, y=0, width=7, height=1),
  )
  assert_true(frame.has_dirty())

  assert_true(
    surface.dirty_frame_present_strategy(frame) ==
    @graphics.DirtyPresentStrategy::Partial,
  )
  assert_true(
    NativeSurface::new(42, 7, 1).dirty_frame_present_strategy(frame) ==
    @graphics.DirtyPresentStrategy::Full,
  )
}

///|
test "NativeSurface exposes RenderFrame dirty present batches" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(8, 1).set_dirty_rect_limit(2)
  frame.get_canvas().draw_pixel(0, 0, @graphics.Color::red())

  let middle = @graphics.Layer::new(1, 1).set_position(3, 0)
  middle.get_canvas().draw_pixel(0, 0, @graphics.Color::green())
  let right = @graphics.Layer::new(1, 1).set_position(6, 0)
  right.get_canvas().draw_pixel(0, 0, @graphics.Color::blue())
  ignore(frame.get_layer_tree().add_layer(middle))
  ignore(frame.get_layer_tree().add_layer(right))

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 7)
      assert_eq(batch.get_present_byte_count(), 28)
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=0, y=0, width=7, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 28)
      assert_eq(pixels[0], @graphics.Color::red().r)
      assert_eq(pixels[12], @graphics.Color::green().r)
      assert_eq(pixels[24], @graphics.Color::blue().r)
    }
    Err(_) => abort("expected native dirty present batch")
  }
  assert_eq(count.val, 0)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(3, 0),
    @graphics.Color::transparent(),
  )
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes filtered dirty present batch without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().clear(@graphics.Color::white())
  frame.get_canvas().clear_dirty_region()

  let layer = @graphics.Layer::new(1, 1)
    .set_position(1, 0)
    .set_filter(@graphics.PaintFilter::invert())
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  ignore(frame.get_layer_tree().add_layer(layer))

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let cyan = @graphics.Color::new(r=0, g=255, b=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], cyan.r)
      assert_eq(pixels[1], cyan.g)
      assert_eq(pixels[2], cyan.b)
      assert_eq(pixels[3], cyan.a)
    }
    Err(_) => abort("expected filtered native dirty present batch")
  }

  assert_eq(count.val, 0)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes shader-filter dirty present batch without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().clear(@graphics.Color::white())
  frame.get_canvas().clear_dirty_region()

  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=@graphics.Color::blue(),
    end_color=@graphics.Color::blue(),
  )
  let layer = @graphics.Layer::new(1, 1)
    .set_position(1, 0)
    .set_shader(shader)
    .set_filter(@graphics.PaintFilter::invert())
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::white())
  ignore(frame.get_layer_tree().add_layer(layer))

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let yellow = @graphics.Color::new(r=255, g=255, b=0)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], yellow.r)
      assert_eq(pixels[1], yellow.g)
      assert_eq(pixels[2], yellow.b)
      assert_eq(pixels[3], yellow.a)
    }
    Err(_) => abort("expected shader-filter native dirty present batch")
  }

  assert_eq(count.val, 0)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes antialiased layer path shader-filter batch without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().clear(@graphics.Color::white())
  assert_true(
    frame.present_dirty_to(@graphics.MemorySurface::new(4, 1)) == Ok(1),
  )
  assert_true(!frame.has_dirty())

  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let layer = @graphics.Layer::new(2, 1)
    .set_position(1, 0)
    .set_shader(shader)
    .set_filter(@graphics.PaintFilter::invert())
  let layer_canvas = layer.get_canvas()
  layer_canvas.fill_path(
    @graphics.Path::new().add_rect(0.5, 0.0, 1.0, 1.0),
    @graphics.Paint::new().set_color(@graphics.Color::white()),
  )
  assert_eq(
    layer.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=255, g=255, b=255, a=128),
  )
  assert_eq(
    layer.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=255, g=255, b=255, a=128),
  )

  assert_eq(frame.get_layer_tree().add_layer(layer), 0)
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  let left = @graphics.Color::new(r=159, g=255, b=223)
  let right = @graphics.Color::new(r=223, g=255, b=159)
  let batch = match surface.dirty_frame_present_batch(frame) {
    Ok(value) => {
      assert_eq(value.get_rect_count(), 1)
      assert_eq(value.get_present_pixel_count(), 2)
      assert_eq(value.get_present_byte_count(), 8)
      assert_true(
        value.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = value.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=2, height=1),
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
      value
    }
    Err(_) => abort("expected native antialiased path shader-filter batch")
  }

  assert_eq(count.val, 0)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::white(),
  )
  assert_true(frame.get_canvas().get_dirty_region().is_empty())
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
  )
  assert_true(frame.has_dirty())

  match surface.submit_present_batch_plan(batch) {
    Ok(plan) => {
      assert_eq(plan.get_surface_width(), 4)
      assert_eq(plan.get_surface_height(), 1)
      assert_true(plan.needs_present())
      assert_true(
        plan.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(
        plan.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      assert_eq(plan.get_rect_count(), 1)
      assert_eq(plan.get_present_pixel_count(), 2)
      assert_eq(plan.get_present_byte_count(), 8)
      assert_eq(plan.get_source_byte_count(), 8)
      assert_true(plan.saves_full_present_pixels())
    }
    Err(_) => abort("expected native antialiased path batch submit plan")
  }
  assert_eq(count.val, 0)
  assert_true(frame.has_dirty())

  match surface.submit_present_batch(batch) {
    Ok(result) => {
      assert_eq(result.get_surface_width(), 4)
      assert_eq(result.get_surface_height(), 1)
      assert_true(result.did_present())
      assert_true(result.needs_present())
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      assert_eq(result.get_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 2)
      assert_eq(result.get_present_byte_count(), 8)
      assert_eq(result.get_source_byte_count(), 8)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected native antialiased path batch submit result")
  }
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::white(),
  )
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), left)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), right)
  assert_true(frame.get_canvas().get_dirty_region().is_empty())
  assert_true(frame.get_layer_tree().dirty_bounds() == None)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes moved layer bounds without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)

  let background = @graphics.Layer::new(4, 1)
  background.clear(@graphics.Color::white())
  let moving = @graphics.Layer::new(1, 1).set_position(1, 0)
  moving.get_canvas().draw_pixel(0, 0, @graphics.Color::blue())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(moving), 1)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::blue(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::white(),
  )
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().set_layer_position(1, 2, 0))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      assert_true(
        batch.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], @graphics.Color::white().r)
      assert_eq(pixels[1], @graphics.Color::white().g)
      assert_eq(pixels[2], @graphics.Color::white().b)
      assert_eq(pixels[3], @graphics.Color::white().a)
      assert_eq(pixels[4], @graphics.Color::blue().r)
      assert_eq(pixels[5], @graphics.Color::blue().g)
      assert_eq(pixels[6], @graphics.Color::blue().b)
      assert_eq(pixels[7], @graphics.Color::blue().a)
    }
    Err(_) => abort("expected native moved layer dirty present batch")
  }

  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::blue(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::white(),
  )
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::blue(),
  )
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes resized layer bounds without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)

  let background = @graphics.Layer::new(4, 1)
  background.clear(@graphics.Color::white())
  let resizing = @graphics.Layer::new(2, 1).set_position(1, 0)
  resizing.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  resizing.get_canvas().draw_pixel(1, 0, @graphics.Color::blue())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(resizing), 1)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::blue(),
  )
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().resize_layer(1, 1, 1))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  let batch = match surface.dirty_frame_present_batch(frame) {
    Ok(value) => {
      assert_eq(value.get_rect_count(), 1)
      assert_eq(value.get_present_pixel_count(), 2)
      assert_eq(value.get_present_byte_count(), 8)
      assert_true(
        value.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = value.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], @graphics.Color::red().r)
      assert_eq(pixels[1], @graphics.Color::red().g)
      assert_eq(pixels[2], @graphics.Color::red().b)
      assert_eq(pixels[3], @graphics.Color::red().a)
      assert_eq(pixels[4], @graphics.Color::white().r)
      assert_eq(pixels[5], @graphics.Color::white().g)
      assert_eq(pixels[6], @graphics.Color::white().b)
      assert_eq(pixels[7], @graphics.Color::white().a)
      value
    }
    Err(_) => abort("expected native resized layer dirty present batch")
  }

  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::blue(),
  )
  assert_true(frame.has_dirty())

  match surface.submit_present_batch(batch) {
    Ok(result) => {
      assert_true(result.did_present())
      assert_true(result.needs_present())
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      assert_eq(result.get_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 2)
      assert_eq(result.get_present_byte_count(), 8)
      assert_eq(result.get_source_byte_count(), 8)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected native resized layer batch submit")
  }
  assert_eq(count.val, 2)
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 3)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::white(),
  )
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes hidden layer bounds without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)

  let background = @graphics.Layer::new(4, 1)
  background.clear(@graphics.Color::white())
  let top = @graphics.Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(top), 1)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().set_layer_visible(1, false))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], @graphics.Color::white().r)
      assert_eq(pixels[1], @graphics.Color::white().g)
      assert_eq(pixels[2], @graphics.Color::white().b)
      assert_eq(pixels[3], @graphics.Color::white().a)
    }
    Err(_) => abort("expected native hidden layer dirty present batch")
  }

  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes removed layer bounds without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)

  let background = @graphics.Layer::new(4, 1)
  background.clear(@graphics.Color::white())
  let top = @graphics.Layer::new(1, 1).set_position(1, 0)
  top.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(top), 1)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_true(!frame.has_dirty())

  match frame.get_layer_tree().remove_layer(1) {
    Some(layer) => assert_eq(layer.get_x(), 1)
    None => abort("expected removed native frame layer")
  }
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  let batch = match surface.dirty_frame_present_batch(frame) {
    Ok(value) => {
      assert_eq(value.get_rect_count(), 1)
      assert_eq(value.get_present_pixel_count(), 1)
      assert_eq(value.get_present_byte_count(), 4)
      assert_true(
        value.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = value.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], @graphics.Color::white().r)
      assert_eq(pixels[1], @graphics.Color::white().g)
      assert_eq(pixels[2], @graphics.Color::white().b)
      assert_eq(pixels[3], @graphics.Color::white().a)
      value
    }
    Err(_) => abort("expected native removed layer dirty present batch")
  }

  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_true(frame.has_dirty())

  match surface.submit_present_batch(batch) {
    Ok(result) => {
      assert_true(result.did_present())
      assert_true(result.needs_present())
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      assert_eq(result.get_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
      assert_eq(result.get_source_byte_count(), 4)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected native removed layer batch submit")
  }
  assert_eq(count.val, 2)
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 3)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes replaced layer bounds without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)

  let background = @graphics.Layer::new(4, 1)
  background.clear(@graphics.Color::white())
  let old_top = @graphics.Layer::new(1, 1).set_position(1, 0)
  old_top.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(old_top), 1)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::white(),
  )
  assert_true(!frame.has_dirty())

  let new_top = @graphics.Layer::new(1, 1).set_position(2, 0)
  new_top.get_canvas().draw_pixel(0, 0, @graphics.Color::green())
  match frame.replace_layer(1, new_top) {
    Some(layer) => assert_eq(layer.get_x(), 1)
    None => abort("expected replaced native frame layer")
  }
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  let batch = match surface.dirty_frame_present_batch(frame) {
    Ok(value) => {
      assert_eq(value.get_rect_count(), 1)
      assert_eq(value.get_present_pixel_count(), 2)
      assert_eq(value.get_present_byte_count(), 8)
      assert_true(
        value.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = value.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 8)
      assert_eq(pixels[0], @graphics.Color::white().r)
      assert_eq(pixels[1], @graphics.Color::white().g)
      assert_eq(pixels[2], @graphics.Color::white().b)
      assert_eq(pixels[3], @graphics.Color::white().a)
      assert_eq(pixels[4], @graphics.Color::green().r)
      assert_eq(pixels[5], @graphics.Color::green().g)
      assert_eq(pixels[6], @graphics.Color::green().b)
      assert_eq(pixels[7], @graphics.Color::green().a)
      value
    }
    Err(_) => abort("expected native replaced layer dirty present batch")
  }

  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::white(),
  )
  assert_true(frame.has_dirty())

  match surface.submit_present_batch(batch) {
    Ok(result) => {
      assert_true(result.did_present())
      assert_true(result.needs_present())
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      assert_eq(result.get_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 2)
      assert_eq(result.get_present_byte_count(), 8)
      assert_eq(result.get_source_byte_count(), 8)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected native replaced layer batch submit")
  }
  assert_eq(count.val, 2)
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 3)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::green(),
  )
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes reordered layer bounds without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(2, 1)

  let background = @graphics.Layer::new(2, 1)
  background.clear(@graphics.Color::white())
  let bottom = @graphics.Layer::new(1, 1)
  bottom.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  let top = @graphics.Layer::new(1, 1)
  top.get_canvas().draw_pixel(0, 0, @graphics.Color::blue())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(bottom), 1)
  assert_eq(frame.get_layer_tree().add_layer(top), 2)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::blue(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().reorder_layer(2, 1))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=1, height=1)),
  )

  let batch = match surface.dirty_frame_present_batch(frame) {
    Ok(value) => {
      assert_eq(value.get_rect_count(), 1)
      assert_eq(value.get_present_pixel_count(), 1)
      assert_eq(value.get_present_byte_count(), 4)
      assert_true(
        value.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=1, height=1)),
      )
      let payloads = value.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], @graphics.Color::red().r)
      assert_eq(pixels[1], @graphics.Color::red().g)
      assert_eq(pixels[2], @graphics.Color::red().b)
      assert_eq(pixels[3], @graphics.Color::red().a)
      value
    }
    Err(_) => abort("expected native reordered layer dirty present batch")
  }

  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::blue(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_true(frame.has_dirty())

  match surface.submit_present_batch(batch) {
    Ok(result) => {
      assert_true(result.did_present())
      assert_true(result.needs_present())
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=1, height=1)),
      )
      assert_eq(result.get_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
      assert_eq(result.get_source_byte_count(), 4)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected native reordered layer batch submit")
  }
  assert_eq(count.val, 2)
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 3)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes opacity style invalidation batch without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)

  let background = @graphics.Layer::new(4, 1)
  background.clear(@graphics.Color::white())
  let layer = @graphics.Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::blue())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(layer), 1)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::blue(),
  )
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().set_layer_opacity(1, 0.5))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let half_blue = @graphics.Color::new(r=127, g=127, b=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], half_blue.r)
      assert_eq(pixels[1], half_blue.g)
      assert_eq(pixels[2], half_blue.b)
      assert_eq(pixels[3], half_blue.a)
    }
    Err(_) => abort("expected native opacity style invalidation batch")
  }

  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::blue(),
  )
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=127, g=127, b=255),
  )
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes filter style invalidation batch without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().clear(@graphics.Color::white())

  let layer = @graphics.Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_true(!frame.has_dirty())

  assert_true(
    frame.get_layer_tree().set_layer_filter(0, @graphics.PaintFilter::invert()),
  )
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let cyan = @graphics.Color::new(r=0, g=255, b=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], cyan.r)
      assert_eq(pixels[1], cyan.g)
      assert_eq(pixels[2], cyan.b)
      assert_eq(pixels[3], cyan.a)
    }
    Err(_) => abort("expected native filter style invalidation batch")
  }

  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface treats identity filter as no-op present lifecycle" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().clear(@graphics.Color::white())

  let layer = @graphics.Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_true(!frame.has_dirty())

  assert_true(
    frame
    .get_layer_tree()
    .set_layer_filter(0, @graphics.PaintFilter::identity()),
  )
  match frame.get_layer_tree().get_layer(0) {
    Some(layer) =>
      match layer.get_filter() {
        Some(filter) => assert_true(filter.is_identity())
        None => abort("expected stored native identity filter")
      }
    None => abort("expected native identity-filtered layer")
  }
  assert_true(frame.get_layer_tree().dirty_bounds() == None)
  assert_true(!frame.has_dirty())

  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_true(batch.is_empty())
      assert_eq(batch.get_rect_count(), 0)
      assert_eq(batch.get_present_pixel_count(), 0)
      assert_eq(batch.get_present_byte_count(), 0)
      assert_true(batch.get_present_bounds() == None)
    }
    Err(_) => abort("expected empty native identity-filter present batch")
  }

  let plan = surface.dirty_frame_submit_by_strategy_plan(frame)
  assert_true(
    plan.get_present_strategy() == @graphics.DirtyPresentStrategy::Skip,
  )
  assert_true(plan.get_state() == @graphics.DirtySubmitState::Clean)
  assert_true(plan.get_dirty_bounds() == None)
  assert_true(!plan.has_dirty())
  assert_true(!plan.needs_present())
  assert_eq(plan.get_present_rect_count(), 0)
  assert_eq(plan.get_present_pixel_count(), 0)
  assert_eq(plan.get_present_byte_count(), 0)

  let schedule = surface.frame_schedule(frame)
  assert_true(
    schedule.get_action() == @graphics.RenderFrameScheduleAction::Skip,
  )
  assert_true(
    schedule.get_present_strategy() == @graphics.DirtyPresentStrategy::Skip,
  )
  assert_true(schedule.get_state() == @graphics.DirtySubmitState::Clean)
  assert_true(schedule.get_dirty_bounds() == None)
  assert_true(!schedule.has_dirty())
  assert_true(!schedule.needs_present())
  assert_true(!schedule.should_submit())
  assert_eq(schedule.get_present_rect_count(), 0)
  assert_eq(schedule.get_present_pixel_count(), 0)
  assert_eq(schedule.get_present_byte_count(), 0)

  match surface.submit_frame_dirty(frame) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy(surface.get_width(), surface.get_height()) ==
        @graphics.DirtyPresentStrategy::Skip,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Clean)
      assert_true(result.get_dirty_bounds() == None)
      assert_true(!result.has_dirty())
      assert_true(!result.needs_present())
      assert_true(!result.did_present())
      assert_eq(result.get_presented_rect_count(), 0)
      assert_true(result.get_present_bounds() == None)
      assert_eq(result.get_present_pixel_count(), 0)
      assert_eq(result.get_present_byte_count(), 0)
    }
    Err(_) => abort("expected clean native identity-filter submit")
  }
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes transparent RGB filter invalidation batch without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().clear(@graphics.Color::white())

  let layer = @graphics.Layer::new(1, 1).set_position(1, 0)
  layer.get_pixmap().set_pixel(0, 0, @graphics.Color::new(r=128, g=0, b=0, a=0))
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_true(!frame.has_dirty())

  assert_true(
    frame
    .get_layer_tree()
    .set_layer_filter(0, native_surface_red_to_alpha_filter()),
  )
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let gray = @graphics.Color::new(r=127, g=127, b=127, a=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], gray.r)
      assert_eq(pixels[1], gray.g)
      assert_eq(pixels[2], gray.b)
      assert_eq(pixels[3], gray.a)
    }
    Err(_) => abort("expected native transparent RGB filter invalidation batch")
  }

  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=127, g=127, b=127, a=255),
  )
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes cleared filter invalidation batch without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().clear(@graphics.Color::white())

  let layer = @graphics.Layer::new(1, 1)
    .set_position(1, 0)
    .set_filter(@graphics.PaintFilter::invert())
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  let cyan = @graphics.Color::new(r=0, g=255, b=255)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), cyan)
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().clear_layer_filter(0))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], @graphics.Color::red().r)
      assert_eq(pixels[1], @graphics.Color::red().g)
      assert_eq(pixels[2], @graphics.Color::red().b)
      assert_eq(pixels[3], @graphics.Color::red().a)
    }
    Err(_) => abort("expected native cleared filter invalidation batch")
  }

  assert_eq(count.val, 1)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), cyan)
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_true(!frame.has_dirty())
}

///|
fn native_surface_red_to_alpha_filter() -> @graphics.PaintFilter {
  @graphics.PaintFilter::color_matrix([
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0,
    0.0, 0.0, 0.0, 0.0,
  ])
}

///|
test "NativeSurface materializes shader style invalidation batch without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().clear(@graphics.Color::white())

  let layer = @graphics.Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_true(!frame.has_dirty())

  let blue_shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=@graphics.Color::blue(),
    end_color=@graphics.Color::blue(),
  )
  assert_true(frame.get_layer_tree().set_layer_shader(0, blue_shader))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], @graphics.Color::blue().r)
      assert_eq(pixels[1], @graphics.Color::blue().g)
      assert_eq(pixels[2], @graphics.Color::blue().b)
      assert_eq(pixels[3], @graphics.Color::blue().a)
    }
    Err(_) => abort("expected native shader style invalidation batch")
  }

  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes positioned shader invalidation through filter batch without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().clear(@graphics.Color::white())

  let layer = @graphics.Layer::new(2, 1)
    .set_position(1, 0)
    .set_filter(@graphics.PaintFilter::invert())
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::white())
  layer.get_canvas().draw_pixel(1, 0, @graphics.Color::white())
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::black(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::black(),
  )
  assert_true(!frame.has_dirty())

  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_true(frame.get_layer_tree().set_layer_shader(0, shader))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 2)
      assert_eq(batch.get_present_byte_count(), 8)
      assert_true(
        batch.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=2, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let left = @graphics.Color::new(r=64, g=255, b=191)
      let right = @graphics.Color::new(r=191, g=255, b=64)
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
      abort("expected native positioned shader-filter invalidation batch")
  }

  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::black(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::black(),
  )
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=64, g=255, b=191),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::new(r=191, g=255, b=64),
  )
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes cleared shader invalidation batch without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().clear(@graphics.Color::white())

  let blue_shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=@graphics.Color::blue(),
    end_color=@graphics.Color::blue(),
  )
  let layer = @graphics.Layer::new(1, 1)
    .set_position(1, 0)
    .set_shader(blue_shader)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::blue(),
  )
  assert_true(!frame.has_dirty())

  assert_true(frame.get_layer_tree().clear_layer_shader(0))
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], @graphics.Color::red().r)
      assert_eq(pixels[1], @graphics.Color::red().g)
      assert_eq(pixels[2], @graphics.Color::red().b)
      assert_eq(pixels[3], @graphics.Color::red().a)
    }
    Err(_) => abort("expected native cleared shader invalidation batch")
  }

  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::blue(),
  )
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes blend style invalidation batch without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)

  let background = @graphics.Layer::new(4, 1)
  background.clear(@graphics.Color::blue())
  let layer = @graphics.Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(layer), 1)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_true(!frame.has_dirty())

  assert_true(
    frame.get_layer_tree().set_layer_blend_mode(1, @graphics.BlendMode::Screen),
  )
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let magenta = @graphics.Color::new(r=255, g=0, b=255)
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], magenta.r)
      assert_eq(pixels[1], magenta.g)
      assert_eq(pixels[2], magenta.b)
      assert_eq(pixels[3], magenta.a)
    }
    Err(_) => abort("expected native blend style invalidation batch")
  }

  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes Destination shader filter invalidation batch with submit telemetry" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  let background_left = @graphics.Color::new(r=20, g=40, b=60)
  let background_right = @graphics.Color::new(r=200, g=150, b=100)
  let cached_left = @graphics.Color::new(r=42, g=148, b=126)
  let cached_right = @graphics.Color::new(r=195, g=203, b=82)

  let background = @graphics.Layer::new(4, 1)
  background.get_canvas().draw_pixel(0, 0, @graphics.Color::white())
  background.get_canvas().draw_pixel(1, 0, background_left)
  background.get_canvas().draw_pixel(2, 0, background_right)
  background.get_canvas().draw_pixel(3, 0, @graphics.Color::black())
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let layer = @graphics.Layer::new(2, 1)
    .set_position(1, 0)
    .set_shader(shader)
    .set_filter(@graphics.PaintFilter::invert())
    .set_opacity(0.5)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::white())
  layer.get_canvas().draw_pixel(1, 0, @graphics.Color::white())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(layer), 1)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), cached_left)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), cached_right)
  assert_true(!frame.has_dirty())

  assert_true(
    frame
    .get_layer_tree()
    .set_layer_blend_mode(1, @graphics.BlendMode::Destination),
  )
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
  )

  let batch = match surface.dirty_frame_present_batch(frame) {
    Ok(value) => {
      assert_eq(value.get_rect_count(), 1)
      assert_eq(value.get_present_pixel_count(), 2)
      assert_eq(value.get_present_byte_count(), 8)
      assert_true(
        value.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      let payloads = value.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=2, height=1),
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
      value
    }
    Err(_) => abort("expected native Destination shader filter batch")
  }
  assert_eq(count.val, 1)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), cached_left)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), cached_right)
  assert_true(frame.has_dirty())

  match surface.submit_present_batch_plan(batch) {
    Ok(plan) => {
      assert_eq(plan.get_surface_width(), 4)
      assert_eq(plan.get_surface_height(), 1)
      assert_true(plan.needs_present())
      assert_true(
        plan.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(
        plan.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      assert_eq(plan.get_rect_count(), 1)
      assert_eq(plan.get_present_pixel_count(), 2)
      assert_eq(plan.get_present_byte_count(), 8)
      assert_eq(plan.get_source_byte_count(), 8)
      assert_true(plan.saves_full_present_pixels())
    }
    Err(_) => abort("expected native Destination shader filter batch plan")
  }
  assert_eq(count.val, 1)
  assert_true(frame.has_dirty())

  match surface.submit_present_batch(batch) {
    Ok(result) => {
      assert_eq(result.get_surface_width(), 4)
      assert_eq(result.get_surface_height(), 1)
      assert_true(result.did_present())
      assert_true(result.needs_present())
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
      )
      assert_eq(result.get_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 2)
      assert_eq(result.get_present_byte_count(), 8)
      assert_eq(result.get_source_byte_count(), 8)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected native Destination shader filter batch submit")
  }
  assert_eq(count.val, 2)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), cached_left)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), cached_right)
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 3)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), background_left)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(2, 0), background_right)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface materializes transparent-source blend invalidation batch without submitting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  let background_color = @graphics.Color::new(r=10, g=20, b=30)

  let background = @graphics.Layer::new(4, 1)
  background.clear(background_color)
  let layer = @graphics.Layer::new(1, 1).set_position(1, 0).set_opacity(0.0)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(frame.get_layer_tree().add_layer(background), 0)
  assert_eq(frame.get_layer_tree().add_layer(layer), 1)

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), background_color)
  assert_true(!frame.has_dirty())

  assert_true(
    frame.get_layer_tree().set_layer_blend_mode(1, @graphics.BlendMode::Clear),
  )
  assert_true(
    frame.get_layer_tree().dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )

  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_eq(batch.get_rect_count(), 1)
      assert_eq(batch.get_present_pixel_count(), 1)
      assert_eq(batch.get_present_byte_count(), 4)
      assert_true(
        batch.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      let payloads = batch.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      )
      let pixels = payloads[0].get_pixels()
      let transparent = @graphics.Color::transparent()
      assert_eq(pixels.length(), 4)
      assert_eq(pixels[0], transparent.r)
      assert_eq(pixels[1], transparent.g)
      assert_eq(pixels[2], transparent.b)
      assert_eq(pixels[3], transparent.a)
    }
    Err(_) => abort("expected native transparent blend invalidation batch")
  }

  assert_eq(count.val, 1)
  assert_eq(frame.get_canvas().get_pixmap().get_pixel(1, 0), background_color)
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::transparent(),
  )
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface dirty present batch preserves clipped-away dirty" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.mark_dirty_rect(@graphics.PixelRect::new(x=3, y=0, width=1, height=1))
  let surface = NativeSurface::new(42, 2, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })

  match surface.dirty_frame_present_batch(frame) {
    Ok(batch) => {
      assert_true(batch.is_empty())
      assert_eq(batch.get_rect_count(), 0)
      assert_eq(batch.get_present_pixel_count(), 0)
      assert_eq(batch.get_present_byte_count(), 0)
    }
    Err(_) => abort("expected clipped-away dirty present batch")
  }
  assert_eq(count.val, 0)
  assert_true(frame.has_dirty())
}

///|
test "NativeSurface submits materialized present batches with telemetry" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().draw_pixel(2, 0, @graphics.Color::red())
  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })

  let batch = match surface.dirty_frame_present_batch(frame) {
    Ok(value) => value
    Err(_) => abort("expected native dirty present batch")
  }
  assert_eq(batch.get_rect_count(), 1)
  assert_true(
    batch.get_present_bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=0, width=1, height=1)),
  )
  assert_true(frame.has_dirty())
  assert_eq(count.val, 0)

  match surface.submit_present_batch_plan(batch) {
    Ok(plan) => {
      assert_eq(plan.get_surface_width(), 4)
      assert_eq(plan.get_surface_height(), 1)
      assert_true(plan.needs_present())
      assert_true(
        plan.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(
        plan.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=2, y=0, width=1, height=1)),
      )
      assert_eq(plan.get_rect_count(), 1)
      assert_eq(plan.get_present_pixel_count(), 1)
      assert_eq(plan.get_present_byte_count(), 4)
      assert_eq(plan.get_source_byte_count(), 4)
      assert_true(plan.saves_full_present_pixels())
    }
    Err(_) => abort("expected native batch submit plan")
  }
  assert_eq(count.val, 0)
  assert_true(frame.has_dirty())

  match surface.submit_present_batch(batch) {
    Ok(result) => {
      assert_eq(result.get_surface_width(), 4)
      assert_eq(result.get_surface_height(), 1)
      assert_true(result.did_present())
      assert_true(result.needs_present())
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=2, y=0, width=1, height=1)),
      )
      assert_eq(result.get_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
      assert_eq(result.get_source_byte_count(), 4)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected native batch submit result")
  }
  assert_eq(count.val, 1)
  assert_true(frame.has_dirty())
}

///|
test "NativeSurface full-frame resized present batch preserves dirty until frame present" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  frame.get_canvas().draw_pixel(3, 0, @graphics.Color::blue())
  frame.mark_all_dirty()

  let surface = NativeSurface::new(42, 2, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.sync_frame_size(frame))
  assert_eq(surface.get_width(), 4)
  assert_eq(surface.get_height(), 1)

  let batch = match surface.dirty_frame_present_batch(frame) {
    Ok(value) => {
      assert_eq(value.get_rect_count(), 1)
      assert_eq(value.get_present_pixel_count(), 4)
      assert_eq(value.get_present_byte_count(), 16)
      assert_true(
        value.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=1)),
      )
      assert_true(
        value.get_present_strategy(4, 1) == @graphics.DirtyPresentStrategy::Full,
      )
      assert_true(!value.saves_full_present_pixels(4, 1))
      let payloads = value.get_payloads()
      assert_true(
        payloads[0].get_rect() ==
        @graphics.PixelRect::new(x=0, y=0, width=4, height=1),
      )
      let pixels = payloads[0].get_pixels()
      assert_eq(pixels.length(), 16)
      assert_eq(pixels[0], @graphics.Color::red().r)
      assert_eq(pixels[1], @graphics.Color::red().g)
      assert_eq(pixels[2], @graphics.Color::red().b)
      assert_eq(pixels[3], @graphics.Color::red().a)
      assert_eq(pixels[12], @graphics.Color::blue().r)
      assert_eq(pixels[13], @graphics.Color::blue().g)
      assert_eq(pixels[14], @graphics.Color::blue().b)
      assert_eq(pixels[15], @graphics.Color::blue().a)
      value
    }
    Err(_) => abort("expected full resized native dirty present batch")
  }
  assert_eq(count.val, 0)
  assert_true(frame.has_dirty())

  match surface.submit_present_batch_plan(batch) {
    Ok(plan) => {
      assert_eq(plan.get_surface_width(), 4)
      assert_eq(plan.get_surface_height(), 1)
      assert_true(plan.needs_present())
      assert_true(
        plan.get_present_strategy() == @graphics.DirtyPresentStrategy::Full,
      )
      assert_true(
        plan.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=1)),
      )
      assert_eq(plan.get_rect_count(), 1)
      assert_eq(plan.get_present_pixel_count(), 4)
      assert_eq(plan.get_present_byte_count(), 16)
      assert_eq(plan.get_source_byte_count(), 16)
      assert_true(!plan.saves_full_present_pixels())
    }
    Err(_) => abort("expected full resized batch submit plan")
  }
  assert_eq(count.val, 0)
  assert_true(frame.has_dirty())

  match surface.submit_present_batch(batch) {
    Ok(result) => {
      assert_eq(result.get_surface_width(), 4)
      assert_eq(result.get_surface_height(), 1)
      assert_true(result.did_present())
      assert_true(result.needs_present())
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Full,
      )
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=1)),
      )
      assert_eq(result.get_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 4)
      assert_eq(result.get_present_byte_count(), 16)
      assert_eq(result.get_source_byte_count(), 16)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected full resized batch submit result")
  }
  assert_eq(count.val, 1)
  assert_true(frame.has_dirty())

  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface present batch submit plan rejects stale synced dimensions before presenting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  frame.get_canvas().draw_pixel(3, 0, @graphics.Color::blue())
  frame.mark_all_dirty()

  let surface = NativeSurface::new(42, 2, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(surface.sync_frame_size(frame))

  let batch = match surface.dirty_frame_present_batch(frame) {
    Ok(value) => {
      assert_eq(value.get_rect_count(), 1)
      assert_true(
        value.get_present_strategy(4, 1) == @graphics.DirtyPresentStrategy::Full,
      )
      assert_eq(value.get_present_pixel_count(), 4)
      assert_eq(value.get_present_byte_count(), 16)
      value
    }
    Err(_) => abort("expected full native dirty present batch")
  }
  let submit_plan = match surface.submit_present_batch_plan(batch) {
    Ok(value) => {
      assert_eq(value.get_surface_width(), 4)
      assert_eq(value.get_surface_height(), 1)
      assert_true(
        value.get_present_strategy() == @graphics.DirtyPresentStrategy::Full,
      )
      assert_true(value.needs_present())
      value
    }
    Err(_) => abort("expected native batch submit plan")
  }
  assert_eq(count.val, 0)

  ignore(frame.resize(2, 1))
  assert_true(surface.sync_frame_size(frame))
  match submit_plan.submit_to_result(surface) {
    Err(@graphics.PresentError::SizeMismatch(4, 1, 2, 1)) => ()
    _ => abort("expected stale native batch submit plan dimensions error")
  }
  assert_eq(count.val, 0)
  assert_true(frame.has_dirty())
}

///|
test "NativeSurface present batch submit preflights target bounds" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().draw_pixel(3, 0, @graphics.Color::red())
  let source_surface = NativeSurface::from_frame(42, frame)
  let batch = match source_surface.dirty_frame_present_batch(frame) {
    Ok(value) => value
    Err(_) => abort("expected clipped native dirty present batch")
  }

  let clipped_surface = NativeSurface::new(42, 2, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  match clipped_surface.submit_present_batch_plan(batch) {
    Err(@graphics.PresentError::RectOutOfBounds(3, 0, 1, 1, 2, 1)) => ()
    _ => abort("expected clipped native batch submit plan error")
  }
  match clipped_surface.submit_present_batch(batch) {
    Err(@graphics.PresentError::RectOutOfBounds(3, 0, 1, 1, 2, 1)) => ()
    _ => abort("expected clipped native batch submit error")
  }
  assert_eq(count.val, 0)
  assert_true(frame.has_dirty())
}

///|
test "NativeSurface dirty submit plan preserves clipped-away dirty without presenting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.mark_dirty_rect(@graphics.PixelRect::new(x=3, y=0, width=1, height=1))
  let surface = NativeSurface::new(42, 2, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })

  let submit_plan = surface.dirty_frame_submit_plan(frame)
  assert_true(
    submit_plan.get_state() == @graphics.DirtySubmitState::DirtyClippedAway,
  )
  assert_true(submit_plan.has_dirty())
  assert_true(!submit_plan.needs_present())
  assert_eq(submit_plan.get_present_rect_count(), 0)
  assert_eq(submit_plan.get_present_pixel_count(), 0)
  assert_eq(submit_plan.get_present_byte_count(), 0)
  assert_true(!submit_plan.saves_full_present_pixels(2, 1))
  assert_true(
    submit_plan.get_present_strategy(2, 1) ==
    @graphics.DirtyPresentStrategy::Skip,
  )
  assert_true(
    submit_plan.get_present_plan().get_mode() ==
    @graphics.DirtyPresentPlanMode::Empty,
  )
  assert_true(
    surface.dirty_frame_present_strategy(frame) ==
    @graphics.DirtyPresentStrategy::Skip,
  )
  assert_eq(count.val, 0)
  assert_true(frame.has_dirty())
}

///|
test "NativeSurface submits dirty frames with scheduler result" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(2, 1)
  let layer = @graphics.Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  ignore(frame.get_layer_tree().add_layer(layer))
  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })

  match surface.submit_frame_dirty(frame) {
    Ok(result) => {
      assert_true(result.get_state() == @graphics.DirtySubmitState::Present)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_true(result.has_dirty())
      assert_true(result.needs_present())
      assert_true(result.did_present())
      assert_true(!result.was_clipped_away())
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
      assert_true(result.saves_full_present_pixels(2, 1))
      assert_true(
        result.get_present_strategy(2, 1) ==
        @graphics.DirtyPresentStrategy::Partial,
      )
    }
    Err(_) => abort("expected dirty submit result")
  }
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())
  assert_true(
    surface.dirty_frame_present_strategy(frame) ==
    @graphics.DirtyPresentStrategy::Skip,
  )

  match surface.submit_frame_dirty(frame) {
    Ok(result) => {
      assert_true(result.get_state() == @graphics.DirtySubmitState::Clean)
      assert_eq(result.get_presented_rect_count(), 0)
      assert_true(!result.has_dirty())
      assert_true(!result.needs_present())
      assert_true(!result.did_present())
      assert_eq(result.get_present_pixel_count(), 0)
      assert_eq(result.get_present_byte_count(), 0)
      assert_true(!result.saves_full_present_pixels(2, 1))
      assert_true(
        result.get_present_strategy(2, 1) ==
        @graphics.DirtyPresentStrategy::Skip,
      )
    }
    Err(_) => abort("expected clean submit result")
  }
  assert_eq(count.val, 1)
}

///|
test "NativeSurface submits frames by present strategy" {
  let partial_count = Ref(0)
  let partial_frame = @graphics.RenderFrame::new(4, 1)
  partial_frame.mark_dirty_rect(
    @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
  )
  let partial_surface = NativeSurface::from_frame(42, partial_frame).with_pre_present_hook(fn() {
      partial_count.val = partial_count.val + 1
    },
  )

  let partial_plan = partial_surface.dirty_frame_submit_by_strategy_plan(
    partial_frame,
  )
  assert_true(
    partial_plan.get_present_strategy() ==
    @graphics.DirtyPresentStrategy::Partial,
  )
  assert_true(partial_plan.get_state() == @graphics.DirtySubmitState::Present)
  assert_true(partial_plan.has_dirty())
  assert_true(partial_plan.needs_present())
  assert_true(!partial_plan.was_clipped_away())
  assert_true(!partial_plan.uses_bounds_fallback())
  assert_true(
    partial_plan.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_eq(partial_plan.get_present_rect_count(), 1)
  assert_eq(partial_plan.get_present_pixel_count(), 1)
  assert_eq(partial_plan.get_present_byte_count(), 4)
  assert_true(partial_plan.saves_full_present_pixels())
  assert_eq(partial_count.val, 0)
  assert_true(partial_frame.has_dirty())

  match partial_surface.submit_frame_by_strategy(partial_frame) {
    Ok(result) => {
      assert_true(
        result.get_submit_plan().get_present_strategy() ==
        partial_plan.get_present_strategy(),
      )
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Present)
      assert_true(result.has_dirty())
      assert_true(result.needs_present())
      assert_true(!result.was_clipped_away())
      assert_true(!result.uses_bounds_fallback())
      assert_true(
        result.get_dirty_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      assert_true(result.did_present())
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected partial strategy submit result")
  }
  assert_eq(partial_count.val, 1)
  assert_true(!partial_frame.has_dirty())

  let full_count = Ref(0)
  let full_frame = @graphics.RenderFrame::new(2, 1)
  full_frame.mark_all_dirty()
  let full_surface = NativeSurface::from_frame(42, full_frame).with_pre_present_hook(fn() {
      full_count.val = full_count.val + 1
    },
  )

  let full_plan = full_surface.dirty_frame_submit_by_strategy_plan(full_frame)
  assert_true(
    full_plan.get_present_strategy() == @graphics.DirtyPresentStrategy::Full,
  )
  assert_true(full_plan.get_state() == @graphics.DirtySubmitState::Present)
  assert_true(full_plan.has_dirty())
  assert_true(full_plan.needs_present())
  assert_true(!full_plan.was_clipped_away())
  assert_true(!full_plan.uses_bounds_fallback())
  assert_true(
    full_plan.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
  )
  assert_eq(full_plan.get_present_rect_count(), 1)
  assert_eq(full_plan.get_present_pixel_count(), 2)
  assert_eq(full_plan.get_present_byte_count(), 8)
  assert_true(!full_plan.saves_full_present_pixels())
  assert_eq(full_count.val, 0)
  assert_true(full_frame.has_dirty())

  match full_surface.submit_frame_by_strategy(full_frame) {
    Ok(result) => {
      assert_true(
        result.get_submit_plan().get_present_strategy() ==
        full_plan.get_present_strategy(),
      )
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Full,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Present)
      assert_true(result.has_dirty())
      assert_true(result.needs_present())
      assert_true(!result.was_clipped_away())
      assert_true(!result.uses_bounds_fallback())
      assert_true(
        result.get_dirty_bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
      )
      assert_true(result.did_present())
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 2)
      assert_eq(result.get_present_byte_count(), 8)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected full strategy submit result")
  }
  assert_eq(full_count.val, 1)
  assert_true(!full_frame.has_dirty())

  let bounds_count = Ref(0)
  let bounds_frame = @graphics.RenderFrame::new(8, 1).set_dirty_rect_limit(2)
  bounds_frame.mark_dirty_rect(
    @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
  )
  bounds_frame.mark_dirty_rect(
    @graphics.PixelRect::new(x=3, y=0, width=1, height=1),
  )
  bounds_frame.mark_dirty_rect(
    @graphics.PixelRect::new(x=6, y=0, width=1, height=1),
  )
  let bounds_surface = NativeSurface::from_frame(42, bounds_frame).with_pre_present_hook(fn() {
      bounds_count.val = bounds_count.val + 1
    },
  )

  let bounds_plan = bounds_surface.dirty_frame_submit_by_strategy_plan(
    bounds_frame,
  )
  assert_true(
    bounds_plan.get_present_strategy() ==
    @graphics.DirtyPresentStrategy::Partial,
  )
  assert_true(bounds_plan.get_state() == @graphics.DirtySubmitState::Present)
  assert_true(bounds_plan.has_dirty())
  assert_true(bounds_plan.needs_present())
  assert_true(!bounds_plan.was_clipped_away())
  assert_true(bounds_plan.uses_bounds_fallback())
  assert_true(
    bounds_plan.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=7, height=1)),
  )
  assert_eq(bounds_plan.get_present_rect_count(), 1)
  assert_eq(bounds_plan.get_present_pixel_count(), 7)
  assert_eq(bounds_plan.get_present_byte_count(), 28)
  assert_true(bounds_plan.saves_full_present_pixels())
  assert_eq(bounds_count.val, 0)
  assert_true(bounds_frame.has_dirty())

  match bounds_surface.submit_frame_by_strategy(bounds_frame) {
    Ok(result) => {
      assert_true(
        result.get_submit_plan().uses_bounds_fallback() ==
        bounds_plan.uses_bounds_fallback(),
      )
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Present)
      assert_true(result.has_dirty())
      assert_true(result.needs_present())
      assert_true(!result.was_clipped_away())
      assert_true(result.uses_bounds_fallback())
      assert_true(
        result.get_dirty_bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=7, height=1)),
      )
      assert_true(result.did_present())
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 7)
      assert_eq(result.get_present_byte_count(), 28)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected bounds fallback strategy submit result")
  }
  assert_eq(bounds_count.val, 1)
  assert_true(!bounds_frame.has_dirty())

  let clean_count = Ref(0)
  let clean_frame = @graphics.RenderFrame::new(2, 1)
  let clean_surface = NativeSurface::from_frame(42, clean_frame).with_pre_present_hook(fn() {
      clean_count.val = clean_count.val + 1
    },
  )
  let clean_plan = clean_surface.dirty_frame_submit_by_strategy_plan(
    clean_frame,
  )
  assert_true(
    clean_plan.get_present_strategy() == @graphics.DirtyPresentStrategy::Skip,
  )
  assert_true(clean_plan.get_state() == @graphics.DirtySubmitState::Clean)
  assert_true(!clean_plan.has_dirty())
  assert_true(!clean_plan.needs_present())
  assert_true(!clean_plan.was_clipped_away())
  assert_true(!clean_plan.uses_bounds_fallback())
  assert_true(clean_plan.get_dirty_bounds() == None)
  assert_eq(clean_plan.get_present_rect_count(), 0)
  assert_eq(clean_plan.get_present_pixel_count(), 0)
  assert_eq(clean_plan.get_present_byte_count(), 0)
  assert_true(!clean_plan.saves_full_present_pixels())
  assert_eq(clean_count.val, 0)
  match clean_surface.submit_frame_by_strategy(clean_frame) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Skip,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Clean)
      assert_true(!result.has_dirty())
      assert_true(!result.needs_present())
      assert_true(!result.was_clipped_away())
      assert_true(!result.uses_bounds_fallback())
      assert_true(result.get_dirty_bounds() == None)
      assert_true(!result.did_present())
      assert_eq(result.get_present_rect_count(), 0)
      assert_eq(result.get_presented_rect_count(), 0)
      assert_eq(result.get_present_pixel_count(), 0)
      assert_eq(result.get_present_byte_count(), 0)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected clean strategy submit result")
  }
  assert_eq(clean_count.val, 0)
  assert_true(!clean_frame.has_dirty())
}

///|
test "NativeSurface strategy submit consumes clipped-away dirty without presenting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.mark_dirty_rect(@graphics.PixelRect::new(x=3, y=0, width=1, height=1))
  let surface = NativeSurface::new(42, 2, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })

  let submit_plan = surface.dirty_frame_submit_by_strategy_plan(frame)
  assert_true(
    submit_plan.get_present_strategy() == @graphics.DirtyPresentStrategy::Skip,
  )
  assert_true(
    submit_plan.get_state() == @graphics.DirtySubmitState::DirtyClippedAway,
  )
  assert_true(submit_plan.has_dirty())
  assert_true(!submit_plan.needs_present())
  assert_true(submit_plan.was_clipped_away())
  assert_true(!submit_plan.uses_bounds_fallback())
  assert_true(
    submit_plan.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=3, y=0, width=1, height=1)),
  )
  assert_eq(submit_plan.get_present_rect_count(), 0)
  assert_eq(submit_plan.get_present_pixel_count(), 0)
  assert_eq(submit_plan.get_present_byte_count(), 0)
  assert_true(!submit_plan.saves_full_present_pixels())
  assert_eq(count.val, 0)
  assert_true(frame.has_dirty())

  match surface.submit_frame_by_strategy(frame) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Skip,
      )
      assert_true(
        result.get_state() == @graphics.DirtySubmitState::DirtyClippedAway,
      )
      assert_true(result.has_dirty())
      assert_true(!result.needs_present())
      assert_true(result.was_clipped_away())
      assert_true(!result.uses_bounds_fallback())
      assert_true(
        result.get_dirty_bounds() ==
        Some(@graphics.PixelRect::new(x=3, y=0, width=1, height=1)),
      )
      assert_true(!result.did_present())
      assert_eq(result.get_present_rect_count(), 0)
      assert_eq(result.get_presented_rect_count(), 0)
      assert_eq(result.get_present_pixel_count(), 0)
      assert_eq(result.get_present_byte_count(), 0)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected clipped-away strategy submit result")
  }
  assert_eq(count.val, 0)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface synced strategy submit resizes before planning" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.mark_dirty_rect(@graphics.PixelRect::new(x=3, y=0, width=1, height=1))
  let surface = NativeSurface::new(42, 2, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })

  assert_true(!surface.matches_frame(frame))
  match surface.submit_synced_frame_by_strategy(frame) {
    Ok(result) => {
      assert_true(surface.matches_frame(frame))
      assert_eq(surface.get_width(), 4)
      assert_eq(surface.get_height(), 1)
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Present)
      assert_true(result.did_present())
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected synced strategy submit result")
  }
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface synced policy submit resizes clean cached redraw" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(3, 1)
  let surface = NativeSurface::new(42, 1, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })

  assert_true(!surface.matches_frame(frame))
  match
    surface.submit_synced_frame_by_policy(
      frame,
      @graphics.RenderFrameSubmitPolicy::CachedRedraw,
    ) {
    Ok(result) => {
      assert_true(surface.matches_frame(frame))
      assert_eq(surface.get_width(), 3)
      assert_eq(surface.get_height(), 1)
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Full,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Clean)
      assert_true(!result.has_dirty())
      assert_true(result.needs_present())
      assert_true(result.did_present())
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 3)
      assert_eq(result.get_present_byte_count(), 12)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected synced policy submit result")
  }
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface synced policy submit resizes dirty full redraw" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(1, 1)
  frame.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  frame.clear_dirty_regions()

  let layer = @graphics.Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::blue())
  ignore(frame.get_layer_tree().add_layer(layer))
  ignore(frame.resize(2, 1))

  let surface = NativeSurface::new(42, 1, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })

  assert_true(!surface.matches_frame(frame))
  match
    surface.submit_synced_frame_by_policy(
      frame,
      @graphics.RenderFrameSubmitPolicy::FullRedraw,
    ) {
    Ok(result) => {
      assert_true(surface.matches_frame(frame))
      assert_eq(surface.get_width(), 2)
      assert_eq(surface.get_height(), 1)
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Full,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Present)
      assert_true(result.has_dirty())
      assert_true(result.needs_present())
      assert_true(result.did_present())
      assert_true(
        result.get_dirty_bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
      )
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
      )
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 2)
      assert_eq(result.get_present_byte_count(), 8)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected synced full redraw policy submit result")
  }
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface schedule delegates graphics schedule telemetry" {
  let frame = @graphics.RenderFrame::new(5, 1)
  frame.mark_dirty_rect(@graphics.PixelRect::new(x=2, y=0, width=1, height=1))
  let surface = NativeSurface::from_frame(42, frame)
  let native_schedule = surface.frame_schedule(frame)
  let graphics_schedule = frame.submit_schedule(surface)

  assert_true(native_schedule.get_action() == graphics_schedule.get_action())
  assert_true(
    native_schedule.get_action() == @graphics.RenderFrameScheduleAction::Present,
  )
  assert_true(native_schedule.get_state() == graphics_schedule.get_state())
  assert_true(
    native_schedule.get_dirty_bounds() == graphics_schedule.get_dirty_bounds(),
  )
  assert_true(
    native_schedule.get_present_bounds() ==
    graphics_schedule.get_present_bounds(),
  )
  assert_true(native_schedule.has_dirty() == graphics_schedule.has_dirty())
  assert_true(
    native_schedule.needs_present() == graphics_schedule.needs_present(),
  )
  assert_true(
    native_schedule.should_submit() == graphics_schedule.should_submit(),
  )
  assert_true(
    native_schedule.was_clipped_away() == graphics_schedule.was_clipped_away(),
  )
  assert_true(
    native_schedule.uses_bounds_fallback() ==
    graphics_schedule.uses_bounds_fallback(),
  )
  assert_eq(
    native_schedule.get_present_rect_count(),
    graphics_schedule.get_present_rect_count(),
  )
  assert_eq(
    native_schedule.get_present_pixel_count(),
    graphics_schedule.get_present_pixel_count(),
  )
  assert_eq(
    native_schedule.get_present_byte_count(),
    graphics_schedule.get_present_byte_count(),
  )
  assert_true(
    native_schedule.saves_full_present_pixels() ==
    graphics_schedule.saves_full_present_pixels(),
  )
}

///|
test "NativeSurface exposes dry-run frame schedule actions" {
  let partial_count = Ref(0)
  let partial_frame = @graphics.RenderFrame::new(4, 1)
  partial_frame.mark_dirty_rect(
    @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
  )
  let partial_surface = NativeSurface::from_frame(42, partial_frame).with_pre_present_hook(fn() {
      partial_count.val = partial_count.val + 1
    },
  )
  let partial_schedule = partial_surface.frame_schedule(partial_frame)
  assert_true(
    partial_schedule.get_action() ==
    @graphics.RenderFrameScheduleAction::Present,
  )
  assert_true(partial_schedule.should_submit())
  assert_true(partial_schedule.needs_present())
  assert_true(partial_schedule.has_dirty())
  assert_true(!partial_schedule.was_clipped_away())
  assert_true(!partial_schedule.uses_bounds_fallback())
  assert_true(
    partial_schedule.get_present_strategy() ==
    @graphics.DirtyPresentStrategy::Partial,
  )
  assert_true(
    partial_schedule.get_state() == @graphics.DirtySubmitState::Present,
  )
  assert_true(
    partial_schedule.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_eq(partial_schedule.get_present_rect_count(), 1)
  assert_eq(partial_schedule.get_present_pixel_count(), 1)
  assert_eq(partial_schedule.get_present_byte_count(), 4)
  assert_true(partial_schedule.saves_full_present_pixels())
  assert_eq(partial_count.val, 0)
  assert_true(partial_frame.has_dirty())

  let clipped_frame = @graphics.RenderFrame::new(4, 1)
  clipped_frame.mark_dirty_rect(
    @graphics.PixelRect::new(x=3, y=0, width=1, height=1),
  )
  let clipped_surface = NativeSurface::new(42, 2, 1).with_pre_present_hook(fn() {
    partial_count.val = partial_count.val + 1
  })
  let clipped_schedule = clipped_surface.frame_schedule(clipped_frame)
  assert_true(
    clipped_schedule.get_action() ==
    @graphics.RenderFrameScheduleAction::SubmitWithoutPresent,
  )
  assert_true(clipped_schedule.should_submit())
  assert_true(!clipped_schedule.needs_present())
  assert_true(clipped_schedule.has_dirty())
  assert_true(clipped_schedule.was_clipped_away())
  assert_true(
    clipped_schedule.get_present_strategy() ==
    @graphics.DirtyPresentStrategy::Skip,
  )
  assert_true(
    clipped_schedule.get_state() == @graphics.DirtySubmitState::DirtyClippedAway,
  )
  assert_eq(clipped_schedule.get_present_rect_count(), 0)
  assert_eq(clipped_schedule.get_present_pixel_count(), 0)
  assert_eq(clipped_schedule.get_present_byte_count(), 0)
  assert_true(!clipped_schedule.saves_full_present_pixels())
  assert_eq(partial_count.val, 0)
  assert_true(clipped_frame.has_dirty())

  let clean_frame = @graphics.RenderFrame::new(2, 1)
  let clean_schedule = NativeSurface::from_frame(42, clean_frame).frame_schedule(
    clean_frame,
  )
  assert_true(
    clean_schedule.get_action() == @graphics.RenderFrameScheduleAction::Skip,
  )
  assert_true(!clean_schedule.should_submit())
  assert_true(!clean_schedule.needs_present())
  assert_true(!clean_schedule.has_dirty())
  assert_true(clean_schedule.get_dirty_bounds() == None)
  assert_true(
    clean_schedule.get_present_strategy() ==
    @graphics.DirtyPresentStrategy::Skip,
  )
  assert_true(clean_schedule.get_state() == @graphics.DirtySubmitState::Clean)
}

///|
test "NativeSurface exposes clean redraw schedule as full cached present" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(2, 1)
  let layer = @graphics.Layer::new(2, 1)
  layer.clear(@graphics.Color::white())
  layer.get_canvas().draw_pixel(1, 0, @graphics.Color::blue())
  ignore(frame.get_layer_tree().add_layer(layer))
  assert_true(
    frame.present_dirty_to(@graphics.MemorySurface::new(2, 1)) == Ok(1),
  )
  assert_true(!frame.has_dirty())

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  let regular_schedule = surface.frame_schedule(frame)
  assert_true(
    regular_schedule.get_action() == @graphics.RenderFrameScheduleAction::Skip,
  )
  assert_true(!regular_schedule.needs_present())
  assert_true(
    regular_schedule.get_present_strategy() ==
    @graphics.DirtyPresentStrategy::Skip,
  )

  let redraw_schedule = surface.frame_redraw_schedule(frame)
  assert_true(
    redraw_schedule.get_action() == @graphics.RenderFrameScheduleAction::Present,
  )
  assert_true(redraw_schedule.should_submit())
  assert_true(redraw_schedule.needs_present())
  assert_true(!redraw_schedule.has_dirty())
  assert_true(
    redraw_schedule.get_present_strategy() ==
    @graphics.DirtyPresentStrategy::Full,
  )
  assert_true(redraw_schedule.get_state() == @graphics.DirtySubmitState::Clean)
  assert_true(redraw_schedule.get_dirty_bounds() == None)
  assert_eq(redraw_schedule.get_present_rect_count(), 1)
  assert_eq(redraw_schedule.get_present_pixel_count(), 2)
  assert_eq(redraw_schedule.get_present_byte_count(), 8)
  assert_true(!redraw_schedule.saves_full_present_pixels())
  assert_eq(count.val, 0)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface exposes policy-driven frame schedules" {
  let clean_frame = @graphics.RenderFrame::new(2, 1)
  let clean_surface = NativeSurface::from_frame(42, clean_frame)
  let dirty_only_schedule = clean_surface.frame_schedule_by_policy(
    clean_frame,
    @graphics.RenderFrameSubmitPolicy::DirtyOnly,
  )
  assert_true(
    dirty_only_schedule.get_action() ==
    @graphics.RenderFrameScheduleAction::Skip,
  )
  assert_true(
    dirty_only_schedule.get_present_strategy() ==
    @graphics.DirtyPresentStrategy::Skip,
  )
  assert_true(
    dirty_only_schedule.get_state() == @graphics.DirtySubmitState::Clean,
  )
  assert_true(!dirty_only_schedule.needs_present())

  let cached_schedule = clean_surface.frame_schedule_by_policy(
    clean_frame,
    @graphics.RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_true(
    cached_schedule.get_action() == @graphics.RenderFrameScheduleAction::Present,
  )
  assert_true(
    cached_schedule.get_present_strategy() ==
    @graphics.DirtyPresentStrategy::Full,
  )
  assert_true(cached_schedule.get_state() == @graphics.DirtySubmitState::Clean)
  assert_true(cached_schedule.needs_present())
  assert_true(!cached_schedule.has_dirty())
  assert_true(
    cached_schedule.get_present_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
  )
  assert_eq(cached_schedule.get_present_pixel_count(), 2)
  assert_eq(cached_schedule.get_present_byte_count(), 8)

  let dirty_frame = @graphics.RenderFrame::new(4, 1)
  dirty_frame.get_canvas().draw_pixel(1, 0, @graphics.Color::red())
  let dirty_surface = NativeSurface::from_frame(42, dirty_frame)
  let cached_dirty_schedule = dirty_surface.frame_schedule_by_policy(
    dirty_frame,
    @graphics.RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_true(
    cached_dirty_schedule.get_action() ==
    @graphics.RenderFrameScheduleAction::Present,
  )
  assert_true(
    cached_dirty_schedule.get_present_strategy() ==
    @graphics.DirtyPresentStrategy::Partial,
  )
  assert_true(
    cached_dirty_schedule.get_state() == @graphics.DirtySubmitState::Present,
  )
  assert_true(cached_dirty_schedule.has_dirty())
  assert_true(
    cached_dirty_schedule.get_present_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_eq(cached_dirty_schedule.get_present_pixel_count(), 1)
  assert_eq(cached_dirty_schedule.get_present_byte_count(), 4)

  let full_dirty_schedule = dirty_surface.frame_schedule_by_policy(
    dirty_frame,
    @graphics.RenderFrameSubmitPolicy::FullRedraw,
  )
  assert_true(
    full_dirty_schedule.get_action() ==
    @graphics.RenderFrameScheduleAction::Present,
  )
  assert_true(
    full_dirty_schedule.get_present_strategy() ==
    @graphics.DirtyPresentStrategy::Full,
  )
  assert_true(
    full_dirty_schedule.get_state() == @graphics.DirtySubmitState::Present,
  )
  assert_true(full_dirty_schedule.has_dirty())
  assert_true(full_dirty_schedule.needs_present())
  assert_true(
    full_dirty_schedule.get_present_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=1)),
  )
  assert_eq(full_dirty_schedule.get_present_rect_count(), 1)
  assert_eq(full_dirty_schedule.get_present_pixel_count(), 4)
  assert_eq(full_dirty_schedule.get_present_byte_count(), 16)
  assert_true(!full_dirty_schedule.saves_full_present_pixels())
  assert_true(dirty_frame.has_dirty())
}

///|
test "NativeSurface submits precomputed frame schedules" {
  let count = Ref(0)
  let partial_frame = @graphics.RenderFrame::new(4, 1)
  partial_frame.get_canvas().draw_pixel(1, 0, @graphics.Color::red())
  let partial_surface = NativeSurface::from_frame(42, partial_frame).with_pre_present_hook(fn() {
      count.val = count.val + 1
    },
  )
  let partial_schedule = partial_surface.frame_schedule(partial_frame)
  match partial_surface.submit_frame_schedule(partial_frame, partial_schedule) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Present)
      assert_true(result.did_present())
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected scheduled partial submit result")
  }
  assert_eq(count.val, 1)
  assert_true(!partial_frame.has_dirty())

  let clipped_frame = @graphics.RenderFrame::new(4, 1)
  clipped_frame.mark_dirty_rect(
    @graphics.PixelRect::new(x=3, y=0, width=1, height=1),
  )
  let clipped_surface = NativeSurface::new(42, 2, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  let clipped_schedule = clipped_surface.frame_schedule(clipped_frame)
  match clipped_surface.submit_frame_schedule(clipped_frame, clipped_schedule) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Skip,
      )
      assert_true(
        result.get_state() == @graphics.DirtySubmitState::DirtyClippedAway,
      )
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
  assert_eq(count.val, 1)
  assert_true(!clipped_frame.has_dirty())

  let clean_frame = @graphics.RenderFrame::new(2, 1)
  let clean_surface = NativeSurface::from_frame(42, clean_frame).with_pre_present_hook(fn() {
      count.val = count.val + 1
    },
  )
  let clean_schedule = clean_surface.frame_schedule(clean_frame)
  match clean_surface.submit_frame_schedule(clean_frame, clean_schedule) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Skip,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Clean)
      assert_true(!result.has_dirty())
      assert_true(!result.needs_present())
      assert_true(!result.did_present())
      assert_eq(result.get_presented_rect_count(), 0)
      assert_eq(result.get_present_pixel_count(), 0)
      assert_eq(result.get_present_byte_count(), 0)
    }
    Err(_) => abort("expected scheduled clean submit result")
  }
  assert_eq(count.val, 1)
  assert_true(!clean_frame.has_dirty())
}

///|
test "NativeSurface refreshes clean precomputed schedule after layer dirty" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(2, 1)
  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  let schedule = surface.frame_schedule(frame)
  assert_true(
    schedule.get_action() == @graphics.RenderFrameScheduleAction::Skip,
  )
  assert_true(schedule.get_state() == @graphics.DirtySubmitState::Clean)
  assert_true(!schedule.has_dirty())
  assert_true(!frame.has_dirty())

  let layer = @graphics.Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)
  assert_true(frame.has_dirty())

  match surface.submit_frame_schedule(frame, schedule) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Present)
      assert_true(result.has_dirty())
      assert_true(result.needs_present())
      assert_true(result.did_present())
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected refreshed dirty submit result")
  }
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
}

///|
test "NativeSurface refreshes resized precomputed schedule telemetry" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.mark_dirty_rect(@graphics.PixelRect::new(x=3, y=0, width=1, height=1))
  let surface = NativeSurface::new(42, 2, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  let schedule = surface.frame_schedule(frame)
  assert_true(
    schedule.get_action() ==
    @graphics.RenderFrameScheduleAction::SubmitWithoutPresent,
  )
  assert_true(
    schedule.get_state() == @graphics.DirtySubmitState::DirtyClippedAway,
  )
  assert_true(schedule.was_clipped_away())

  surface.resize(4, 1)
  match surface.submit_frame_schedule(frame, schedule) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Present)
      assert_true(result.did_present())
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=3, y=0, width=1, height=1)),
      )
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
    }
    Err(_) => abort("expected resized scheduled partial submit result")
  }
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface submits clean redraw as cached full present" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(2, 1)
  let layer = @graphics.Layer::new(2, 1)
  layer.clear(@graphics.Color::white())
  layer.get_canvas().draw_pixel(1, 0, @graphics.Color::blue())
  ignore(frame.get_layer_tree().add_layer(layer))
  assert_true(
    frame.present_dirty_to(@graphics.MemorySurface::new(2, 1)) == Ok(1),
  )
  assert_true(!frame.has_dirty())

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  match surface.submit_frame_redraw(frame) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Full,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Clean)
      assert_true(!result.has_dirty())
      assert_true(result.needs_present())
      assert_true(result.did_present())
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 2)
      assert_eq(result.get_present_byte_count(), 8)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected redraw submit result")
  }
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface submits frame by explicit policy" {
  let count = Ref(0)
  let dirty_frame = @graphics.RenderFrame::new(4, 1)
  dirty_frame.get_canvas().draw_pixel(1, 0, @graphics.Color::red())
  let dirty_surface = NativeSurface::from_frame(42, dirty_frame).with_pre_present_hook(fn() {
      count.val = count.val + 1
    },
  )

  match
    dirty_surface.submit_frame_by_policy(
      dirty_frame,
      @graphics.RenderFrameSubmitPolicy::FullRedraw,
    ) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Full,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Present)
      assert_true(result.has_dirty())
      assert_true(result.did_present())
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 4)
      assert_eq(result.get_present_byte_count(), 16)
    }
    Err(_) => abort("expected policy submit result")
  }
  assert_eq(count.val, 1)
  assert_true(!dirty_frame.has_dirty())

  let clean_frame = @graphics.RenderFrame::new(2, 1)
  let clean_surface = NativeSurface::from_frame(42, clean_frame).with_pre_present_hook(fn() {
      count.val = count.val + 1
    },
  )
  match
    clean_surface.submit_frame_by_policy(
      clean_frame,
      @graphics.RenderFrameSubmitPolicy::DirtyOnly,
    ) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Skip,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Clean)
      assert_true(!result.has_dirty())
      assert_true(!result.needs_present())
      assert_true(!result.did_present())
      assert_eq(result.get_presented_rect_count(), 0)
    }
    Err(_) => abort("expected dirty-only policy submit result")
  }
  assert_eq(count.val, 1)
}

///|
test "NativeSurface submit requests preserve policy and schedule decisions" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().draw_pixel(1, 0, @graphics.Color::red())
  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })

  let request = surface.frame_submit_request_by_policy(
    frame,
    @graphics.RenderFrameSubmitPolicy::FullRedraw,
  )
  assert_true(
    request.get_policy() == @graphics.RenderFrameSubmitPolicy::FullRedraw,
  )
  assert_true(
    request.get_action() == @graphics.RenderFrameScheduleAction::Present,
  )
  assert_true(request.should_submit())
  assert_true(request.needs_present())
  assert_true(request.has_dirty())
  assert_true(!request.was_clipped_away())
  assert_true(!request.uses_bounds_fallback())
  assert_true(
    request.get_present_strategy() == @graphics.DirtyPresentStrategy::Full,
  )
  assert_true(request.get_state() == @graphics.DirtySubmitState::Present)
  assert_true(
    request.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_true(
    request.get_present_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=1)),
  )
  assert_true(
    request.get_schedule().get_submit_plan().get_present_strategy() ==
    @graphics.DirtyPresentStrategy::Full,
  )
  assert_eq(request.get_present_rect_count(), 1)
  assert_eq(request.get_present_pixel_count(), 4)
  assert_eq(request.get_present_byte_count(), 16)
  assert_true(!request.saves_full_present_pixels())
  assert_eq(count.val, 0)
  assert_true(frame.has_dirty())

  match surface.submit_frame_request(frame, request) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Full,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Present)
      assert_true(result.did_present())
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=1)),
      )
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 4)
      assert_eq(result.get_present_byte_count(), 16)
    }
    Err(_) => abort("expected native submit request result")
  }
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())

  let clean_frame = @graphics.RenderFrame::new(2, 1)
  let clean_surface = NativeSurface::from_frame(42, clean_frame).with_pre_present_hook(fn() {
      count.val = count.val + 1
    },
  )
  let clean_schedule = clean_surface.frame_schedule_by_policy(
    clean_frame,
    @graphics.RenderFrameSubmitPolicy::DirtyOnly,
  )
  let clean_request = @graphics.RenderFrameSubmitRequest::new(
    @graphics.RenderFrameSubmitPolicy::DirtyOnly,
    clean_schedule,
  )
  assert_true(
    clean_request.get_policy() == @graphics.RenderFrameSubmitPolicy::DirtyOnly,
  )
  assert_true(
    clean_request.get_action() == @graphics.RenderFrameScheduleAction::Skip,
  )
  assert_true(!clean_request.should_submit())
  assert_true(!clean_request.needs_present())
  assert_true(!clean_request.has_dirty())
  assert_true(clean_request.get_dirty_bounds() == None)
  assert_true(clean_request.get_present_bounds() == None)
  match clean_surface.submit_frame_request(clean_frame, clean_request) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Skip,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Clean)
      assert_true(!result.did_present())
      assert_eq(result.get_presented_rect_count(), 0)
    }
    Err(_) => abort("expected clean native submit request result")
  }
  assert_eq(count.val, 1)
}

///|
test "NativeSurface refreshes clean precomputed request after layer dirty" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(2, 1)
  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  let request = surface.frame_submit_request_by_policy(
    frame,
    @graphics.RenderFrameSubmitPolicy::DirtyOnly,
  )
  assert_true(
    request.get_policy() == @graphics.RenderFrameSubmitPolicy::DirtyOnly,
  )
  assert_true(request.get_action() == @graphics.RenderFrameScheduleAction::Skip)
  assert_true(request.get_state() == @graphics.DirtySubmitState::Clean)
  assert_true(!request.should_submit())
  assert_true(!request.has_dirty())
  assert_true(!request.needs_present())
  assert_true(request.get_dirty_bounds() == None)
  assert_true(request.get_present_bounds() == None)

  let layer = @graphics.Layer::new(1, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(frame.get_layer_tree().add_layer(layer), 0)
  assert_true(frame.has_dirty())

  match surface.submit_frame_request(frame, request) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Present)
      assert_true(result.has_dirty())
      assert_true(result.needs_present())
      assert_true(result.did_present())
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
      )
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
      assert_true(result.saves_full_present_pixels())
    }
    Err(_) => abort("expected refreshed dirty submit request result")
  }
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
}

///|
test "NativeSurface submit request refreshes resized precomputed request telemetry" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.mark_dirty_rect(@graphics.PixelRect::new(x=3, y=0, width=1, height=1))
  let surface = NativeSurface::new(42, 2, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })

  let request = surface.frame_submit_request_by_policy(
    frame,
    @graphics.RenderFrameSubmitPolicy::DirtyOnly,
  )
  assert_true(
    request.get_policy() == @graphics.RenderFrameSubmitPolicy::DirtyOnly,
  )
  assert_true(
    request.get_action() ==
    @graphics.RenderFrameScheduleAction::SubmitWithoutPresent,
  )
  assert_true(request.should_submit())
  assert_true(!request.needs_present())
  assert_true(request.has_dirty())
  assert_true(request.was_clipped_away())
  assert_true(
    request.get_present_strategy() == @graphics.DirtyPresentStrategy::Skip,
  )
  assert_true(
    request.get_state() == @graphics.DirtySubmitState::DirtyClippedAway,
  )
  assert_true(
    request.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=3, y=0, width=1, height=1)),
  )
  assert_true(request.get_present_bounds() == None)
  assert_eq(request.get_present_rect_count(), 0)
  assert_eq(request.get_present_pixel_count(), 0)
  assert_eq(request.get_present_byte_count(), 0)
  assert_eq(count.val, 0)
  assert_true(frame.has_dirty())

  surface.resize(4, 1)
  match surface.submit_frame_request(frame, request) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Present)
      assert_true(result.did_present())
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=3, y=0, width=1, height=1)),
      )
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
    }
    Err(_) => abort("expected resized native submit request result")
  }
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface syncs before building submit requests" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.get_canvas().draw_pixel(2, 0, @graphics.Color::red())
  let surface = NativeSurface::new(42, 1, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })

  let request = surface.sync_frame_submit_request_by_policy(
    frame,
    @graphics.RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_eq(surface.get_width(), 4)
  assert_eq(surface.get_height(), 1)
  assert_true(
    request.get_policy() == @graphics.RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_true(
    request.get_action() == @graphics.RenderFrameScheduleAction::Present,
  )
  assert_true(
    request.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
  )
  assert_true(request.get_state() == @graphics.DirtySubmitState::Present)
  assert_true(request.should_submit())
  assert_true(request.needs_present())
  assert_true(request.has_dirty())
  assert_true(
    request.get_present_bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=0, width=1, height=1)),
  )
  assert_eq(request.get_present_rect_count(), 1)
  assert_eq(request.get_present_pixel_count(), 1)
  assert_eq(request.get_present_byte_count(), 4)
  assert_true(request.saves_full_present_pixels())
  assert_eq(count.val, 0)
  assert_true(frame.has_dirty())

  match surface.submit_frame_request(frame, request) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Partial,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Present)
      assert_true(result.did_present())
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 1)
      assert_eq(result.get_present_byte_count(), 4)
    }
    Err(_) => abort("expected synced native submit request result")
  }
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface syncs clean cached redraw submit request before presenting" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(3, 1)
  assert_true(!frame.has_dirty())
  let surface = NativeSurface::new(42, 1, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })

  let request = surface.sync_frame_submit_request_by_policy(
    frame,
    @graphics.RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_eq(surface.get_width(), 3)
  assert_eq(surface.get_height(), 1)
  assert_eq(count.val, 0)
  assert_true(
    request.get_policy() == @graphics.RenderFrameSubmitPolicy::CachedRedraw,
  )
  assert_true(
    request.get_action() == @graphics.RenderFrameScheduleAction::Present,
  )
  assert_true(
    request.get_present_strategy() == @graphics.DirtyPresentStrategy::Full,
  )
  assert_true(request.get_state() == @graphics.DirtySubmitState::Clean)
  assert_true(request.should_submit())
  assert_true(request.needs_present())
  assert_true(!request.has_dirty())
  assert_true(request.get_dirty_bounds() == None)
  assert_true(
    request.get_present_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=3, height=1)),
  )
  assert_eq(request.get_present_rect_count(), 1)
  assert_eq(request.get_present_pixel_count(), 3)
  assert_eq(request.get_present_byte_count(), 12)
  assert_true(!request.saves_full_present_pixels())
  assert_true(!frame.has_dirty())

  match surface.submit_frame_request(frame, request) {
    Ok(result) => {
      assert_true(
        result.get_present_strategy() == @graphics.DirtyPresentStrategy::Full,
      )
      assert_true(result.get_state() == @graphics.DirtySubmitState::Clean)
      assert_true(!result.has_dirty())
      assert_true(result.needs_present())
      assert_true(result.did_present())
      assert_true(
        result.get_present_bounds() ==
        Some(@graphics.PixelRect::new(x=0, y=0, width=3, height=1)),
      )
      assert_eq(result.get_present_rect_count(), 1)
      assert_eq(result.get_presented_rect_count(), 1)
      assert_eq(result.get_present_pixel_count(), 3)
      assert_eq(result.get_present_byte_count(), 12)
      assert_true(!result.saves_full_present_pixels())
    }
    Err(_) => abort("expected synced clean native cached redraw request result")
  }
  assert_eq(count.val, 1)
  assert_true(!frame.has_dirty())
}

///|
test "NativeSurface dirty submit skips clipped-away presents" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(4, 1)
  frame.mark_dirty_rect(@graphics.PixelRect::new(x=3, y=0, width=1, height=1))
  let surface = NativeSurface::new(42, 2, 1).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })

  match surface.submit_frame_dirty(frame) {
    Ok(result) => {
      assert_true(
        result.get_state() == @graphics.DirtySubmitState::DirtyClippedAway,
      )
      assert_eq(result.get_presented_rect_count(), 0)
      assert_true(result.has_dirty())
      assert_true(!result.needs_present())
      assert_true(!result.did_present())
      assert_eq(result.get_present_pixel_count(), 0)
      assert_eq(result.get_present_byte_count(), 0)
      assert_true(!result.saves_full_present_pixels(2, 1))
      assert_true(
        result.get_present_strategy(2, 1) ==
        @graphics.DirtyPresentStrategy::Skip,
      )
      assert_true(result.was_clipped_away())
    }
    Err(_) => abort("expected clipped-away submit result")
  }
  assert_eq(count.val, 0)
  assert_true(!frame.has_dirty())
}

///|
