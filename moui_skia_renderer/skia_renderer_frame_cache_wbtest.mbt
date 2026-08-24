///|
test "skia renderer resize updates presented frame metrics" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=3.0, height=2.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.resize(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=6.0),
      scale_factor=2.0,
    ),
  ) catch {
    err => fail("expected Skia renderer resize: \{err.message()}")
  }
  renderer.render([@core.DrawCommand::Clear(@core.Color::white())]) catch {
    err => fail("expected Skia renderer render: \{err.message()}")
  }
  guard renderer.last_frame() is Some(frame) else {
    fail("expected Skia renderer to keep last frame after render")
  }
  inspect(frame.width, content="16")
  inspect(frame.height, content="12")
  inspect(frame.scale_factor, content="2")
  inspect(renderer.present_count(), content="1")
}

///|
test "skia renderer reports presenter failure without counting present" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="failing-presenter", present=_ => {
    false
  })
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  try renderer.render([@core.DrawCommand::Clear(@core.Color::white())]) catch {
    err =>
      match err {
        SkiaRendererError::PresentFailed(description) =>
          inspect(description, content="failing-presenter")
        _ => fail("expected Skia presenter failure")
      }
  } noraise {
    _ => fail("expected Skia presenter failure")
  }
  inspect(renderer.present_count(), content="0")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected failed presentation to keep rendered frame for diagnostics")
  }
  inspect(frame.width, content="4")
  inspect(frame.height, content="4")
}

///|
test "skia unmatched scope pops are ignored and counted" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopRoundedClip,
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::PopOpacity,
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::black(),
    ),
  ]) catch {
    err =>
      fail("expected Skia renderer to ignore unmatched pops: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="6")
  let diagnostics = renderer.unsupported_command_diagnostics()
  inspect(diagnostics.length(), content="6")
  inspect(diagnostics[0].command, content="PopClip")
  assert_true(diagnostics[0].reason.contains("no matching push"))
  inspect(diagnostics[5].command, content="PopFilter")
  inspect(renderer.present_count(), content="1")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  inspect(frame.width, content="8")
  inspect(frame.height, content="8")
}

///|
test "skia mismatched scope pop preserves the active scope" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=12.0, height=8.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=8.0),
    ),
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=12.0, height=8.0),
      @core.Color::black(),
    ),
    @core.DrawCommand::PopClip,
  ]) catch {
    err =>
      fail("expected Skia renderer to ignore mismatched pop: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="1")
  let diagnostics = renderer.unsupported_command_diagnostics()
  inspect(diagnostics.length(), content="1")
  inspect(diagnostics[0].command, content="PopTransform")
  assert_true(diagnostics[0].reason.contains("active clip scope"))
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      frame,
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=8.0),
    ),
  )
  assert_false(
    skia_test_region_has_dark_pixel(
      frame,
      @core.Rect::new(x=6.0, y=0.0, width=4.0, height=8.0),
    ),
  )
}

///|
test "skia unclosed scopes are counted and restored at frame boundary" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=12.0, height=8.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=8.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=12.0, height=8.0),
      @core.Color::black(),
    ),
  ]) catch {
    err =>
      fail("expected Skia renderer to restore unclosed clip: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="1")
  let diagnostics = renderer.unsupported_command_diagnostics()
  inspect(diagnostics.length(), content="1")
  inspect(diagnostics[0].command, content="PushClip")
  assert_true(diagnostics[0].reason.contains("open clip scope"))
  guard renderer.last_frame() is Some(clipped_frame) else {
    fail("expected clipped rendered frame")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      clipped_frame,
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=8.0),
    ),
  )
  assert_false(
    skia_test_region_has_dark_pixel(
      clipped_frame,
      @core.Rect::new(x=6.0, y=0.0, width=4.0, height=8.0),
    ),
  )

  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=12.0, height=8.0),
      @core.Color::black(),
    ),
  ]) catch {
    err =>
      fail("expected next Skia frame after unclosed clip: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  inspect(renderer.unsupported_command_diagnostics().length(), content="0")
  inspect(renderer.present_count(), content="2")
  guard renderer.last_frame() is Some(restored_frame) else {
    fail("expected restored rendered frame")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      restored_frame,
      @core.Rect::new(x=6.0, y=0.0, width=4.0, height=8.0),
    ),
  )
}

