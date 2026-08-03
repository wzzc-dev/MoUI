///|
test "skia hybrid renderer presents next frame through raster after terminal recovery" {
  guard skia_available() else { return () }
  let presents = Ref(0)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    SkiaPresentTarget::new(description="hybrid-raster-fallback", present=_ => {
      presents.val = presents.val + 1
      true
    }),
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let hybrid = SkiaHybridRenderer::{
    renderer,
    worker: @render.GpuRenderWorker::new(),
    surface_route: resolve_surface_route(
      NativeGpuPlatform::MacOS,
      NativeRendererMode::SkiaGpu,
      gpu_available=true,
      gpu_promoted=false,
    ),
    requested: NativeRendererMode::SkiaGpu,
    fallback_to_raster: false,
    pending_completions: [],
  }
  hybrid.worker.fail_next_context_recovery()
  ignore(
    hybrid.worker.submit_control(
      @render.RendererControlMessage::ContextLoss("first"),
    ),
  )
  hybrid.worker.poll()
  hybrid.worker.poll()
  hybrid.worker.fail_next_context_recovery()
  ignore(
    hybrid.worker.submit_control(
      @render.RendererControlMessage::ContextLoss("second"),
    ),
  )
  hybrid.worker.poll()
  hybrid.worker.poll()
  let frame = skia_test_draw_frame([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=1.0, y=1.0, width=4.0, height=4.0),
      @core.Color::black(),
    ),
  ])
  let terminal = hybrid.render_frame(frame)
  assert_false(terminal.presented)
  assert_true(hybrid.fallback_to_raster())
  let completions = hybrid.drain_present_completions()
  assert_true(
    completions.any(completion => {
      completion.status() is @render.RenderPresentStatus::FallbackToRaster
    }),
  )
  let fallback = hybrid.render_frame(frame)
  assert_true(fallback.presented)
  inspect(presents.val, content="1")
  renderer.dispose()
}
