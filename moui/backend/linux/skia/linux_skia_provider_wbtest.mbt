///|
test "linux skia options default to system font resolution" {
  let options = LinuxSkiaAppOptions::new()
  assert_true(
    options.font_resolution == @skia_renderer.SkiaFontResolution::SystemFontMgr,
  )
  assert_false(options.exit_after_first_present)
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
    _ => fail("expected default Linux Skia scene resolver rejection")
  }
}

///|
test "linux skia availability follows render skia backend info" {
  assert_true(
    @skia_renderer.backend_info().can_render == @skia_renderer.skia_available(),
  )
  assert_true(
    linux_skia_provider_ready() == @skia_renderer.backend_info().can_render,
  )
}

///|
test "linux skia preflight diagnostic describes unavailable renderer setup" {
  let message = linux_skia_unavailable_message()
  assert_true(message.contains("Linux Skia renderer selected"))
  assert_true(message.contains("skia_mbt/native is unavailable"))
  assert_true(message.contains("real Skia link flags"))
}

///|
test "linux skia provider preflight records package evidence boundary" {
  let preflight = linux_skia_provider_preflight_summary()
  assert_true(preflight.contains("Linux Skia provider preflight"))
  assert_true(preflight.contains("renderer="))
  assert_true(
    preflight.contains("can_render=\{@skia_renderer.backend_info().can_render}"),
  )
  assert_true(
    preflight.contains("skia_available=\{@skia_renderer.skia_available()}"),
  )
  assert_true(preflight.contains("font=system-font-mgr"))
  assert_true(preflight.contains("Linux Wayland wl_shm Skia pixel presenter"))
  assert_true(preflight.contains("first_frame_smoke=disabled"))
  assert_true(preflight.contains("renderer_bridge=HostWindowRenderer"))
  assert_true(
    preflight.contains("renderer_text_system=SkiaRasterRenderer.text_system"),
  )
  assert_true(
    preflight.contains(
      "renderer_image_resources=SkiaRasterRenderer.image_resources",
    ),
  )
  assert_true(
    preflight.contains(
      "renderer_present_count=SkiaRasterRenderer.present_count",
    ),
  )
  assert_true(preflight.contains("renderer_dispose=SkiaRasterRenderer.dispose"))
  assert_true(preflight.contains("host=Linux host"))
  assert_true(preflight.contains("host_services=system theme"))
  assert_true(preflight.contains("host_input=pointer,scroll,keyboard,focus"))
  assert_true(preflight.contains("clipboard=gap"))
  assert_true(preflight.contains("menu_service=gap"))
  assert_true(preflight.contains("file_dialogs=gap"))
  assert_true(preflight.contains("open_url=gap"))
  assert_true(preflight.contains("system_theme=ready"))
  assert_true(preflight.contains("async_services=gap"))
  assert_true(preflight.contains("window_lifecycle=ready"))
  assert_true(preflight.contains("multi_window=ready"))
  assert_true(preflight.contains("text_input=gap"))
  assert_true(preflight.contains("ime=gap"))
  assert_true(preflight.contains("drag_drop=gap"))
  assert_true(preflight.contains("native_context_menu=gap"))
  assert_true(preflight.contains("host_modal=gap"))
  assert_true(preflight.contains("native_accessibility=gap"))
  assert_true(preflight.contains("real Skia link flags"))
  assert_true(preflight.contains("matching-host pending"))

  let empty = linux_skia_provider_preflight_summary(
    options=LinuxSkiaAppOptions::new(
      font_resolution=@skia_renderer.SkiaFontResolution::EmptyTypeface,
      exit_after_first_present=true,
    ),
  )
  assert_true(empty.contains("font=empty-typeface"))
  assert_true(empty.contains("first_frame_smoke=enabled"))
}
