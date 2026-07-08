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
