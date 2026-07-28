///|
test "macos skia options default to system font resolution and host resolver" {
  let options = MacosSkiaAppOptions::new()
  assert_true(
    options.font_resolution == @skia_renderer.SkiaFontResolution::SystemFontMgr,
  )
  // Default follows auto: Metal when the GPU runtime is available, else raster.
  let expected_route = macos_surface_route_from_environment()
  assert_true(options.surface_route == expected_route)
  let smoke_options = MacosSkiaSmokeOptions::new(
    first_frame_smoke_auto_exit=true,
    native_ime_runtime_smoke=true,
  )
  inspect(smoke_options.first_frame_smoke_auto_exit, content="true")
  inspect(smoke_options.native_ime_runtime_smoke, content="true")
  let request = @host.HostWindowOpenRequest::new(
    title="Inspector",
    scene=@host.HostWindowScene::new(scene_id="inspector"),
    metrics=@host.HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match options.scene_resolver.resolve(request) {
    @runtime.HostWindowSceneResolution::SceneRejected(message) =>
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
  assert_true(message.contains("moui_skia/native is unavailable"))
  assert_true(message.contains("real Skia link flags"))
}

///|
test "macos skia provider preflight records package observation boundary" {
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
  let expected_route = macos_surface_route_from_environment().label()
  assert_true(preflight.contains("surface_route=\{expected_route}"))
  assert_true(
    preflight.contains("macOS pass-through NSImageView Skia pixel presenter") ||
    preflight.contains("Metal"),
  )
  assert_true(preflight.contains("gpu_route=Metal GPU opt-in preflight"))
  assert_true(preflight.contains("window-present=pending"))
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
  assert_true(preflight.contains("host=macOS host"))
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
  assert_true(preflight.contains("first-frame smoke required"))

  let empty = macos_skia_provider_preflight_summary(
    options=MacosSkiaAppOptions::new(
      font_resolution=@skia_renderer.SkiaFontResolution::EmptyTypeface,
      surface_route=@render.SkiaSurfaceRoute::MetalGpuSurfaceRoute,
    ),
  )
  assert_true(empty.contains("font=empty-typeface"))
  assert_true(empty.contains("surface_route=metal-gpu"))
}

///|
test "macos skia preflight reports gpu metal direct presenter path" {
  let summary = macos_skia_provider_preflight_summary()
  assert_true(
    summary.contains(
      "gpu_presenter=macOS CAMetalLayer Skia Metal direct GPU presenter",
    ),
  )
  assert_true(summary.contains("gpu_runtime_available="))
  assert_true(summary.contains("metal_layer_install=available"))
}

///|
fn skia_test_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}

///|
test "macos skia async image loader completes loading resources" {
  let loader = skia_async_image_loader()
  let window_id = @host.HostWindowId::new(1)
  let lifecycle = @render.ImageResourceLifecycle::new()
  let source = skia_test_png_data_uri()
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
  let redraws : Array[@host.HostWindowId] = []
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
    Some(record) =>
      if @skia_renderer.skia_available() {
        assert_true(record.status == @render.ImageResourceStatus::ImageReady)
        inspect(record.width, content="1")
        inspect(record.height, content="1")
      } else {
        assert_true(record.status == @render.ImageResourceStatus::ImageFailed)
        inspect(record.diagnostic, content="Skia image decode failed")
      }
    None => fail("expected completed macOS Skia image resource")
  }
  inspect(redraws.length(), content="1")
  assert_true(redraws[0] == window_id)
}

///|
test "macos skia deferred native source completes through decode helper" {
  let native_source = @render.HostNativeAsyncImageSource::new()
  let loader = native_source.loader()
  let window_id = @host.HostWindowId::new(2)
  let lifecycle = @render.ImageResourceLifecycle::new()
  let source = skia_test_png_data_uri()
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
  let redraws : Array[@host.HostWindowId] = []
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
    None => fail("expected deferred macOS Skia image record")
  }
  let delivered = native_source.complete(
    window_id,
    @skia_renderer.skia_image_load_completion(source),
  )
  assert_true(
    delivered.status() ==
    @render.HostNativeAsyncImageCompletionStatus::NativeAsyncImageCompletionDelivered,
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
    None => fail("expected completed macOS Skia deferred image resource")
  }
  inspect(redraws.length(), content="1")
  assert_true(redraws[0] == window_id)
  inspect(loader.diagnostics().completed_count(), content="1")
  inspect(native_source.diagnostics().pending_count(), content="0")
}

///|

///|
extern "C" fn usleep(microseconds : Int) -> Int = "usleep"

///|
fn skia_provider_test_png_bytes() -> Bytes {
  @base64.decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==",
    ignore_whitespace=true,
  ) catch {
    _ => Bytes::make(0, 0)
  }
}

///|
test "macos skia async image background decode confirmed" {
  guard @skia_renderer.skia_available() else { return () }
  let path = "/tmp/moui-bg-decode-test-macos.png"
  @fs.write_bytes_to_file(path, skia_provider_test_png_bytes()) catch {
    _ => fail("expected temp file write")
  }
  defer (@fs.remove_file(path) catch { _ => () })
  let source_bytes = @utf8.encode(path, bom=false)
  moui_macos_async_image_spawn(42, source_bytes, source_bytes.length())
  let max_attempts = 200
  let mut result = Bytes::make(0, 0)
  for attempt = 0; attempt < max_attempts; attempt = attempt + 1 {
    let r = moui_macos_async_image_take_result()
    if r.length() > 0 {
      result = r
      break
    }
    let _ = usleep(1000)
  }
  guard result.length() >= 40 else {
    fail("expected result with 40-byte header, got \{result.length()} bytes")
  }
  let status = async_image_read_i32_le(result, 8)
  let bytes_len = async_image_read_i32_le(result, 16)
  let background_io_raw = async_image_read_i32_le(result, 20)
  let decoded_width = async_image_read_i32_le(result, 24)
  let decoded_height = async_image_read_i32_le(result, 28)
  let decoded_row_bytes = async_image_read_i32_le(result, 32)
  let background_decode_raw = async_image_read_i32_le(result, 36)
  inspect(status, content="0")
  assert_true(background_io_raw == 1)
  inspect(decoded_width, content="1")
  inspect(decoded_height, content="1")
  inspect(decoded_row_bytes, content="4")
  assert_true(background_decode_raw == 1)
  inspect(bytes_len, content="4")
}
