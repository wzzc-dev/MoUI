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
