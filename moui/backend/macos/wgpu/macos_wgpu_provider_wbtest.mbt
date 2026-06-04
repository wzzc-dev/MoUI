///|
test "macos wgpu options default to platform text and host resolver" {
  let options = MacosWgpuAppOptions::new(exit_after_first_present=true)
  assert_true(
    options.text_engine ==
    @wgpu_renderer.NativeTextEngineSetting::PlatformDefault,
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
    _ => fail("expected default macOS WGPU scene resolver rejection")
  }
}

///|
fn wgpu_test_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}

///|
test "macos wgpu native image loader completes loading resources" {
  let loader = wgpu_native_image_loader()
  let window_id = @host.HostWindowId::new(1)
  let lifecycle = @render.ImageResourceLifecycle::new()
  let source = wgpu_test_png_data_uri()
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
    None => fail("expected completed macOS WGPU image resource")
  }
  inspect(redraws.length(), content="1")
  assert_true(redraws[0] == window_id)
}
