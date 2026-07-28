///|
test "Windows Sun smoke options expose first-frame flag" {
  let options = WindowsSunSmokeOptions::new(first_frame_smoke_auto_exit=true)
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
test "Windows Sun app options expose Skia-aligned platform view plugins" {
  let options = WindowsSunAppOptions::new(platform_view_plugins=[
    sun_test_platform_view_plugin(),
  ])
  inspect(options.platform_view_plugins.length(), content="1")
}

///|
test "Windows Sun preflight describes experimental host bridge" {
  let preflight = windows_sun_provider_preflight_summary(
    options=WindowsSunAppOptions::new(),
    smoke_options=WindowsSunSmokeOptions::new(first_frame_smoke_auto_exit=true),
  )
  assert_true(preflight.contains("Windows Sun provider preflight"))
  assert_true(preflight.contains("renderer=experimental-ready"))
  assert_true(preflight.contains("Windows softbuffer Sun pixel presenter"))
  assert_true(
    preflight.contains("renderer_frame=SunRasterRenderer.render_frame"),
  )
  assert_true(
    preflight.contains(
      "renderer_platform_view_pixels=SunRasterRenderer.draw_platform_view_pixels",
    ),
  )
  assert_true(preflight.contains("renderer_preflight="))
  assert_true(preflight.contains("Sun CPU raster surface preflight ready"))
  assert_true(preflight.contains("resource cache preflight ready"))
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
  assert_true(preflight.contains("first_frame_smoke=enabled"))
  assert_true(
    preflight.contains(
      "first_frame_env=MOUI_WINDOWS_SUN_EXIT_AFTER_FIRST_PRESENT",
    ),
  )
  assert_true(preflight.contains("runtime_smokes=showcase-windows-sun"))
}

///|
test "Windows Sun host renderer forwards platform view pixels" {
  let presented = Ref(None)
  let renderer = @sun_renderer.create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    @sun_renderer.SunPresentTarget::new(
      description="windows-sun-platform-view-test",
      present=frame => {
        presented.val = Some(frame)
        true
      },
    ),
  )
  let host_renderer = host_renderer_from_sun(renderer)
  host_renderer.set_platform_view_draw_fn(
    Some(() => {
      host_renderer.draw_platform_view_pixels(
        Bytes::from_array([255, 0, 0, 255]),
        1,
        1,
        4,
        1.0,
        1.0,
        1.0,
        1.0,
      )
    }),
  )
  let result = host_renderer.render_frame(
    @core.DrawFrame::new(
      commands=[@core.DrawCommand::Clear(@core.Color::white())],
      damage=@core.DamageRegion::full("Windows Sun platform view pixels"),
    ),
  )
  inspect(result.presented, content="true")
  match presented.val {
    Some(frame) => {
      let pixels = frame.pixels()
      let red = (1 * frame.width() + 1) * 4
      assert_true(pixels[red].to_int() > 200)
      assert_true(pixels[red + 1].to_int() < 80)
      assert_true(pixels[red + 2].to_int() < 80)
    }
    None => fail("expected Windows Sun frame with platform-view pixels")
  }
}

///|
fn sun_test_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}

///|
test "Windows Sun native image loader completes loading resources" {
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
    None => fail("expected completed Windows Sun image resource")
  }
  inspect(redraws.length(), content="1")
  assert_true(redraws[0] == window_id)
}

///|
test "Windows Sun async image path records loading then second-frame completion" {
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
    None => fail("expected deferred Windows Sun image record")
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
    None => fail("expected completed Windows Sun deferred image resource")
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
#borrow(source_bytes)
extern "C" fn moui_windows_sun_async_image_spawn_sync(
  window_id : Int64,
  source_bytes : Bytes,
  source_len : Int,
) -> Unit = "moui_windows_sun_async_image_spawn_sync"

///|
test "Windows Sun async image background_io confirmed" {
  // The native async-image stub only runs on Windows; on other hosts the
  // spawn_sync/take_result pair is a no-op that returns 0 bytes.
  guard @env.get_env_var("OS") == Some("Windows_NT") else { return () }
  let base = match @env.get_env_var("TEMP") {
    Some(value) => value
    None =>
      match @env.get_env_var("TMP") {
        Some(value) => value
        None => "."
      }
  }
  let path = StringBuilder::new()
  path.write_string(base)
  path.write_string("\\moui-sun-bg-io-test-windows.png")
  let path = path.to_string()
  @fs.write_bytes_to_file(path, @utf8.encode("test", bom=false)) catch {
    _ => fail("expected temp file write")
  }
  defer (@fs.remove_file(path) catch { _ => () })
  let source_bytes = @utf8.encode(path, bom=false)
  moui_windows_sun_async_image_spawn_sync(
    42,
    source_bytes,
    source_bytes.length(),
  )
  let max_attempts = 200
  let mut result = Bytes::make(0, 0)
  for attempt = 0; attempt < max_attempts; attempt = attempt + 1 {
    ignore(attempt)
    let r = moui_windows_sun_async_image_take_result()
    if r.length() > 0 {
      result = r
      break
    }
  }
  guard result.length() >= 24 else {
    fail("expected result with 24-byte header, got \{result.length()} bytes")
  }
  let background_io_raw = async_image_read_i32_le(result, 20)
  assert_true(background_io_raw == 1)
}
