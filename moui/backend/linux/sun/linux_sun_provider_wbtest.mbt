///|
test "Linux Sun smoke options expose first-frame flag" {
  let options = LinuxSunSmokeOptions::new(first_frame_smoke_auto_exit=true)
  inspect(options.first_frame_smoke_auto_exit, content="true")
}

///|
fn sun_test_platform_view_plugin() -> @host.PlatformViewPlugin {
  @host.PlatformViewPlugin::new(
    kind="test-platform-view",
    capabilities_summary="test",
    install_event_dispatcher=_callback => (),
    sync_platform_views=(_native_view, _frame, _scale_factor) => (),
    drain_commands=_native_view => (),
    dispose_platform_views=_native_view => (),
  )
}

///|
test "Linux Sun app options expose Skia-aligned platform view plugins" {
  let options = LinuxSunAppOptions::new(platform_view_plugins=[
    sun_test_platform_view_plugin(),
  ])
  inspect(options.platform_view_plugins.length(), content="1")
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
    preflight.contains("renderer_frame=SunRasterRenderer.render_frame"),
  )
  assert_true(preflight.contains("renderer_preflight="))
  assert_true(preflight.contains("Sun CPU raster surface preflight ready"))
  assert_true(preflight.contains("resource cache preflight ready"))
  assert_true(
    preflight.contains(
      "renderer_platform_view_pixels=SunRasterRenderer.draw_platform_view_pixels",
    ),
  )
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
  assert_true(
    preflight.contains(
      "renderer_image_completion_source=HostNativeAsyncImageSource",
    ),
  )
  assert_true(preflight.contains("renderer_async_image_loading=off-main-io"))
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
  assert_true(
    preflight.contains(
      "first_frame_env=MOUI_LINUX_SUN_EXIT_AFTER_FIRST_PRESENT",
    ),
  )
  assert_true(preflight.contains("runtime_smokes=showcase-linux-sun"))
}

///|
fn sun_test_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}

///|
test "Linux Sun native image loader completes loading resources" {
  let loader = sun_native_image_loader()
  let window_id = @render.RenderWindowId::new(1)
  let lifecycle = @render.ImageResourceLifecycle::new()
  let source = sun_test_png_data_uri()
  ignore(lifecycle.mark_loading(source))
  let renderer = @render.HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image=@render.HostRendererImageCapability::new(
      image_resource_snapshot=Some(() => lifecycle.snapshot_with_revision()),
      apply_image_resource_load_completion=Some(completion => {
        lifecycle.apply_load_completion(completion)
      }),
    ),
  )
  let tracker = @render.HostImageResourceRepaintTracker::new()
  ignore(tracker.record_presented(window_id, renderer))
  let redraws : Array[@render.RenderWindowId] = []
  let completion_source = @render.HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=id => redraws.push(id),
  )
  let result = loader.schedule_loading_resources(
    window_id, renderer, completion_source,
  )
  inspect(result.loading_count(), content="1")
  inspect(result.scheduled_count(), content="1")
  match lifecycle.lookup(source) {
    Some(record) => {
      assert_true(record.status == @render.ImageResourceStatus::ImageReady)
      inspect(record.width, content="1")
      inspect(record.height, content="1")
    }
    None => fail("expected completed Linux Sun image resource")
  }
  inspect(redraws.length(), content="1")
  assert_true(redraws[0] == window_id)
}

