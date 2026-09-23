///|
/// Frame contract regression suite for the Skia route: every presented frame
/// fully overwrites the surface. Damage rects from the runtime must never
/// leave previous-frame pixels (e.g. a scrolled image ghost) behind.
test "skia render_frame full damage clears entire surface" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=16.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  // Frame 1: paint entire surface black.
  let first = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [
        FillRect(
          @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
          @core.Color::black(),
        ),
      ],
      @core.DamageRegion::full("baseline black"),
    ),
  )
  inspect(first.presented, content="true")
  guard renderer.last_frame() is Some(first_frame) else {
    fail("expected first frame")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      first_frame,
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
    ),
  )
  // Frame 2: FullSurface damage with empty command list clears to white.
  let second = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [],
      @core.DamageRegion::full("clear to white"),
    ),
  )
  inspect(second.presented, content="true")
  guard renderer.last_frame() is Some(second_frame) else {
    fail("expected second frame")
  }
  assert_false(
    skia_test_region_has_dark_pixel(
      second_frame,
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
    ),
  )
}

///|
test "skia preserves transparent modal scrim pixels" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let result = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        FillRect(
          @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
          @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.22),
        ),
      ],
      damage=@core.DamageRegion::full("transparent modal scrim"),
      clear_color=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
    ),
  )
  assert_true(result.presented)
  guard renderer.last_frame() is Some(frame) else {
    fail("expected transparent modal frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      (red, green, blue, alpha) => {
        red == 0 && green == 0 && blue == 0 && alpha >= 55 && alpha <= 57
      },
    ),
  )
}

///|
test "skia frame contract fully overwrites despite rect damage" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=16.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  // Frame 1: paint entire surface black (the previous scroll frame's image).
  let _ = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [
        FillRect(
          @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
          @core.Color::black(),
        ),
      ],
      @core.DamageRegion::full("baseline black"),
    ),
  )
  // Frame 2: runtime damage covers only the left half, but the frame must
  // fully overwrite the surface: the right half loses its previous-frame
  // pixels even though no command draws there. This pins the ghost fix —
  // retained backing pixels must never survive into a presented frame.
  let second = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [
        FillRect(
          @core.Rect::new(x=8.0, y=0.0, width=8.0, height=16.0),
          @core.Color::black(),
        ),
      ],
      Rects([@core.Rect::new(x=0.0, y=0.0, width=8.0, height=16.0)]),
    ),
  )
  inspect(second.presented, content="true")
  guard renderer.last_frame() is Some(second_frame) else {
    fail("expected second frame")
  }
  // Left half: cleared to white (nothing drawn there this frame).
  assert_false(
    skia_test_region_has_dark_pixel(
      second_frame,
      @core.Rect::new(x=0.0, y=0.0, width=8.0, height=16.0),
    ),
  )
  // Right half: cleared too, then drawn black again by this frame's command.
  // Under the old contract it stayed black via retention; the black now
  // comes from this frame's FillRect, and a command-less region proves the
  // clear covers outside the damage rect (see the empty-command variant).
  assert_true(
    skia_test_region_has_dark_pixel(
      second_frame,
      @core.Rect::new(x=8.0, y=0.0, width=8.0, height=16.0),
    ),
  )
  // Same shape, no commands at all: the full clear alone must reach the
  // region outside the damage rect.
  let third = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [],
      Rects([@core.Rect::new(x=0.0, y=0.0, width=8.0, height=16.0)]),
    ),
  )
  inspect(third.presented, content="true")
  guard renderer.last_frame() is Some(third_frame) else {
    fail("expected third frame")
  }
  assert_false(
    skia_test_region_has_dark_pixel(
      third_frame,
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
    ),
  )
}

