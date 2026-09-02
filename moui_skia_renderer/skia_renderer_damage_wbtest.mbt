///|
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
        @core.DrawCommand::FillRect(
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
test "skia render_frame rects damage clears only dirty rects" {
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
test "skia render_frame skips retained layer outside damage rects" {
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
    key="skia-damage-skip",
    frame=@core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0),
    content_revision=1,
  )
  // Frame 1: establish cached layer at (2,2,4,4).
  let first = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::BeginRetainedLayer(spec),
        @core.DrawCommand::FillRect(
          @core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0),
          @core.Color::black(),
        ),
        @core.DrawCommand::EndRetainedLayer(spec.key),
      ],
      @core.DamageRegion::full("establish cached layer"),
    ),
  )
  inspect(first.presented, content="true")
  inspect(first.cache_update_count, content="1")
  inspect(first.cache_hit_count, content="0")
  inspect(first.cache_miss_count, content="1")
  // Frame 2 includes a complete declaration and a full-surface Clear. Damage
  // at (10,10,4,4) does not intersect the retained layer at
  // (2,2,4,4), so the damage clip must keep the skipped layer visible.
  let second = renderer.render_frame(
    skia_test_draw_frame_with_damage(
      [
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::BeginRetainedLayer(spec),
        @core.DrawCommand::FillRect(spec.frame, @core.Color::black()),
        @core.DrawCommand::EndRetainedLayer(spec.key),
      ],
      @core.DamageRegion::Rects([
        @core.Rect::new(x=10.0, y=10.0, width=4.0, height=4.0),
      ]),
    ),
  )
  inspect(second.presented, content="true")
  inspect(second.cache_hit_count, content="0")
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
test "skia rect damage uses logical coordinates on hidpi surfaces" {
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
          @core.DrawCommand::FillRect(
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
      @core.DamageRegion::Rects([
        @core.Rect::new(x=0.0, y=0.0, width=8.0, height=16.0),
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
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=32.0),
    ),
  )
  assert_true(
    skia_test_region_has_dark_pixel(
      second_frame,
      @core.Rect::new(x=16.0, y=0.0, width=16.0, height=32.0),
    ),
  )
}

///|
test "skia effective damage policy preserves safe Metal rects" {
  let dirty = @core.Rect::new(x=2.0, y=3.0, width=4.0, height=5.0)
  let resolved = skia_effective_damage_policy(
    @core.DamageRegion::Rects([dirty]),
    [@core.DrawCommand::FillRect(dirty, @core.Color::black())],
    gpu_target=true,
    metal_backing_ready=true,
    image_generation_changed=false,
  )
  match resolved {
    @core.DamageRegion::Rects([rect]) => assert_true(rect == dirty)
    _ => fail("expected safe Metal backing to preserve rect damage")
  }
}

///|
test "skia effective damage policy keeps host GPU safety fallbacks" {
  let dirty = @core.Rect::new(x=2.0, y=3.0, width=4.0, height=5.0)
  let commands = [@core.DrawCommand::FillRect(dirty, @core.Color::black())]
  match
    skia_effective_damage_policy(
      @core.DamageRegion::Rects([dirty]),
      commands,
      gpu_target=true,
      metal_backing_ready=false,
      image_generation_changed=false,
    ) {
    @core.DamageRegion::FullSurface(reason) =>
      assert_eq(reason, "host-gpu drawable has no preserved backbuffer")
    _ => fail("expected a fresh host drawable to force full damage")
  }
  match
    skia_effective_damage_policy(
      @core.DamageRegion::Rects([dirty]),
      commands,
      gpu_target=true,
      metal_backing_ready=true,
      image_generation_changed=true,
    ) {
    @core.DamageRegion::FullSurface(reason) =>
      assert_eq(reason, "image resource completed")
    _ => fail("expected image completion to force full damage")
  }
  match
    skia_effective_damage_policy(
      @core.DamageRegion::Rects([dirty]),
      [@core.DrawCommand::PushOpacity(0.5), @core.DrawCommand::PopOpacity],
      gpu_target=true,
      metal_backing_ready=true,
      image_generation_changed=false,
    ) {
    @core.DamageRegion::FullSurface(reason) =>
      assert_eq(reason, "scope commands present with damage rects")
    _ => fail("expected scope commands to force full damage")
  }
  match
    skia_effective_damage_policy(
      @core.DamageRegion::Empty,
      [],
      gpu_target=false,
      metal_backing_ready=false,
      image_generation_changed=false,
    ) {
    @core.DamageRegion::FullSurface(reason) =>
      assert_eq(reason, "empty damage fallback")
    _ => fail("expected empty damage to force a full raster fallback")
  }
}

///|
test "skia render_frame falls back to full damage when scope commands present" {
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
