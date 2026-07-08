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
