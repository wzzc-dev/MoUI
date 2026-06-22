///|
test "macOS Sun smoke options expose first-frame flag" {
  let options = MacosSunSmokeOptions::new(first_frame_smoke_auto_exit=true)
  inspect(options.first_frame_smoke_auto_exit, content="true")
}

///|
test "macOS Sun preflight describes experimental host bridge" {
  let preflight = macos_sun_provider_preflight_summary(
    options=MacosSunAppOptions::new(),
    smoke_options=MacosSunSmokeOptions::new(first_frame_smoke_auto_exit=true),
  )
  assert_true(preflight.contains("macOS Sun provider preflight"))
  assert_true(preflight.contains("renderer=experimental-ready"))
  assert_true(preflight.contains("macOS softbuffer Sun pixel presenter"))
  assert_true(
    preflight.contains("renderer_text_system=SunRasterRenderer.text_system"),
  )
  assert_true(preflight.contains("renderer_image_resources=none"))
  assert_true(preflight.contains("renderer_async_image_loading=none"))
  assert_true(preflight.contains("first_frame_smoke=enabled"))
}
