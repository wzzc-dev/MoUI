///|
test "macos skia options default to fallback-safe text and host resolver" {
  let options = MacosSkiaAppOptions::new(exit_after_first_present=true)
  assert_true(
    options.font_resolution == @skia_renderer.SkiaFontResolution::EmptyTypeface,
  )
  inspect(options.exit_after_first_present, content="true")
  let request = @host.HostWindowOpenRequest::new(
    title="Inspector",
    scene=@host.HostWindowScene::new(scene_id="inspector"),
    metrics=@host.HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match options.scene_resolver.resolve(request) {
    @host.HostWindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected default macOS Skia scene resolver rejection")
  }
}

///|
test "macos skia availability follows render skia backend info" {
  assert_true(
    @skia_renderer.backend_info().can_render == @skia_renderer.skia_available(),
  )
}