///|
test "skia unsupported command diagnostics reset per frame" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="missing-shader",
        frame=@core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
        fallback=@core.Brush::solid(@core.Color::blue()),
      ),
    ),
  ]) catch {
    err => fail("expected Skia fallback render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="1")
  let diagnostics = renderer.unsupported_command_diagnostics()
  inspect(diagnostics.length(), content="1")
  inspect(diagnostics[0].command, content="DrawShaderEffect")
  assert_true(diagnostics[0].reason.contains("missing-shader"))
  assert_true(diagnostics[0].reason.contains("fallback brush"))
  inspect(renderer.present_count(), content="1")
  renderer.render([@core.DrawCommand::Clear(@core.Color::white())]) catch {
    err => fail("expected Skia supported render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  inspect(renderer.unsupported_command_diagnostics().length(), content="0")
  inspect(renderer.present_count(), content="2")
}

///|
test "skia color matrix normalizes short and long payloads" {
  let identity = skia_color_filter_matrix_values([])
  inspect(identity.length(), content="20")
  inspect(identity[0], content="1")
  inspect(identity[6], content="1")
  inspect(identity[12], content="1")
  inspect(identity[18], content="1")
  inspect(identity[1], content="0")
  inspect(identity[19], content="0")

  let short = skia_color_filter_matrix_values([0.25, 0.5])
  inspect(short.length(), content="20")
  inspect(short[0], content="0.25")
  inspect(short[1], content="0.5")
  inspect(short[6], content="1")
  inspect(short[12], content="1")
  inspect(short[18], content="1")

  let long = skia_color_filter_matrix_values([
    0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0,
    15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0,
  ])
  inspect(long.length(), content="20")
  inspect(long[0], content="0")
  inspect(long[18], content="18")
  inspect(long[19], content="19")
}

///|
test "skia renderer composites masked opacity layer pixels" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=24.0, height=24.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(
        opacity=0.5,
        mask=@core.LayerMask::RectMask(
          @core.Rect::new(x=4.0, y=4.0, width=12.0, height=12.0),
        ),
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=24.0, height=24.0),
      @core.Color::black(),
    ),
    @core.DrawCommand::PopLayer,
  ]) catch {
    err => fail("expected Skia masked layer render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  inspect(renderer.present_count(), content="1")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=8.0, y=8.0, width=4.0, height=4.0),
      (r, g, b, a) => {
        a > 0 && r > 80 && r < 220 && g > 80 && g < 220 && b > 80 && b < 220
      },
    ),
  )
  assert_false(
    skia_test_region_has_dark_pixel(
      frame,
      @core.Rect::new(x=0.0, y=0.0, width=3.0, height=3.0),
    ),
  )
}

