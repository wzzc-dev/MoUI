///|
test "sun renderer DrawCachedLayer respects surrounding opacity" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  )
  let spec = @core.CachedLayerSpec::new(
    key="opacity-layer",
    frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
    content_revision=1,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::BeginCachedLayer(spec),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::EndCachedLayer(spec.key),
  ])
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushOpacity(0.5),
    @core.DrawCommand::DrawCachedLayer(spec),
    @core.DrawCommand::PopOpacity,
  ])
  inspect(renderer.cached_layer_miss_count(), content="1")
  inspect(renderer.cached_layer_hit_count(), content="1")
  inspect(renderer.unsupported_command_count(), content="0")
  match presented.val {
    Some(frame) => {
      let idx = (2 * frame.width() + 2) * 4
      assert_true(frame.pixels()[idx].to_int() > 240)
      assert_true(frame.pixels()[idx + 1].to_int() > 100)
      assert_true(frame.pixels()[idx + 1].to_int() < 200)
      assert_true(frame.pixels()[idx + 2].to_int() > 100)
      assert_true(frame.pixels()[idx + 2].to_int() < 200)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer cached layer restores filter blur stack after open child scope" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=12.0, height=8.0),
    ),
    target,
  )
  let spec = @core.CachedLayerSpec::new(
    key="open-child-filter-layer",
    frame=@core.Rect::new(x=0.0, y=0.0, width=2.0, height=2.0),
    content_revision=1,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Blur(0.0)),
    @core.DrawCommand::BeginCachedLayer(spec),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Blur(3.0)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=2.0, height=2.0),
      @core.Color::black(),
    ),
    @core.DrawCommand::EndCachedLayer(spec.key),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=8.0),
      @core.Color::black(),
    ),
    @core.DrawCommand::PopFilter,
  ])
  inspect(renderer.unsupported_command_count(), content="1")
  guard renderer.last_frame() is Some(frame) else { fail("expected Sun frame") }
  let edge_idx = (4 * frame.width() + 4) * 4
  assert_true(frame.pixels()[edge_idx].to_int() > 240)
  assert_true(frame.pixels()[edge_idx + 1].to_int() > 240)
  assert_true(frame.pixels()[edge_idx + 2].to_int() > 240)
}

///|
test "sun renderer cached layer refreshes when physical size changes" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=6.0, height=6.0),
    ),
    target,
  )
  let small = @core.CachedLayerSpec::new(
    key="resized-layer",
    frame=@core.Rect::new(x=0.0, y=0.0, width=2.0, height=2.0),
    content_revision=1,
  )
  let large = @core.CachedLayerSpec::new(
    key="resized-layer",
    frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
    content_revision=1,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::BeginCachedLayer(small),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=2.0, height=2.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::EndCachedLayer(small.key),
  ])
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::BeginCachedLayer(large),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::EndCachedLayer(large.key),
  ])
  inspect(renderer.cached_layer_miss_count(), content="2")
  inspect(renderer.cached_layer_hit_count(), content="0")
  inspect(renderer.unsupported_command_count(), content="0")
  match presented.val {
    Some(frame) => {
      let idx = (3 * frame.width() + 3) * 4
      assert_true(frame.pixels()[idx + 2].to_int() > 200)
      assert_true(frame.pixels()[idx].to_int() < 80)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer cached layer reuses same-size moved frame" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    target,
  )
  let initial = @core.CachedLayerSpec::new(
    key="moving-sun-layer",
    frame=@core.Rect::new(x=1.0, y=1.0, width=3.0, height=3.0),
    content_revision=1,
  )
  let moved = @core.CachedLayerSpec::new(
    key="moving-sun-layer",
    frame=@core.Rect::new(x=4.0, y=4.0, width=3.0, height=3.0),
    content_revision=1,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::BeginCachedLayer(initial),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=1.0, y=1.0, width=3.0, height=3.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::EndCachedLayer(initial.key),
  ])
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawCachedLayer(moved),
  ])
  inspect(renderer.cached_layer_miss_count(), content="1")
  inspect(renderer.cached_layer_hit_count(), content="1")
  inspect(renderer.unsupported_command_count(), content="0")
  match presented.val {
    Some(frame) => {
      let moved_idx = (5 * frame.width() + 5) * 4
      let old_idx = (2 * frame.width() + 2) * 4
      assert_true(frame.pixels()[moved_idx].to_int() > 200)
      assert_true(frame.pixels()[old_idx].to_int() > 240)
      assert_true(frame.pixels()[old_idx + 1].to_int() > 240)
      assert_true(frame.pixels()[old_idx + 2].to_int() > 240)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer repeated same-key refresh records churn without retaining latest cache entry" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  )
  for revision in 0..<40 {
    let spec = @core.CachedLayerSpec::new(
      key="refresh-layer",
      frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      content_revision=revision,
    )
    renderer.render([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::BeginCachedLayer(spec),
      @core.DrawCommand::FillRect(
        @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
        @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
      ),
      @core.DrawCommand::EndCachedLayer(spec.key),
    ])
  }
  inspect(renderer.cached_layer_miss_count(), content="2")
  let diagnostic = renderer.cached_layer_diagnostic()
  inspect(diagnostic.cached_layer_count(), content="0")
  inspect(diagnostic.total_update_count(), content="2")
  inspect(diagnostic.churn_without_hit_count(), content="1")
  inspect(
    diagnostic.admission_records()[0].skip_reason(),
    content="churn-without-hit",
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawCachedLayer(
      @core.CachedLayerSpec::new(
        key="refresh-layer",
        frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
        content_revision=39,
      ),
    ),
  ])
  inspect(renderer.cached_layer_hit_count(), content="0")
  inspect(renderer.unsupported_command_count(), content="1")
}

