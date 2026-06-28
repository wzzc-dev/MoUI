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
  assert_true(
    preflight.contains("renderer_image_loader=sun_image_load_completion"),
  )
  assert_true(preflight.contains("renderer_async_image_loading=post-present"))
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

///|
fn sun_test_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}

///|
test "macOS Sun native image loader completes loading resources" {
  let loader = sun_native_image_loader()
  let window_id = @host.HostWindowId::new(1)
  let lifecycle = @render.ImageResourceLifecycle::new()
  let source = sun_test_png_data_uri()
  ignore(lifecycle.mark_loading(source))
  let renderer = @host.HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image_resource_snapshot=Some(() => lifecycle.snapshot_with_revision()),
    apply_image_resource_load_completion=Some(completion => {
      lifecycle.apply_load_completion(completion)
    }),
  )
  let tracker = @host.HostImageResourceRepaintTracker::new()
  ignore(tracker.record_presented(window_id, renderer))
  let redraws : Array[@host.HostWindowId] = []
  let completion_source = @host.HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=id => redraws.push(id),
  )
  let result = loader.schedule_loading_resources(
    window_id, renderer, completion_source,
  )
  inspect(result.loading_count, content="1")
  inspect(result.scheduled_count, content="1")
  match lifecycle.lookup(source) {
    Some(record) => {
      assert_true(record.status == @render.ImageResourceStatus::ImageReady)
      inspect(record.width, content="1")
      inspect(record.height, content="1")
    }
    None => fail("expected completed macOS Sun image resource")
  }
  inspect(redraws.length(), content="1")
  assert_true(redraws[0] == window_id)
}