///|
test "skia render_frame updates and reuses renderer-local cached layers" {
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
    key="skia-layer-a",
    frame=@core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
    content_revision=1,
  )
  let first = renderer.render_frame(
    skia_test_draw_frame([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::BeginRetainedLayer(spec),
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=4.0, y=4.0, width=4.0, height=4.0),
        @core.Color::black(),
      ),
      @core.DrawCommand::EndRetainedLayer(spec.key),
    ]),
  )
  inspect(first.presented, content="true")
  inspect(first.cache_update_count, content="1")
  inspect(first.cache_hit_count, content="0")
  inspect(first.cache_miss_count, content="1")
  inspect(renderer.unsupported_command_count(), content="0")
  guard renderer.last_frame() is Some(first_frame) else {
    fail("expected first cached-layer frame")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      first_frame,
      @core.Rect::new(x=4.0, y=4.0, width=4.0, height=4.0),
    ),
  )
  let second = renderer.render_frame(
    skia_test_draw_frame([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::BeginRetainedLayer(spec),
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=4.0, y=4.0, width=4.0, height=4.0),
        @core.Color::black(),
      ),
      @core.DrawCommand::EndRetainedLayer(spec.key),
    ]),
  )
  inspect(second.presented, content="true")
  inspect(second.cache_hit_count, content="1")
  inspect(second.cache_update_count, content="0")
  inspect(second.cache_miss_count, content="0")
  inspect(renderer.present_count(), content="2")
  guard renderer.last_frame() is Some(second_frame) else {
    fail("expected second cached-layer frame")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      second_frame,
      @core.Rect::new(x=4.0, y=4.0, width=4.0, height=4.0),
    ),
  )
}

///|
test "skia render_frame reuses cached layer when only origin changes" {
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
  let initial = @core.RetainedLayerSpec::new(
    key="moving-layer",
    frame=@core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
    content_revision=1,
  )
  let moved = @core.RetainedLayerSpec::new(
    key="moving-layer",
    frame=@core.Rect::new(x=2.0, y=6.0, width=8.0, height=8.0),
    content_revision=1,
  )
  let first = renderer.render_frame(
    skia_test_draw_frame([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::BeginRetainedLayer(initial),
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=4.0, y=4.0, width=4.0, height=4.0),
        @core.Color::black(),
      ),
      @core.DrawCommand::EndRetainedLayer(initial.key),
    ]),
  )
  inspect(first.presented, content="true")
  inspect(first.cache_update_count, content="1")
  let second = renderer.render_frame(
    skia_test_draw_frame([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::BeginRetainedLayer(moved),
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=4.0, y=8.0, width=4.0, height=4.0),
        @core.Color::black(),
      ),
      @core.DrawCommand::EndRetainedLayer(moved.key),
    ]),
  )
  inspect(second.presented, content="true")
  inspect(second.cache_hit_count, content="1")
  inspect(second.cache_miss_count, content="0")
  inspect(second.cache_update_count, content="0")
  guard renderer.last_frame() is Some(second_frame) else {
    fail("expected moved cached-layer frame")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      second_frame,
      @core.Rect::new(x=4.0, y=8.0, width=4.0, height=4.0),
    ),
  )
  assert_false(
    skia_test_region_has_dark_pixel(
      second_frame,
      @core.Rect::new(x=4.0, y=4.0, width=4.0, height=4.0),
    ),
  )
}

///|
test "skia render_frame snapshots nested cached layers into parent cache" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=20.0, height=20.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let outer = @core.RetainedLayerSpec::new(
    key="outer-layer",
    frame=@core.Rect::new(x=2.0, y=2.0, width=14.0, height=14.0),
    content_revision=1,
  )
  let inner = @core.RetainedLayerSpec::new(
    key="inner-layer",
    frame=@core.Rect::new(x=6.0, y=6.0, width=6.0, height=6.0),
    content_revision=1,
  )
  let first = renderer.render_frame(
    skia_test_draw_frame([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::BeginRetainedLayer(outer),
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=2.0, y=2.0, width=14.0, height=14.0),
        @core.Color::gray(),
      ),
      @core.DrawCommand::BeginRetainedLayer(inner),
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=6.0, y=6.0, width=6.0, height=6.0),
        @core.Color::black(),
      ),
      @core.DrawCommand::EndRetainedLayer(inner.key),
      @core.DrawCommand::EndRetainedLayer(outer.key),
    ]),
  )
  inspect(first.presented, content="true")
  inspect(first.cache_update_count, content="2")
  guard renderer.last_frame() is Some(first_frame) else {
    fail("expected nested cached-layer frame")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      first_frame,
      @core.Rect::new(x=7.0, y=7.0, width=4.0, height=4.0),
    ),
  )
  let second = renderer.render_frame(
    skia_test_draw_frame([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::BeginRetainedLayer(outer),
      @core.DrawCommand::FillRect(outer.frame, @core.Color::gray()),
      @core.DrawCommand::BeginRetainedLayer(inner),
      @core.DrawCommand::FillRect(inner.frame, @core.Color::black()),
      @core.DrawCommand::EndRetainedLayer(inner.key),
      @core.DrawCommand::EndRetainedLayer(outer.key),
    ]),
  )
  inspect(second.presented, content="true")
  inspect(second.cache_hit_count, content="1")
  inspect(second.cache_miss_count, content="0")
  guard renderer.last_frame() is Some(second_frame) else {
    fail("expected nested cached-layer hit frame")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      second_frame,
      @core.Rect::new(x=7.0, y=7.0, width=4.0, height=4.0),
    ),
  )
}