///|
test "skia render_frame empty damage falls back to full clear" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=16.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  // Frame 1: paint entire surface black.
  let _ = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [
        FillRect(
          @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
          @core.Color::black(),
        ),
      ],
      @core.DamageRegion::full("baseline black"),
    ),
  )
  // Frame 2: Empty damage with empty commands. resolve_effective_damage
  // should fall back to FullSurface, clearing the entire surface to white.
  let second = renderer.render_frame(
    skia_test_draw_frame_with_damage([], @core.DamageRegion::empty()),
  )
  inspect(second.presented, content="true")
  guard renderer.last_frame() is Some(second_frame) else {
    fail("expected second frame")
  }
  assert_false(
    skia_test_region_has_dark_pixel(
      second_frame,
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
    ),
  )
}

///|
test "skia redraws retained layer outside damage rects instead of retaining" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=16.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let spec = @core.RetainedLayerSpec::new(
    key="skia-damage-redraw",
    frame=@core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0),
    content_revision=1,
  )
  // Frame 1: establish cached layer at (2,2,4,4).
  let first = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [
        Clear(@core.Color::white()),
        BeginRetainedLayer(spec),
        FillRect(
          @core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0),
          @core.Color::black(),
        ),
        EndRetainedLayer(spec.key),
      ],
      @core.DamageRegion::full("establish cached layer"),
    ),
  )
  inspect(first.presented, content="true")
  inspect(first.cache_update_count, content="1")
  inspect(first.cache_hit_count, content="0")
  inspect(first.cache_miss_count, content="1")
  // Frame 2: damage at (10,10,4,4) does not intersect the retained layer.
  // The contract forbids skipping the layer and letting surface retention
  // keep it visible; the layer must be re-blitted from its cached raster.
  let second = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [
        Clear(@core.Color::white()),
        BeginRetainedLayer(spec),
        FillRect(spec.frame, @core.Color::black()),
        EndRetainedLayer(spec.key),
      ],
      Rects([@core.Rect::new(x=10.0, y=10.0, width=4.0, height=4.0)]),
    ),
  )
  inspect(second.presented, content="true")
  inspect(second.cache_hit_count, content="1")
  inspect(second.cache_miss_count, content="0")
  guard renderer.last_frame() is Some(second_frame) else {
    fail("expected second frame")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      second_frame,
      @core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0),
    ),
  )
}

///|
test "skia frame contract clears hidpi surface despite rect damage" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=16.0),
      scale_factor=2.0,
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  ignore(
    renderer.render_frame(
      skia_test_draw_frame_with_damage(
        [
          FillRect(
            @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
            @core.Color::black(),
          ),
        ],
        @core.DamageRegion::full("baseline black"),
      ),
    ),
  )
  let second = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [],
      Rects([@core.Rect::new(x=0.0, y=0.0, width=8.0, height=16.0)]),
    ),
  )
  inspect(second.presented, content="true")
  guard renderer.last_frame() is Some(second_frame) else {
    fail("expected second frame")
  }
  // The full clear is applied before the logical-coordinate scale, so the
  // entire physical surface loses the previous frame's pixels.
  assert_false(
    skia_test_region_has_dark_pixel(
      second_frame,
      @core.Rect::new(x=0.0, y=0.0, width=32.0, height=32.0),
    ),
  )
}

///|
test "skia scope commands never rely on partial damage" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=16.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  // Frame 1: paint entire surface black.
  let _ = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [
        FillRect(
          @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
          @core.Color::black(),
        ),
      ],
      @core.DamageRegion::full("baseline black"),
    ),
  )
  // Frame 2: Rects damage with PushOpacity/PopOpacity in the stream. The
  // frame contract clears everything regardless of scope commands.
  let second = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [PushOpacity(1.0), PopOpacity],
      Rects([@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0)]),
    ),
  )
  inspect(second.presented, content="true")
  guard renderer.last_frame() is Some(second_frame) else {
    fail("expected second frame")
  }
  assert_false(
    skia_test_region_has_dark_pixel(
      second_frame,
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
    ),
  )
}
