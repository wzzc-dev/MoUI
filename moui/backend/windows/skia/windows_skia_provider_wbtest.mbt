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
test "windows skia provider preflight records package observation boundary" {
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
    preflight.contains("renderer_image_loader=skia_async_image_loader"),
  )
  assert_true(preflight.contains("renderer_async_image_loading=off-main-io"))
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
      "host_services=clipboard,menus,file dialogs,file access,open URL,system theme",
    ),
  )
  assert_true(
    preflight.contains(
      "host_input=pointer,scroll,keyboard,focus,text input,IME,clipboard shortcuts,drag/drop",
    ),
  )
  assert_true(preflight.contains("clipboard=available"))
  assert_true(preflight.contains("menu_service=available"))
  assert_true(preflight.contains("file_dialogs=available"))
  assert_true(preflight.contains("file_access=available"))
  assert_true(preflight.contains("open_url=available"))
  assert_true(preflight.contains("system_theme=available"))
  assert_true(preflight.contains("async_services=gap"))
  assert_true(preflight.contains("window_lifecycle=available"))
  assert_true(preflight.contains("multi_window=available"))
  assert_true(preflight.contains("text_input=available"))
  assert_true(preflight.contains("ime=available"))
  assert_true(preflight.contains("drag_drop=available"))
  assert_true(preflight.contains("native_context_menu=available"))
  assert_true(preflight.contains("host_modal=available"))
  assert_true(preflight.contains("native_accessibility=gap"))
  assert_true(preflight.contains("real Skia link flags"))
  assert_true(preflight.contains("smoke log required"))

  let empty = windows_skia_provider_preflight_summary(
    options=WindowsSkiaAppOptions::new(
      font_resolution=@skia_renderer.SkiaFontResolution::EmptyTypeface,
    ),
  )
  assert_true(empty.contains("font=empty-typeface"))
}

///|
fn skia_test_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}

///|
test "windows skia async image loader completes loading resources" {
  let loader = skia_async_image_loader()
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

///|
test "windows skia options default to system font resolution" {
  let options = WindowsSkiaAppOptions::new()
  assert_true(
    options.font_resolution == @skia_renderer.SkiaFontResolution::SystemFontMgr,
  )
  assert_false(WindowsSkiaSmokeOptions::new().first_frame_smoke_auto_exit)
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
test "windows skia async image background_io confirmed" {
  guard @skia_renderer.skia_available() else { return () }
  let base = match @env.get_env_var("TEMP") {
    Some(v) => v
    None => match @env.get_env_var("TMP") {
      Some(v) => v
      None => "."
    }
  }
  let path = StringBuilder::new()
  path.write_string(base)
  path.write_string("\\moui-bg-io-test-windows.png")
  let path = path.to_string()
  @fs.write_bytes_to_file(path, @utf8.encode("test", bom=false)) catch {
    _ => fail("expected temp file write")
  }
  defer { @fs.remove_file(path) catch { _ => () } }
  let source_bytes = @utf8.encode(path, bom=false)
  moui_windows_async_image_spawn_sync(42, source_bytes, source_bytes.length())
  let max_attempts = 200
  let mut result = Bytes::make(0, 0)
  for attempt = 0; attempt < max_attempts; attempt = attempt + 1 {
    let r = moui_windows_async_image_take_result()
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