///|
test "skia picture producer caches nested layers as pictures without surfaces" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=20.0, height=20.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let outer = @core.RetainedLayerSpec::new(
    key="picture-outer",
    frame=@core.Rect::new(x=2.0, y=2.0, width=14.0, height=14.0),
    content_revision=1,
  )
  let inner = @core.RetainedLayerSpec::new(
    key="picture-inner",
    frame=@core.Rect::new(x=6.0, y=6.0, width=6.0, height=6.0),
    content_revision=1,
  )
  let first = renderer.record_frame_picture(
    skia_test_draw_frame([
      @core.DrawCommand::BeginRetainedLayer(outer),
      @core.DrawCommand::FillRect(outer.frame, @core.Color::gray()),
      @core.DrawCommand::BeginRetainedLayer(inner),
      @core.DrawCommand::FillRect(inner.frame, @core.Color::black()),
      @core.DrawCommand::EndRetainedLayer(inner.key),
      @core.DrawCommand::EndRetainedLayer(outer.key),
    ]),
  )
  assert_true(first is Some(_))
  inspect(renderer.picture_layer_cache.length(), content="2")
  inspect(renderer.layer_cache.length(), content="0")
  let second = renderer.record_frame_picture(
    skia_test_draw_frame([
      @core.DrawCommand::BeginRetainedLayer(outer),
      @core.DrawCommand::FillRect(outer.frame, @core.Color::gray()),
      @core.DrawCommand::BeginRetainedLayer(inner),
      @core.DrawCommand::FillRect(inner.frame, @core.Color::black()),
      @core.DrawCommand::EndRetainedLayer(inner.key),
      @core.DrawCommand::EndRetainedLayer(outer.key),
    ]),
  )
  assert_true(second is Some(_))
  inspect(renderer.picture_layer_cache.length(), content="2")
  inspect(renderer.layer_cache.length(), content="0")
  guard renderer.picture_layer_cache.get(
      renderer.skia_layer_cache_key(
        outer,
        skia_cached_layer_physical_size(
          outer.frame,
          renderer.metrics.scale_factor,
        ),
      ),
    )
    is Some(entry) else {
    fail("expected outer picture cache entry")
  }
  assert_true(entry.hit_count >= 1)
  renderer.dispose()
}

///|
test "skia raster fallback replays cached layers recorded by GPU producer" {
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
    key="gpu-picture-to-raster",
    frame=@core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
    content_revision=1,
  )
  let recorded = renderer.record_frame_picture(
    skia_test_draw_frame([
      @core.DrawCommand::BeginRetainedLayer(spec),
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=4.0, y=4.0, width=4.0, height=4.0),
        @core.Color::black(),
      ),
      @core.DrawCommand::EndRetainedLayer(spec.key),
    ]),
  )
  assert_true(recorded is Some(_))
  inspect(renderer.picture_layer_cache.length(), content="1")
  inspect(renderer.layer_cache.length(), content="0")
  let fallback = renderer.render_frame(
    skia_test_draw_frame([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::BeginRetainedLayer(spec),
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=4.0, y=4.0, width=4.0, height=4.0),
        @core.Color::black(),
      ),
      @core.DrawCommand::EndRetainedLayer(spec.key),
    ]),
  )
  inspect(fallback.presented, content="true")
  inspect(fallback.cache_hit_count, content="1")
  inspect(fallback.cache_miss_count, content="0")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected raster fallback frame")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      frame,
      @core.Rect::new(x=4.0, y=4.0, width=4.0, height=4.0),
    ),
  )
  renderer.dispose()
}