///|
test "sun renderer skips churny cached layer admission" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=16.0),
    ),
    target,
  )
  for revision in 1..<=3 {
    let spec = @core.CachedLayerSpec::new(
      key="churn-admission-layer",
      frame=@core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
      content_revision=revision,
    )
    let result = renderer.render_frame(
      @core.DrawFrame::new(
        commands=[
          @core.DrawCommand::Clear(@core.Color::white()),
          @core.DrawCommand::BeginCachedLayer(spec),
          @core.DrawCommand::FillRect(
            @core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
            @core.Color::black(),
          ),
          @core.DrawCommand::EndCachedLayer(spec.key),
        ],
        damage=@core.DamageRegion::full("sun churn admission policy"),
      ),
    )
    inspect(result.presented, content="true")
    if revision < 3 {
      inspect(result.cache_update_count, content="1")
      inspect(
        renderer.cached_layer_diagnostic().cached_layer_count(),
        content="1",
      )
    } else {
      inspect(result.cache_update_count, content="0")
      inspect(
        renderer.cached_layer_diagnostic().cached_layer_count(),
        content="0",
      )
      inspect(
        renderer.cached_layer_diagnostic().admission_records()[0].skip_reason(),
        content="churn-without-hit",
      )
    }
  }
  inspect(renderer.unsupported_command_count(), content="0")
}

///|
test "sun renderer keeps hot cached layer admitted across revisions" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=16.0),
    ),
    target,
  )
  let first = @core.CachedLayerSpec::new(
    key="hot-admission-layer",
    frame=@core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
    content_revision=1,
  )
  ignore(
    renderer.render_frame(
      @core.DrawFrame::new(
        commands=[
          @core.DrawCommand::Clear(@core.Color::white()),
          @core.DrawCommand::BeginCachedLayer(first),
          @core.DrawCommand::FillRect(
            @core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
            @core.Color::black(),
          ),
          @core.DrawCommand::EndCachedLayer(first.key),
        ],
        damage=@core.DamageRegion::full("sun hot admission first"),
      ),
    ),
  )
  let hit = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::DrawCachedLayer(first),
      ],
      damage=@core.DamageRegion::empty(),
    ),
  )
  inspect(hit.cache_hit_count, content="1")
  for revision in 2..<=4 {
    let spec = @core.CachedLayerSpec::new(
      key="hot-admission-layer",
      frame=@core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
      content_revision=revision,
    )
    let update = renderer.render_frame(
      @core.DrawFrame::new(
        commands=[
          @core.DrawCommand::Clear(@core.Color::white()),
          @core.DrawCommand::BeginCachedLayer(spec),
          @core.DrawCommand::FillRect(
            @core.Rect::new(x=2.0, y=2.0, width=8.0, height=8.0),
            @core.Color::black(),
          ),
          @core.DrawCommand::EndCachedLayer(spec.key),
        ],
        damage=@core.DamageRegion::full("sun hot admission update"),
      ),
    )
    inspect(update.cache_update_count, content="1")
  }
  let diagnostic = renderer.cached_layer_diagnostic()
  inspect(diagnostic.cached_layer_count(), content="1")
  inspect(diagnostic.admission_records()[0].hit_count(), content="1")
  inspect(diagnostic.admission_records()[0].skip_reason(), content="")
}

