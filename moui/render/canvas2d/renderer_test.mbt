///|
test "canvas2d_renderer_create_and_resize" {
  let renderer = Canvas2DRenderer::new(canvas_id="test-canvas")
  let metrics = @render.RendererSurfaceMetrics::new(
    logical_size=@core.Size::new(width=375.0, height=812.0),
    physical_size=@core.Size::new(width=1125.0, height=2436.0),
    scale_factor=3.0,
  )
  renderer.resize(metrics)
  assert_eq!(renderer.logical_width, 375.0)
  assert_eq!(renderer.logical_height, 812.0)
  assert_eq!(renderer.scale_factor, 3.0)
  assert_false!(renderer.disposed)
}

///|
test "canvas2d_renderer_dispose" {
  let renderer = Canvas2DRenderer::new(canvas_id="test-canvas")
  assert_false!(renderer.disposed)
  renderer.dispose()
  assert_true!(renderer.disposed)
}

///|
test "canvas2d_renderer_render_frame_empty" {
  let renderer = Canvas2DRenderer::new(canvas_id="test-canvas")
  let frame = @core.DrawFrame::new(
    commands=[],
    damage=@core.DamageRegion::empty(),
    clear_color=@core.Color::white(),
  )
  let result = renderer.render_frame(frame)
  assert_true!(result.presented)
}

///|
test "canvas2d_renderer_render_frame_after_dispose" {
  let renderer = Canvas2DRenderer::new(canvas_id="test-canvas")
  renderer.dispose()
  let frame = @core.DrawFrame::new(
    commands=[],
    damage=@core.DamageRegion::empty(),
    clear_color=@core.Color::white(),
  )
  let result = renderer.render_frame(frame)
  assert_false!(result.presented)
}

///|
test "canvas2d_create_renderer_sets_metrics" {
  let metrics = @render.RendererSurfaceMetrics::new(
    logical_size=@core.Size::new(width=390.0, height=844.0),
    physical_size=@core.Size::new(width=1170.0, height=2532.0),
    scale_factor=3.0,
  )
  let renderer = canvas2d_create_renderer(canvas_id="test-canvas", metrics~)
  assert_eq!(renderer.logical_width, 390.0)
  assert_eq!(renderer.logical_height, 844.0)
  assert_eq!(renderer.scale_factor, 3.0)
}

///|
test "canvas2d_descriptor_has_wasm_gc_target" {
  let descriptor = canvas2d_descriptor()
  assert_eq!(descriptor.supported_targets.length(), 1)
  assert_eq!(descriptor.supported_targets[0], @render.RendererTarget::WasmGc)
}

///|
test "canvas2d_image_resources_empty" {
  let renderer = Canvas2DRenderer::new(canvas_id="test-canvas")
  let resources = renderer.image_resources()
  assert_eq!(resources.length(), 0)
}