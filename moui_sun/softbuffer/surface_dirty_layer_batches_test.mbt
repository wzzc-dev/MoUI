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