///|
test "sun renderer resize clears cached layers" {
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=8.0, height=8.0),
  )
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(metrics, target)
  let spec = @core.CachedLayerSpec::new(
    key="resize-layer",
    frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
    content_revision=1,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::BeginCachedLayer(spec),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::black(),
    ),
    @core.DrawCommand::EndCachedLayer(spec.key),
  ])
  inspect(renderer.cached_layer_miss_count(), content="1")
  renderer.resize(metrics)
  inspect(renderer.cached_layer_miss_count(), content="0")
  inspect(renderer.cached_layer_hit_count(), content="0")
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawCachedLayer(spec),
  ])
  inspect(renderer.cached_layer_hit_count(), content="0")
  inspect(renderer.unsupported_command_count(), content="1")
}

///|
test "sun renderer render_frame reports cached layer update and hit" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  )
  let spec = @core.CachedLayerSpec::new(
    key="frame-layer",
    frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
    content_revision=1,
  )
  let update = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::BeginCachedLayer(spec),
        @core.DrawCommand::FillRect(
          @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
          @core.Color::blue(),
        ),
        @core.DrawCommand::EndCachedLayer(spec.key),
      ],
      damage=@core.DamageRegion::full("sun render frame update"),
    ),
  )
  inspect(update.presented, content="true")
  inspect(update.cache_update_count, content="1")
  inspect(update.cache_hit_count, content="0")
  let hit = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::DrawCachedLayer(spec),
      ],
      damage=@core.DamageRegion::empty(),
    ),
  )
  inspect(hit.presented, content="true")
  inspect(hit.cache_update_count, content="0")
  inspect(hit.cache_hit_count, content="1")
  inspect(hit.cache_miss_count, content="0")
  inspect(renderer.present_count(), content="2")
}

///|
test "sun renderer cached layer diagnostic summary reports live entries and counters" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  )
  let spec = @core.CachedLayerSpec::new(
    key="diagnostic-layer",
    frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
    content_revision=1,
  )
  ignore(
    renderer.render_frame(
      @core.DrawFrame::new(
        commands=[
          @core.DrawCommand::Clear(@core.Color::white()),
          @core.DrawCommand::BeginCachedLayer(spec),
          @core.DrawCommand::FillRect(
            @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
            @core.Color::blue(),
          ),
          @core.DrawCommand::EndCachedLayer(spec.key),
        ],
        damage=@core.DamageRegion::full("sun cache diagnostic update"),
      ),
    ),
  )
  ignore(
    renderer.render_frame(
      @core.DrawFrame::new(
        commands=[
          @core.DrawCommand::Clear(@core.Color::white()),
          @core.DrawCommand::DrawCachedLayer(spec),
        ],
        damage=@core.DamageRegion::empty(),
      ),
    ),
  )
  let diagnostic = renderer.cached_layer_diagnostic()
  inspect(diagnostic.cached_layer_count(), content="1")
  inspect(diagnostic.max_cached_layer_count(), content="32")
  inspect(diagnostic.total_hit_count(), content="1")
  inspect(diagnostic.total_miss_count(), content="1")
  inspect(diagnostic.cached_layer_keys().length(), content="1")
  assert_true(diagnostic.cached_layer_keys()[0].contains("diagnostic-layer"))
  assert_true(diagnostic.cache_ready())
  assert_true(diagnostic.summary().contains("Sun cached-layer audit ready"))
  assert_true(diagnostic.summary().contains("entries=1/32"))
  assert_true(diagnostic.summary().contains("hits=1 misses=1"))
}