///|
test "skia render_frame cache miss rebuilds from the current frame" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let baseline = renderer.render_frame(
    skia_test_draw_frame([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=1.0, y=1.0, width=2.0, height=2.0),
        @core.Color::black(),
      ),
    ]),
  )
  inspect(baseline.presented, content="true")
  guard renderer.last_frame() is Some(before_miss) else {
    fail("expected baseline frame")
  }
  let missing = @core.RetainedLayerSpec::new(
    key="missing-layer",
    frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
    content_revision=1,
  )
  let miss = renderer.render_frame(
    skia_test_draw_frame([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::BeginRetainedLayer(missing),
      @core.DrawCommand::FillRect(missing.frame, @core.Color::blue()),
      @core.DrawCommand::EndRetainedLayer(missing.key),
    ]),
  )
  inspect(miss.presented, content="true")
  inspect(miss.cache_miss_count, content="1")
  inspect(miss.cache_update_count, content="1")
  inspect(renderer.present_count(), content="2")
  assert_true(renderer.last_frame() != Some(before_miss))
}

///|
test "skia render_frame resize clears renderer-local cached layers" {
  guard skia_available() else { return () }
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=12.0, height=12.0),
  )
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(metrics, target) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let spec = @core.RetainedLayerSpec::new(
    key="resize-layer",
    frame=@core.Rect::new(x=2.0, y=2.0, width=6.0, height=6.0),
    content_revision=1,
  )
  let update = renderer.render_frame(
    skia_test_draw_frame([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::BeginRetainedLayer(spec),
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=2.0, y=2.0, width=6.0, height=6.0),
        @core.Color::black(),
      ),
      @core.DrawCommand::EndRetainedLayer(spec.key),
    ]),
  )
  inspect(update.cache_update_count, content="1")
  // Resize to a substantially larger surface to verify cache invalidation.
  // Small incremental resizes during live drag preserve the cache for
  // performance, so use a large delta that exceeds the live-resize threshold.
  let large = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=100.0, height=100.0),
  )
  renderer.resize(large) catch {
    err => fail("expected Skia renderer resize: \{err.message()}")
  }
  let miss = renderer.render_frame(
    skia_test_draw_frame([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::BeginRetainedLayer(spec),
      @core.DrawCommand::FillRect(spec.frame, @core.Color::black()),
      @core.DrawCommand::EndRetainedLayer(spec.key),
    ]),
  )
  inspect(miss.presented, content="true")
  inspect(miss.cache_miss_count, content="1")
  inspect(miss.cache_update_count, content="1")
}

///|
test "skia render_frame treats empty cached layer draws as no-op" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let spec = @core.RetainedLayerSpec::new(
    key="empty-layer",
    frame=@core.Rect::new(x=2.0, y=2.0, width=0.0, height=4.0),
    content_revision=1,
  )
  let result = renderer.render_frame(
    skia_test_draw_frame([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::BeginRetainedLayer(spec),
      @core.DrawCommand::EndRetainedLayer(spec.key),
    ]),
  )
  inspect(result.presented, content="true")
  inspect(result.cache_miss_count, content="0")
  inspect(result.cache_hit_count, content="0")
}

