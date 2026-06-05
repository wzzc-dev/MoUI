///|
test "windows skia options default to system font resolution" {
  let options = WindowsSkiaAppOptions::new()
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
  assert_true(message.contains("moui_skia/native is unavailable"))
  assert_true(message.contains("real Skia link flags"))
}

///|
test "windows skia provider preflight records package evidence boundary" {
  let preflight = windows_skia_provider_preflight_summary()
  assert_true(preflight.contains("Windows Skia provider preflight"))
  assert_true(preflight.contains("renderer="))
  assert_true(
    preflight.contains("can_render=\{@skia_renderer.backend_info().can_render}"),
  )
  assert_true(
    preflight.contains("skia_available=\{@skia_renderer.skia_available()}"),
  )
  assert_true(preflight.contains("font=system-font-mgr"))
  assert_true(preflight.contains("Windows GDI Skia pixel presenter"))
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
    preflight.contains("renderer_image_loader=skia_image_load_completion"),
  )
  assert_true(
    preflight.contains(
      "renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion",
    ),
  )
  assert_true(
    preflight.contains(
      "renderer_image_resource_change=SkiaRasterRenderer.set_image_resource_change_callback",
    ),
  )
  assert_true(
    preflight.contains(
      "renderer_present_count=SkiaRasterRenderer.present_count",
    ),
  )
  assert_true(preflight.contains("renderer_dispose=SkiaRasterRenderer.dispose"))
  assert_true(preflight.contains("host=Windows host"))
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
  assert_true(preflight.contains("matching-host pending"))

  let empty = windows_skia_provider_preflight_summary(
    options=WindowsSkiaAppOptions::new(
      font_resolution=@skia_renderer.SkiaFontResolution::EmptyTypeface,
      exit_after_first_present=true,
    ),
  )
  assert_true(empty.contains("font=empty-typeface"))
  assert_true(empty.contains("first_frame_smoke=enabled"))
}

///|
fn skia_test_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}

///|
test "windows skia native image loader completes loading resources" {
  let loader = skia_native_image_loader()
  let window_id = @host.HostWindowId::new(1)
  let lifecycle = @render.ImageResourceLifecycle::new()
  let source = skia_test_png_data_uri()
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
    Some(record) =>
      if @skia_renderer.skia_available() {
        assert_true(record.status == @render.ImageResourceStatus::ImageReady)
        inspect(record.width, content="1")
        inspect(record.height, content="1")
      } else {
        assert_true(record.status == @render.ImageResourceStatus::ImageFailed)
        inspect(record.diagnostic, content="Skia image decode failed")
      }
    None => fail("expected completed Windows Skia image resource")
  }
  inspect(redraws.length(), content="1")
  assert_true(redraws[0] == window_id)
}

///|
test "windows skia deferred native source completes through decode helper" {
  let native_source = @host.HostNativeAsyncImageSource::new()
  let loader = native_source.loader()
  let window_id = @host.HostWindowId::new(2)
  let lifecycle = @render.ImageResourceLifecycle::new()
  let source = skia_test_png_data_uri()
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
  let scheduled = loader.schedule_loading_resources(
    window_id, renderer, completion_source,
  )
  inspect(scheduled.loading_count, content="1")
  inspect(scheduled.scheduled_count, content="1")
  inspect(native_source.pending_requests().length(), content="1")
  inspect(redraws.length(), content="0")
  match lifecycle.lookup(source) {
    Some(record) =>
      assert_true(record.status == @render.ImageResourceStatus::ImageLoading)
    None => fail("expected deferred Windows Skia image record")
  }
  let delivered = native_source.complete(
    window_id,
    @skia_renderer.skia_image_load_completion(source),
  )
  assert_true(
    delivered.status ==
    @host.HostNativeAsyncImageCompletionStatus::NativeAsyncImageCompletionDelivered,
  )
  match lifecycle.lookup(source) {
    Some(record) =>
      if @skia_renderer.skia_available() {
        assert_true(record.status == @render.ImageResourceStatus::ImageReady)
        inspect(record.width, content="1")
        inspect(record.height, content="1")
      } else {
        assert_true(record.status == @render.ImageResourceStatus::ImageFailed)
        inspect(record.diagnostic, content="Skia image decode failed")
      }
    None => fail("expected completed Windows Skia deferred image resource")
  }
  inspect(redraws.length(), content="1")
  assert_true(redraws[0] == window_id)
  inspect(loader.diagnostics().completed_count, content="1")
  inspect(native_source.diagnostics().pending_count, content="0")
}