///|
test "Linux Sun async image path records loading then second-frame completion" {
  let native_source = @render.HostNativeAsyncImageSource::new()
  let loader = native_source.loader()
  let window_id = @render.RenderWindowId::new(3)
  let lifecycle = @render.ImageResourceLifecycle::new()
  let source = sun_test_png_data_uri()
  ignore(lifecycle.mark_loading(source))
  let renderer = @render.HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image=@render.HostRendererImageCapability::new(
      image_resource_snapshot=Some(() => lifecycle.snapshot_with_revision()),
      apply_image_resource_load_completion=Some(completion => {
        lifecycle.apply_load_completion(completion)
      }),
    ),
  )
  let tracker = @render.HostImageResourceRepaintTracker::new()
  let first_frame = tracker.record_presented(window_id, renderer)
  assert_true(
    first_frame.status() ==
    @render.HostImageResourceRepaintStatus::ImageRepaintRecorded,
  )
  inspect(first_frame.current_status_counts().loading_count(), content="1")
  inspect(first_frame.current_status_counts().ready_count(), content="0")
  let redraws : Array[@render.RenderWindowId] = []
  let completion_source = @render.HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=id => redraws.push(id),
  )
  let scheduled = loader.schedule_loading_resources(
    window_id, renderer, completion_source,
  )
  inspect(scheduled.loading_count(), content="1")
  inspect(scheduled.scheduled_count(), content="1")
  inspect(native_source.pending_requests().length(), content="1")
  inspect(redraws.length(), content="0")
  match lifecycle.lookup(source) {
    Some(record) =>
      assert_true(record.status == @render.ImageResourceStatus::ImageLoading)
    None => fail("expected deferred Linux Sun image record")
  }
  let tracked_loading = tracker.snapshot()
  inspect(tracked_loading.tracked_window_count(), content="1")
  inspect(tracked_loading.tracked_windows()[0].revision(), content="1")
  inspect(
    tracked_loading.tracked_windows()[0].status_counts().loading_count(),
    content="1",
  )
  let delivered = native_source.complete(
    window_id,
    @sun_renderer.sun_image_load_completion(source),
  )
  assert_true(
    delivered.status() ==
    @render.HostNativeAsyncImageCompletionStatus::NativeAsyncImageCompletionDelivered,
  )
  match lifecycle.lookup(source) {
    Some(record) => {
      assert_true(record.status == @render.ImageResourceStatus::ImageReady)
      inspect(record.width, content="1")
      inspect(record.height, content="1")
    }
    None => fail("expected completed Linux Sun deferred image resource")
  }
  inspect(redraws.length(), content="1")
  assert_true(redraws[0] == window_id)
  let tracked_completed = tracker.snapshot()
  inspect(tracked_completed.tracked_window_count(), content="1")
  inspect(tracked_completed.tracked_windows()[0].revision(), content="2")
  inspect(
    tracked_completed.tracked_windows()[0].status_counts().ready_count(),
    content="1",
  )
  let second_frame = tracker.record_presented(window_id, renderer)
  assert_true(
    second_frame.status() ==
    @render.HostImageResourceRepaintStatus::ImageRepaintRecorded,
  )
  inspect(second_frame.current_status_counts().ready_count(), content="1")
  inspect(second_frame.current_status_counts().failed_count(), content="0")
  inspect(loader.diagnostics().completed_count(), content="1")
  inspect(native_source.diagnostics().pending_count(), content="0")
}

///|
extern "C" fn usleep(microseconds : Int) -> Int = "usleep"

///|
test "Linux Sun async image background_io confirmed" {
  let path = "/tmp/moui-sun-bg-io-test-linux.png"
  @fs.write_bytes_to_file(path, @utf8.encode("test", bom=false)) catch {
    _ => fail("expected temp file write")
  }
  defer (@fs.remove_file(path) catch { _ => () })
  let source_bytes = @utf8.encode(path, bom=false)
  moui_linux_sun_async_image_spawn(42, source_bytes, source_bytes.length())
  let max_attempts = 200
  let mut result = Bytes::make(0, 0)
  for attempt = 0; attempt < max_attempts; attempt = attempt + 1 {
    ignore(attempt)
    let r = moui_linux_sun_async_image_take_result()
    if r.length() > 0 {
      result = r
      break
    }
    let _ = usleep(1000)
  }
  guard result.length() >= 24 else {
    fail("expected result with 24-byte header, got \{result.length()} bytes")
  }
  let background_io_raw = async_image_read_i32_le(result, 20)
  assert_true(background_io_raw == 1)
}