///|
test "sun cached layer diagnostic reports update evict and churn records" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  )
  for revision in 1..<=3 {
    let spec = @core.CachedLayerSpec::new(
      key="churn-diagnostic-layer",
      frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      content_revision=revision,
    )
    ignore(
      renderer.render_frame(
        @core.DrawFrame::new(
          commands=[
            @core.DrawCommand::Clear(@core.Color::white()),
            @core.DrawCommand::BeginCachedLayer(spec),
            @core.DrawCommand::FillRect(
              @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
              @core.Color::blue(),
            ),
            @core.DrawCommand::EndCachedLayer(spec.key),
          ],
          damage=@core.DamageRegion::full("sun cache churn diagnostic"),
        ),
      ),
    )
  }
  let diagnostic = renderer.cached_layer_diagnostic()
  inspect(diagnostic.cached_layer_count(), content="0")
  inspect(diagnostic.total_update_count(), content="2")
  inspect(diagnostic.total_evict_count(), content="0")
  inspect(diagnostic.admission_record_count(), content="1")
  inspect(diagnostic.churn_without_hit_count(), content="1")
  inspect(diagnostic.admission_records().length(), content="1")
  assert_true(
    diagnostic.admission_records()[0]
    .identity_key()
    .contains("churn-diagnostic-layer"),
  )
  inspect(diagnostic.admission_records()[0].update_streak(), content="3")
  inspect(diagnostic.admission_records()[0].hit_count(), content="0")
  inspect(
    diagnostic.admission_records()[0].skip_reason(),
    content="churn-without-hit",
  )
  assert_true(diagnostic.admission_records()[0].churn_without_hit())
  assert_true(diagnostic.summary().contains("updates=2 evicts=0"))
  assert_true(diagnostic.summary().contains("churn_without_hit=1"))
}

///|
test "sun cached layer diagnostic accumulates FIFO evictions" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  )
  for index in 0..<33 {
    let spec = @core.CachedLayerSpec::new(
      key="evict-diagnostic-layer-\{index}",
      frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      content_revision=1,
    )
    let result = renderer.render_frame(
      @core.DrawFrame::new(
        commands=[
          @core.DrawCommand::Clear(@core.Color::white()),
          @core.DrawCommand::BeginCachedLayer(spec),
          @core.DrawCommand::FillRect(
            @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
            @core.Color::blue(),
          ),
          @core.DrawCommand::EndCachedLayer(spec.key),
        ],
        damage=@core.DamageRegion::full("sun cache eviction diagnostic"),
      ),
    )
    if index == 32 {
      inspect(result.cache_evict_count, content="1")
    }
  }
  let diagnostic = renderer.cached_layer_diagnostic()
  inspect(diagnostic.cached_layer_count(), content="32")
  inspect(diagnostic.total_update_count(), content="33")
  inspect(diagnostic.total_evict_count(), content="1")
  inspect(diagnostic.admission_record_count(), content="33")
}

///|
test "sun renderer render_frame reports missing cached layer without presenting" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  )
  let baseline = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::FillRect(
          @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
          @core.Color::blue(),
        ),
      ],
      damage=@core.DamageRegion::full("sun render frame baseline"),
    ),
  )
  inspect(baseline.presented, content="true")
  guard renderer.last_frame() is Some(before_miss) else {
    fail("expected baseline Sun frame")
  }
  let missing = @core.CachedLayerSpec::new(
    key="missing-sun-layer",
    frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
    content_revision=1,
  )
  let miss = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::DrawCachedLayer(missing),
      ],
      damage=@core.DamageRegion::empty(),
    ),
  )
  inspect(miss.presented, content="false")
  inspect(miss.cache_miss_count, content="1")
  inspect(miss.missing_layer_keys.length(), content="1")
  inspect(miss.missing_layer_keys[0], content="missing-sun-layer")
  inspect(renderer.present_count(), content="1")
  match renderer.last_frame() {
    Some(after_miss) => {
      inspect(after_miss.width(), content="\{before_miss.width()}")
      let idx = (2 * after_miss.width() + 2) * 4
      assert_true(after_miss.pixels()[idx + 2].to_int() > 200)
    }
    None => fail("expected retained Sun frame after missing layer")
  }
}

///|
test "sun renderer render_frame treats empty cached layer draws as no-op" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    target,
  )
  let spec = @core.CachedLayerSpec::new(
    key="empty-layer",
    frame=@core.Rect::new(x=2.0, y=2.0, width=0.0, height=4.0),
    content_revision=1,
  )
  let result = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::DrawCachedLayer(spec),
      ],
      damage=@core.DamageRegion::empty(),
    ),
  )
  inspect(result.presented, content="true")
  inspect(result.cache_miss_count, content="0")
  inspect(result.cache_hit_count, content="0")
  inspect(renderer.present_count(), content="1")
  inspect(renderer.unsupported_command_count(), content="0")
}
