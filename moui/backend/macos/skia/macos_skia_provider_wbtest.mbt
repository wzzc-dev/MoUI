///|
test "macos skia options default to system font resolution and host resolver" {
  let options = MacosSkiaAppOptions::new(exit_after_first_present=true)
  assert_true(
    options.font_resolution == @skia_renderer.SkiaFontResolution::SystemFontMgr,
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
test "macos skia options can explicitly select smoke-safe empty typeface" {
  let options = MacosSkiaAppOptions::new(
    font_resolution=@skia_renderer.SkiaFontResolution::EmptyTypeface,
  )
  assert_true(
    options.font_resolution == @skia_renderer.SkiaFontResolution::EmptyTypeface,
  )
}

///|
test "macos skia availability follows render skia backend info" {
  assert_true(
    @skia_renderer.backend_info().can_render == @skia_renderer.skia_available(),
  )
  assert_true(
    macos_skia_provider_ready() == @skia_renderer.backend_info().can_render,
  )
}

///|
test "macos skia preflight diagnostic describes unavailable renderer setup" {
  let message = macos_skia_unavailable_message()
  assert_true(message.contains("macOS Skia renderer selected"))
  assert_true(message.contains("skia_mbt/native is unavailable"))
  assert_true(message.contains("real Skia link flags"))
}

///|
test "macos skia provider preflight records package evidence boundary" {
  let preflight = macos_skia_provider_preflight_summary()
  assert_true(preflight.contains("macOS Skia provider preflight"))
  assert_true(preflight.contains("renderer="))
  assert_true(
    preflight.contains("can_render=\{@skia_renderer.backend_info().can_render}"),
  )
  assert_true(
    preflight.contains("skia_available=\{@skia_renderer.skia_available()}"),
  )
  assert_true(preflight.contains("font=system-font-mgr"))
  assert_true(preflight.contains("macOS NSImageView Skia pixel presenter"))
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
  assert_true(preflight.contains("host=macOS host"))
  assert_true(
    preflight.contains(
      "host_services=clipboard,menus,file dialogs,open URL,system theme",
    ),
  )
  assert_true(
    preflight.contains(
      "host_input=pointer,scroll,keyboard,focus,text input,IME,clipboard shortcuts,drag/drop",
    ),
  )
  assert_true(preflight.contains("clipboard=ready"))
  assert_true(preflight.contains("menu_service=ready"))
  assert_true(preflight.contains("file_dialogs=ready"))
  assert_true(preflight.contains("open_url=ready"))
  assert_true(preflight.contains("system_theme=ready"))
  assert_true(preflight.contains("async_services=gap"))
  assert_true(preflight.contains("window_lifecycle=ready"))
  assert_true(preflight.contains("multi_window=ready"))
  assert_true(preflight.contains("text_input=ready"))
  assert_true(preflight.contains("ime=ready"))
  assert_true(preflight.contains("drag_drop=ready"))
  assert_true(preflight.contains("native_context_menu=ready"))
  assert_true(preflight.contains("host_modal=ready"))
  assert_true(preflight.contains("native_accessibility=gap"))
  assert_true(preflight.contains("real Skia link flags"))
  assert_true(preflight.contains("first-frame smoke required"))

  let empty = macos_skia_provider_preflight_summary(
    options=MacosSkiaAppOptions::new(
      font_resolution=@skia_renderer.SkiaFontResolution::EmptyTypeface,
      exit_after_first_present=true,
    ),
  )
  assert_true(empty.contains("font=empty-typeface"))
}
