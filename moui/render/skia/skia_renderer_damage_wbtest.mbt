///|
test "skia render_frame full damage clears entire surface" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
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
        @core.DrawCommand::FillRect(
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
test "skia render_frame rects damage clears only dirty rects" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
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
        @core.DrawCommand::FillRect(
          @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
          @core.Color::black(),
        ),
      ],
      @core.DamageRegion::full("baseline black"),
    ),
  )
  // Frame 2: damage only the left half; draw black on the right half.
  // Left half should be cleared to white; right half retains black from
  // frame 1 and gets black drawn over it.
  let second = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [
        @core.DrawCommand::FillRect(
          @core.Rect::new(x=8.0, y=0.0, width=8.0, height=16.0),
          @core.Color::black(),
        ),
      ],
      @core.DamageRegion::Rects([
        @core.Rect::new(x=0.0, y=0.0, width=8.0, height=16.0),
      ]),
    ),
  )
  inspect(second.presented, content="true")
  guard renderer.last_frame() is Some(second_frame) else {
    fail("expected second frame")
  }
  // Left half: cleared to white by partial damage clear.
  assert_false(
    skia_test_region_has_dark_pixel(
      second_frame,
      @core.Rect::new(x=0.0, y=0.0, width=8.0, height=16.0),
    ),
  )
  // Right half: retains black (not cleared, then black drawn).
  assert_true(
    skia_test_region_has_dark_pixel(
      second_frame,
      @core.Rect::new(x=8.0, y=0.0, width=8.0, height=16.0),
    ),
  )
}

///|
test "skia render_frame empty damage falls back to full clear" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
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
        @core.DrawCommand::FillRect(
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
test "skia render_frame skips draw_cached_layer outside damage rects" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=16.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let spec = @core.CachedLayerSpec::new(
    key="skia-damage-skip",
    frame=@core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0),
    content_revision=1,
  )
  // Frame 1: establish cached layer at (2,2,4,4).
  let first = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::BeginCachedLayer(spec),
        @core.DrawCommand::FillRect(
          @core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0),
          @core.Color::black(),
        ),
        @core.DrawCommand::EndCachedLayer(spec.key),
      ],
      @core.DamageRegion::full("establish cached layer"),
    ),
  )
  inspect(first.presented, content="true")
  inspect(first.cache_update_count, content="1")
  inspect(first.cache_hit_count, content="0")
  inspect(first.cache_miss_count, content="0")
  // Frame 2: damage rect at (10,10,4,4) does not intersect the cached layer
  // at (2,2,4,4). DrawCachedLayer should be skipped without counting hit/miss.
  let second = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [@core.DrawCommand::DrawCachedLayer(spec)],
      @core.DamageRegion::Rects([
        @core.Rect::new(x=10.0, y=10.0, width=4.0, height=4.0),
      ]),
    ),
  )
  inspect(second.presented, content="true")
  inspect(second.cache_hit_count, content="0")
  inspect(second.cache_miss_count, content="0")
}

///|
test "skia render_frame falls back to full damage when scope commands present" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
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
        @core.DrawCommand::FillRect(
          @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
          @core.Color::black(),
        ),
      ],
      @core.DamageRegion::full("baseline black"),
    ),
  )
  // Frame 2: Rects damage but commands contain PushOpacity/PopOpacity.
  // resolve_effective_damage should fall back to FullSurface, clearing the
  // entire surface to white despite the small damage rect.
  let second = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [@core.DrawCommand::PushOpacity(1.0), @core.DrawCommand::PopOpacity],
      @core.DamageRegion::Rects([
        @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      ]),
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
