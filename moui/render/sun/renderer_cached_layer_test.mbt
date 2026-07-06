///|
test "sun renderer DrawCachedLayer respects surrounding opacity" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
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
      let idx = (2 * frame.width + 2) * 4
      assert_true(frame.pixels[idx].to_int() > 240)
      assert_true(frame.pixels[idx + 1].to_int() > 100)
      assert_true(frame.pixels[idx + 1].to_int() < 200)
      assert_true(frame.pixels[idx + 2].to_int() > 100)
      assert_true(frame.pixels[idx + 2].to_int() < 200)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer cached layer refreshes when physical size changes" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
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
      let idx = (3 * frame.width + 3) * 4
      assert_true(frame.pixels[idx + 2].to_int() > 200)
      assert_true(frame.pixels[idx].to_int() < 80)
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
    @render.RendererSurfaceMetrics::from_logical(
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
      let moved_idx = (5 * frame.width + 5) * 4
      let old_idx = (2 * frame.width + 2) * 4
      assert_true(frame.pixels[moved_idx].to_int() > 200)
      assert_true(frame.pixels[old_idx].to_int() > 240)
      assert_true(frame.pixels[old_idx + 1].to_int() > 240)
      assert_true(frame.pixels[old_idx + 2].to_int() > 240)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer repeated same-key refresh keeps latest cache entry" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
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
  inspect(renderer.cached_layer_miss_count(), content="40")
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
  inspect(renderer.cached_layer_hit_count(), content="1")
  inspect(renderer.unsupported_command_count(), content="0")
}

///|
test "sun renderer resize clears cached layers" {
  let metrics = @render.RendererSurfaceMetrics::from_logical(
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
