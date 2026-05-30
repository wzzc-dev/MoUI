///|
test "windows skia options default to system font resolution" {
  let options = WindowsSkiaAppOptions::new()
  assert_true(
    options.font_resolution == @skia_renderer.SkiaFontResolution::SystemFontMgr,
  )
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
    _ => fail("expected default Windows Skia scene resolver rejection")
  }
}

///|
test "windows skia availability follows render skia backend info" {
  assert_true(
    @skia_renderer.backend_info().can_render == @skia_renderer.skia_available(),
  )
  assert_true(
    windows_skia_provider_ready() == @skia_renderer.backend_info().can_render,
  )
}

///|
test "windows skia preflight diagnostic describes unavailable renderer setup" {
  let message = windows_skia_unavailable_message()
  assert_true(message.contains("Windows Skia renderer selected"))
  assert_true(message.contains("skia_mbt/native is unavailable"))
  assert_true(message.contains("real Skia link flags"))
}
