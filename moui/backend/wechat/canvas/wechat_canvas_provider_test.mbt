///|
test "wechat_canvas_provider_creates_renderer" {
  let metrics = @host.HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=375.0, height=812.0),
    scale_factor=2.0,
  )
  let renderer = wechat_canvas_create_renderer(
    canvas_id="test-canvas",
    metrics~,
  )
  // Verify the renderer is created (we can't do much without actual Canvas)
  assert_eq(renderer.present_count(), 0)
}

///|
test "wechat_canvas_provider_dispose" {
  let metrics = @host.HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=375.0, height=812.0),
    scale_factor=2.0,
  )
  let renderer = wechat_canvas_create_renderer(
    canvas_id="test-canvas",
    metrics~,
  )
  renderer.dispose()
  // Dispose should not crash
}

///|
test "wechat_canvas_provider_render_frame_empty" {
  let metrics = @host.HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=375.0, height=812.0),
    scale_factor=2.0,
  )
  let renderer = wechat_canvas_create_renderer(
    canvas_id="test-canvas",
    metrics~,
  )
  let frame = @core.DrawFrame::new(
    commands=[],
    damage=@core.DamageRegion::empty(),
    clear_color=@core.Color::white(),
  )
  let result = renderer.render_frame(frame)
  assert_true(result.presented)
}

///|
test "wechat_canvas_provider_resize" {
  let metrics = @host.HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=375.0, height=812.0),
    scale_factor=2.0,
  )
  let renderer = wechat_canvas_create_renderer(
    canvas_id="test-canvas",
    metrics~,
  )
  let new_metrics = @render.RendererSurfaceMetrics::from_logical(
    size=@core.Size::new(width=414.0, height=896.0),
    scale_factor=3.0,
  )
  renderer.resize(new_metrics)
  // Resize should not crash
}
