///|
test "Linux Sun smoke options expose first-frame flag" {
  let options = LinuxSunSmokeOptions::new(first_frame_smoke_auto_exit=true)
  inspect(options.first_frame_smoke_auto_exit, content="true")
}

///|
test "Linux Sun preflight describes direct Wayland pixel presenter" {
  let preflight = linux_sun_provider_preflight_summary(
    options=LinuxSunAppOptions::new(),
    smoke_options=LinuxSunSmokeOptions::new(first_frame_smoke_auto_exit=true),
  )
  assert_true(preflight.contains("Linux Sun provider preflight"))
  assert_true(preflight.contains("renderer=experimental-ready"))
  assert_true(preflight.contains("Linux Wayland wl_shm Sun pixel presenter"))
  assert_true(
    preflight.contains("renderer_text_system=SunRasterRenderer.text_system"),
  )
  assert_true(
    preflight.contains(
      "renderer_image_resources=SunRasterRenderer.image_resources",
    ),
  )
  assert_true(preflight.contains("renderer_async_image_loading=sync"))
  assert_true(
    preflight.contains(
      "renderer_image_resource_apply=SunRasterRenderer.apply_image_resource_load_completion",
    ),
  )
  assert_true(
    preflight.contains(
      "renderer_image_resource_change=SunRasterRenderer.set_image_resource_change_callback",
    ),
  )
  assert_true(
    preflight.contains("linux_presenter=window_linux.present_rgba_pixels"),
  )
  assert_true(preflight.contains("first_frame_smoke=enabled"))
}
