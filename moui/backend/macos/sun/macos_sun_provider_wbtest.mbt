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
  assert_true(preflight.contains("first_frame_smoke=enabled"))
}

///|
test "macOS Sun renderer metrics recover from zero initial surface height" {
  let metrics = renderer_metrics_from_host(
    @host.HostSurfaceMetrics::new(
      logical_size=@core.Size::new(width=960.0, height=560.0),
      physical_size=@core.Size::new(width=1.0, height=0.0),
      scale_factor=2.0,
    ),
  )
  inspect(metrics.physical_size.width, content="1")
  inspect(metrics.physical_size.height, content="1120")
  inspect(metrics.scale_factor, content="2")
}