///|
test "skia render_frame evicts cached layers by surface budget" {
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
  let commands : Array[@core.DrawCommand] = [
    @core.DrawCommand::Clear(@core.Color::white()),
  ]
  for index in 0..<4 {
    let spec = @core.RetainedLayerSpec::new(
      key="evict-layer-\{index}",
      frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      content_revision=1,
    )
    commands.push(@core.DrawCommand::BeginRetainedLayer(spec))
    commands.push(
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
        @core.Color::black(),
      ),
    )
    commands.push(@core.DrawCommand::EndRetainedLayer(spec.key))
  }
  let result = renderer.render_frame(skia_test_draw_frame(commands))
  inspect(result.presented, content="true")
  inspect(result.cache_update_count, content="4")
  inspect(result.cache_evict_count, content="1")
}

///|
test "skia cached layer admission records stay bounded" {
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
  for index in 0..<(skia_layer_cache_admission_limit() + 48) {
    let record = renderer.layer_cache_admission_record(
      "admission-layer-\{index}",
    )
    record.last_admitted_frame = index + 1
  }
  inspect(
    renderer.layer_cache_admissions.length(),
    content=skia_layer_cache_admission_limit().to_string(),
  )
}

///|
test "skia render_frame skips churny cached layer admission" {
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
  for revision in 1..<=3 {
    let spec = @core.RetainedLayerSpec::new(
      key="churn-layer",
      frame=@core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
      content_revision=revision,
    )
    let result = renderer.render_frame(
      skia_test_draw_frame([
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::BeginRetainedLayer(spec),
        @core.DrawCommand::FillRect(
          @core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
          @core.Color::black(),
        ),
        @core.DrawCommand::EndRetainedLayer(spec.key),
      ]),
    )
    inspect(result.presented, content="true")
    if revision < 3 {
      inspect(result.cache_update_count, content="1")
      inspect(renderer.layer_cache.length(), content="1")
    } else {
      inspect(result.cache_update_count, content="0")
      inspect(renderer.layer_cache.length(), content="0")
      let mut churn_skip_reason = ""
      for _, record in renderer.layer_cache_admissions {
        churn_skip_reason = record.skip_reason
      }
      inspect(churn_skip_reason, content="churn-without-hit")
    }
  }
  inspect(renderer.unsupported_command_count(), content="0")
}

///|
test "skia render_frame keeps hot cached layer admitted across revisions" {
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
  let first_spec = @core.RetainedLayerSpec::new(
    key="hot-layer",
    frame=@core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
    content_revision=1,
  )
  ignore(
    renderer.render_frame(
      skia_test_draw_frame([
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::BeginRetainedLayer(first_spec),
        @core.DrawCommand::FillRect(
          @core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
          @core.Color::black(),
        ),
        @core.DrawCommand::EndRetainedLayer(first_spec.key),
      ]),
    ),
  )
  let hit = renderer.render_frame(
    skia_test_draw_frame([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::BeginRetainedLayer(first_spec),
      @core.DrawCommand::FillRect(first_spec.frame, @core.Color::black()),
      @core.DrawCommand::EndRetainedLayer(first_spec.key),
    ]),
  )
  inspect(hit.cache_hit_count, content="1")
  for revision in 2..<=4 {
    let spec = @core.RetainedLayerSpec::new(
      key="hot-layer",
      frame=@core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
      content_revision=revision,
    )
    let update = renderer.render_frame(
      skia_test_draw_frame([
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::BeginRetainedLayer(spec),
        @core.DrawCommand::FillRect(
          @core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
          @core.Color::black(),
        ),
        @core.DrawCommand::EndRetainedLayer(spec.key),
      ]),
    )
    inspect(update.cache_update_count, content="1")
  }
  inspect(renderer.layer_cache.length(), content="1")
  let mut hot_hit_count = 0
  for _, record in renderer.layer_cache_admissions {
    hot_hit_count = record.hit_count
  }
  inspect(hot_hit_count, content="1")
}
