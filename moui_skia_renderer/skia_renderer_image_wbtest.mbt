///|
fn skia_test_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}

///|
fn skia_test_jpeg_data_uri() -> String {
  "data:image/jpeg;base64," +
  "/9j/4AAQSkZJRgABAQAAkACQAAD/4QCoRXhpZgAATU0AKgAAAAgABQEaAAUAAAABAAAASgEbAAUAAAABAAAAUgEoAAMAAAABAAIAAAExAAIAAAAJAAAAWodpAAQAAAABAAAAZAAAAAAAAACQAAAAAQAAAJAAAAABU25pcGFzdGUAAAADkoYABwAAABIAAACOoAIABAAAAAEAAAABoAMABAAAAAEAAAABAAAAAEFTQ0lJAAAAU2NyZWVuc2hvdP/tADhQaG90b3Nob3AgMy4wADhCSU0EBAAAAAAAADhCSU0EJQAAAAAAENQdjNmPALIE6YAJmOz4Qn7/4gIcSUNDX1BST0ZJTEUAAQEAAAIMYXBwbAQAAABtbnRyUkdCIFhZWiAH6gAFAB0ACgAMAAJhY3NwQVBQTAAAAABBUFBMAAAAAAAAAAAAAAAAAAAAAAAA9tYAAQAAAADTLWFwcGwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAApkZXNjAAAA/AAAADJjcHJ0AAABMAAAAFB3dHB0AAABgAAAABRyWFlaAAABlAAAABRnWFlaAAABqAAAABRiWFlaAAABvAAAABRyVFJDAAAB0AAAABBjaGFkAAAB4AAAACxiVFJDAAAB0AAAABBnVFJDAAAB0AAAABBtbHVjAAAAAAAAAAEAAAAMZW5VUwAAABYAAAAcADIANwBFADEATgA1ADUAMAAwAEwAQgAAbWx1YwAAAAAAAAABAAAADGVuVVMAAAA0AAAAHABDAG8AcAB5AHIAaQBnAGgAdAAgAEEAcABwAGwAZQAgAEkAbgBjAC4ALAAgADIAMAAyADZYWVogAAAAAAAA9tYAAQAAAADTLVhZWiAAAAAAAABuFAAAN20AAAH2WFlaIAAAAAAAAGJlAACzeQAAFbxYWVogAAAAAAAAJl0AABUZAAC7e3BhcmEAAAAAAAAAAAAB9gRzZjMyAAAAAAABC7cAAAWW///zVwAABykAAP3X///7t////aYAAAPaAADA9v/AABEIAAEAAQMBIgACEQEDEQH/xAAfAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgv/xAC1EAACAQMDAgQDBQUEBAAAAX0BAgMABBEFEiExQQYTUWEHInEUMoGRoQgjQrHBFVLR8CQzYnKCCQoWFxgZGiUmJygpKjQ1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4eLj5OXm5+jp6vHy8/T19vf4+fr/xAAfAQADAQEBAQEBAQEBAAAAAAAAAQIDBAUGBwgJCgv/xAC1EQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJIzNS8BVictEKFiQ04SXxFxgZGiYnKCkqNTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqCg4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2dri4+Tl5ufo6ery8/T19vf4+fr/2wBDAAICAgICAgMCAgMFAwMDBQYFBQUFBggGBgYGBggKCAgICAgICgoKCgoKCgoMDAwMDAwODg4ODg8PDw8PDw8PDw//2wBDAQICAgQEBAcEBAcQCwkLEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBD/3QAEAAH/2gAMAwEAAhEDEQA/AP3MooorsOc//9k="
}

///|
fn skia_test_bmp_data_uri() -> String {
  "data:image/bmp;base64," +
  "Qk0+AAAAAAAAADYAAAAoAAAAAgAAAAEAAAABACAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAD///8AAP8="
}

///|
test "skia renderer decodes jpeg and bmp data uris through encoded image api" {
  guard skia_available() else { return () }
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    SkiaPresentTarget::new(description="test", present=_ => true),
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }

  let jpeg_source = skia_test_jpeg_data_uri()
  match renderer.skia_image_for_source(jpeg_source) {
    None => fail("expected Skia JPEG data URI decode")
    Some(image) => {
      inspect(image.width(), content="1")
      inspect(image.height(), content="1")
    }
  }
  guard renderer.image_lifecycle.lookup(jpeg_source) is Some(jpeg_ready) else {
    fail("expected ready JPEG image lifecycle record")
  }
  assert_true(jpeg_ready.status == @render.ImageResourceStatus::ImageReady)

  let bmp_source = skia_test_bmp_data_uri()
  match renderer.skia_image_for_source(bmp_source) {
    None => fail("expected Skia BMP data URI decode")
    Some(image) => {
      inspect(image.width(), content="2")
      inspect(image.height(), content="1")
    }
  }
  guard renderer.image_lifecycle.lookup(bmp_source) is Some(bmp_ready) else {
    fail("expected ready BMP image lifecycle record")
  }
  assert_true(bmp_ready.status == @render.ImageResourceStatus::ImageReady)
  inspect(renderer.image_resources().length(), content="2")
}

///|
test "skia renderer decodes host-provided jpeg and bmp file bytes" {
  guard skia_available() else { return () }
  let jpeg_path = skia_test_temp_path("moui-skia-local-image-fixture.jpg")
  let bmp_path = skia_test_temp_path("moui-skia-local-image-fixture.bmp")
  @fs.remove_file(jpeg_path) catch {
    _ => ()
  }
  @fs.remove_file(bmp_path) catch {
    _ => ()
  }
  match skia_image_data_uri_bytes(skia_test_jpeg_data_uri()) {
    Some(bytes) =>
      @fs.write_bytes_to_file(jpeg_path, bytes) catch {
        _ => fail("expected local JPEG fixture write")
      }
    None => fail("expected embedded test JPEG bytes")
  }
  match skia_image_data_uri_bytes(skia_test_bmp_data_uri()) {
    Some(bytes) =>
      @fs.write_bytes_to_file(bmp_path, bytes) catch {
        _ => fail("expected local BMP fixture write")
      }
    None => fail("expected embedded test BMP bytes")
  }

  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    SkiaPresentTarget::new(description="test", present=_ => true),
    async_image_loading=true,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }

  assert_true(renderer.skia_image_for_source(jpeg_path) is None)
  ignore(
    renderer.apply_image_resource_load_completion(
      skia_image_load_completion_from_bytes(
        jpeg_path,
        @fs.read_file_to_bytes(jpeg_path) catch {
          _ => fail("expected host JPEG byte read")
        },
        background_io=true,
      ),
    ),
  )
  match renderer.skia_image_for_source(jpeg_path) {
    None => fail("expected Skia local JPEG decode")
    Some(image) => {
      inspect(image.width(), content="1")
      inspect(image.height(), content="1")
    }
  }
  guard renderer.image_lifecycle.lookup(jpeg_path) is Some(jpeg_ready) else {
    fail("expected ready local JPEG image lifecycle record")
  }
  assert_true(jpeg_ready.status == @render.ImageResourceStatus::ImageReady)

  assert_true(renderer.skia_image_for_source(bmp_path) is None)
  ignore(
    renderer.apply_image_resource_load_completion(
      skia_image_load_completion_from_bytes(
        bmp_path,
        @fs.read_file_to_bytes(bmp_path) catch {
          _ => fail("expected host BMP byte read")
        },
        background_io=true,
      ),
    ),
  )
  match renderer.skia_image_for_source(bmp_path) {
    None => fail("expected Skia local BMP decode")
    Some(image) => {
      inspect(image.width(), content="2")
      inspect(image.height(), content="1")
    }
  }
  guard renderer.image_lifecycle.lookup(bmp_path) is Some(bmp_ready) else {
    fail("expected ready local BMP image lifecycle record")
  }
  assert_true(bmp_ready.status == @render.ImageResourceStatus::ImageReady)
  inspect(renderer.image_resources().length(), content="2")

  @fs.remove_file(jpeg_path) catch {
    _ => ()
  }
  @fs.remove_file(bmp_path) catch {
    _ => ()
  }
}

///|
test "skia image load completion reports decoded dimensions or fallback failure" {
  let source = skia_test_png_data_uri()
  let completion = skia_image_load_completion(source)
  if skia_available() {
    assert_true(
      completion.status ==
      @render.ImageResourceLoadCompletionStatus::ImageLoadReady,
    )
    inspect(completion.source, content=source)
    inspect(completion.width, content="1")
    inspect(completion.height, content="1")
  } else {
    assert_true(
      completion.status ==
      @render.ImageResourceLoadCompletionStatus::ImageLoadFailed,
    )
    inspect(completion.diagnostic, content="Skia image decode failed")
  }
  let missing = skia_image_load_completion("moui-skia-missing://nope")
  assert_true(
    missing.status == @render.ImageResourceLoadCompletionStatus::ImageLoadFailed,
  )
  inspect(missing.diagnostic, content="Skia image source bytes are unavailable")
}

///|
test "skia image load completion from bytes decodes provided image bytes" {
  let source = skia_test_png_data_uri()
  match skia_image_data_uri_bytes(source) {
    Some(bytes) => {
      let completion = skia_image_load_completion_from_bytes(source, bytes)
      if skia_available() {
        assert_true(
          completion.status ==
          @render.ImageResourceLoadCompletionStatus::ImageLoadReady,
        )
        inspect(completion.source, content=source)
        inspect(completion.width, content="1")
        inspect(completion.height, content="1")
        assert_true(completion.has_decoded_rgba_payload())
        inspect(completion.decoded_row_bytes, content="4")
        inspect(completion.decoded_pixels.length(), content="4")
        inspect(completion.background_decode, content="false")
      } else {
        assert_true(
          completion.status ==
          @render.ImageResourceLoadCompletionStatus::ImageLoadFailed,
        )
        inspect(completion.diagnostic, content="Skia image decode failed")
      }
    }
    None => fail("expected embedded test PNG bytes for from_bytes test")
  }
  let invalid_bytes : Bytes = b"not-an-image"
  let failed = skia_image_load_completion_from_bytes(
    "invalid://bytes", invalid_bytes,
  )
  assert_true(
    failed.status == @render.ImageResourceLoadCompletionStatus::ImageLoadFailed,
  )
  inspect(failed.diagnostic, content="Skia image decode failed")
}

///|
test "skia renderer dispose clears cached image resources and records disposal" {
  guard skia_available() else { return () }
  let source = skia_test_png_data_uri()
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]) catch {
    err => fail("expected Skia image render: \{err.message()}")
  }
  assert_true(renderer.image_cache.get(source) is Some(_))
  guard renderer.image_lifecycle.lookup(source) is Some(ready) else {
    fail("expected ready image lifecycle record before dispose")
  }
  assert_true(ready.status == @render.ImageResourceStatus::ImageReady)
  renderer.dispose()
  assert_true(renderer.image_cache.get(source) is None)
  guard renderer.image_lifecycle.lookup(source) is Some(disposed) else {
    fail("expected disposed image lifecycle record after dispose")
  }
  assert_true(disposed.status == @render.ImageResourceStatus::ImageDisposed)
  inspect(renderer.image_resources().length(), content="1")
}

///|
test "skia renderer owns image lifecycle for ready and disposed resources" {
  guard skia_available() else { return () }
  let source = skia_test_png_data_uri()
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }

  renderer.render([
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]) catch {
    err => fail("expected Skia image render: \{err.message()}")
  }
  guard renderer.image_resources()[0]
    is { status: @render.ImageResourceStatus::ImageReady, .. } else {
    fail("expected ready image resource")
  }

  renderer.render([
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]) catch {
    err => fail("expected cached Skia image render: \{err.message()}")
  }
  inspect(renderer.image_resources().length(), content="1")

  renderer.dispose()
  guard renderer.image_resources()[0]
    is { status: @render.ImageResourceStatus::ImageDisposed, .. } else {
    fail("expected disposed image resource")
  }
}

///|
test "skia renderer applies image load completions and rejects stale results" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
    async_image_loading=true,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.mark_image_loading("async.png")
  let ready = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::ready("async.png", width=18, height=10),
  )
  assert_true(ready)
  guard renderer.image_lifecycle.lookup("async.png")
    is Some({ status: @render.ImageResourceStatus::ImageReady, .. }) else {
    fail("expected ready async image")
  }
  let stale = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::failed(
      "async.png",
      diagnostic="late failure",
    ),
  )
  assert_true(!stale)
  renderer.mark_image_loading("missing.png")
  let failed = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::failed(
      "missing.png",
      diagnostic="decode failed",
    ),
  )
  assert_true(failed)
  guard renderer.image_lifecycle.lookup("missing.png")
    is Some({ status: @render.ImageResourceStatus::ImageFailed, .. }) else {
    fail("expected failed image")
  }
  assert_true(renderer.failed_images.get("missing.png") is Some(_))
}

/// Regression: an async image completion must invalidate retained layers that
/// previously rasterized the loading placeholder. Otherwise redraws keep
/// hitting the old layer image and the newly decoded pixels never reach the
/// surface (especially visible while scrolling a repaint-boundary editor).
test "skia renderer retained layer refreshes after async image completion" {
  guard skia_available() else { return () }
  let source = "moui-skia-retained-async://red"
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    SkiaPresentTarget::new(description="test", present=_ => true),
    async_image_loading=true,
  ) catch {
    _ => fail("expected Skia renderer creation")
  }
  renderer.mark_image_loading(source)
  let spec = @core.RetainedLayerSpec::new(
    key="retained-async-image",
    frame=@core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0),
    content_revision=1,
  )
  let commands = [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::BeginRetainedLayer(spec),
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Stretch,
    }),
    @core.DrawCommand::EndRetainedLayer(spec.key),
  ]
  let first = renderer.render_frame(
    @core.DrawFrame::new(
      commands~,
      damage=@core.DamageRegion::full("initial image"),
    ),
  )
  assert_true(first.presented)
  let pixels = Bytes::from_array([b'\xff', b'\x00', b'\x00', b'\xff'])
  ignore(renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::ready_decoded_rgba(
      source,
      width=1,
      height=1,
      row_bytes=4,
      pixels,
    ),
  ))
  // The completion can race with a scroll/sidebar damage rect that does not
  // overlap the editor layer. The renderer must promote this frame to full
  // damage or the placeholder remains visible in the untouched region.
  let second = renderer.render_frame(
    @core.DrawFrame::new(
      commands~,
      damage=@core.DamageRegion::Rects([
        @core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
      ]),
    ),
  )
  assert_true(second.presented)
  inspect(second.cache_hit_count, content="0")
  guard renderer.last_frame() is Some(last) else {
    fail("expected retained async image frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      last,
      @core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && r > 220 && g < 40 && b < 40,
    ),
  )
}

///|
test "skia renderer async image loading waits for explicit decoded completion before caching" {
  guard skia_available() else { return () }
  let source = skia_test_png_data_uri()
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
    async_image_loading=true,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let commands = [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]
  renderer.render(commands) catch {
    err => fail("expected Skia async placeholder render: \{err.message()}")
  }
  inspect(renderer.present_count(), content="1")
  assert_true(renderer.image_cache.get(source) is None)
  guard renderer.image_lifecycle.lookup(source) is Some(loading) else {
    fail("expected loading image lifecycle record")
  }
  assert_true(loading.status == @render.ImageResourceStatus::ImageLoading)

  let completed = renderer.apply_image_resource_load_completion(
    skia_image_load_completion(source),
  )
  assert_true(completed)
  guard renderer.image_lifecycle.lookup(source) is Some(ready) else {
    fail("expected ready image lifecycle record")
  }
  assert_true(ready.status == @render.ImageResourceStatus::ImageReady)
  assert_true(renderer.image_cache.get(source) is Some(_))

  renderer.render(commands) catch {
    err => fail("expected Skia async second-frame render: \{err.message()}")
  }
  inspect(renderer.present_count(), content="2")
  assert_true(renderer.image_cache.get(source) is Some(_))
}

///|
test "skia renderer caches decoded async image completion without source decode" {
  guard skia_available() else { return () }
  let source = "moui-skia-decoded-async://cache-ready"
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
    async_image_loading=true,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let commands = [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]
  renderer.render(commands) catch {
    err => fail("expected Skia async placeholder render: \{err.message()}")
  }
  assert_true(renderer.image_cache.get(source) is None)
  guard renderer.image_lifecycle.lookup(source) is Some(loading) else {
    fail("expected loading image lifecycle record")
  }
  assert_true(loading.status == @render.ImageResourceStatus::ImageLoading)

  let pixels = Bytes::from_array([b'\xff', b'\x00', b'\x00', b'\xff'])
  let completed = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::ready_decoded_rgba(
      source,
      width=1,
      height=1,
      row_bytes=4,
      pixels,
      background_io=true,
      background_decode=true,
    ),
  )
  assert_true(completed)
  guard renderer.image_lifecycle.lookup(source) is Some(ready) else {
    fail("expected ready image lifecycle record")
  }
  assert_true(ready.status == @render.ImageResourceStatus::ImageReady)
  assert_true(renderer.image_cache.get(source) is Some(_))

  renderer.render(commands) catch {
    err =>
      fail("expected Skia decoded async second-frame render: \{err.message()}")
  }
  inspect(renderer.present_count(), content="2")
  assert_true(renderer.image_cache.get(source) is Some(_))
}

///|
test "skia renderer records failed image resources and reuses failed cache" {
  guard skia_available() else { return () }
  let missing_source = "moui-skia-missing-image-resource://not-a-file"
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source: missing_source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]) catch {
    err =>
      fail("expected Skia missing-image placeholder render: \{err.message()}")
  }
  assert_true(renderer.image_cache.get(missing_source) is None)
  guard renderer.image_lifecycle.lookup(missing_source) is Some(failed) else {
    fail("expected failed image lifecycle record")
  }
  assert_true(failed.status == @render.ImageResourceStatus::ImageFailed)
  assert_true(failed.diagnostic.contains("unavailable"))
  assert_true(renderer.failed_images.get(missing_source) is Some(_))
  inspect(renderer.image_resources().length(), content="1")
  inspect(renderer.present_count(), content="1")

  let valid_source = skia_test_png_data_uri()
  renderer.failed_images[valid_source] = "cached failure"
  match renderer.skia_image_for_source(valid_source) {
    Some(_) => fail("expected failed image cache to skip decode")
    None => ()
  }
  assert_true(renderer.image_cache.get(valid_source) is None)
  guard renderer.image_lifecycle.lookup(valid_source) is Some(cached) else {
    fail("expected cached failed image lifecycle record")
  }
  assert_true(cached.status == @render.ImageResourceStatus::ImageFailed)
  inspect(cached.diagnostic, content="cached failure")
}

///|
test "skia renderer keeps unchanged failed image cache stable" {
  guard skia_available() else { return () }
  let missing_source = "moui-skia-missing-image-resource://not-a-file"
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source: missing_source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]) catch {
    err =>
      fail("expected Skia missing-image placeholder render: \{err.message()}")
  }
  guard renderer.image_resources()[0]
    is { status: @render.ImageResourceStatus::ImageFailed, .. } else {
    fail("expected failed image resource")
  }

  renderer.render([
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source: missing_source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]) catch {
    err =>
      fail("expected cached failed-image placeholder render: \{err.message()}")
  }
  guard renderer.image_resources()[0]
    is { status: @render.ImageResourceStatus::ImageFailed, .. } else {
    fail("expected cached failed image resource")
  }
}

///|
test "skia renderer retries local image failures when the file appears" {
  guard skia_available() else { return () }
  let source = skia_test_temp_path("moui-skia-local-image-retry.png")
  @fs.remove_file(source) catch {
    _ => ()
  }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
    async_image_loading=true,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }

  renderer.render([
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]) catch {
    err => fail("expected Skia placeholder render: \{err.message()}")
  }
  assert_true(renderer.image_cache.get(source) is None)
  assert_true(renderer.failed_images.get(source) is None)
  guard renderer.image_lifecycle.lookup(source) is Some(failed) else {
    fail("expected loading local image lifecycle record")
  }
  assert_true(failed.status == @render.ImageResourceStatus::ImageLoading)
  ignore(
    renderer.apply_image_resource_load_completion(
      skia_image_load_completion(source),
    ),
  )
  assert_true(renderer.failed_images.get(source) is Some(_))

  match skia_image_data_uri_bytes(skia_test_png_data_uri()) {
    Some(bytes) =>
      @fs.write_bytes_to_file(source, bytes) catch {
        _ => fail("expected local image retry fixture write")
      }
    None => fail("expected embedded test PNG bytes")
  }
  renderer.mark_image_loading(source)
  ignore(
    renderer.apply_image_resource_load_completion(
      skia_image_load_completion_from_bytes(
        source,
        @fs.read_file_to_bytes(source) catch {
          _ => fail("expected host retry byte read")
        },
        background_io=true,
      ),
    ),
  )
  ignore(renderer.skia_image_for_source(source))
  @fs.remove_file(source) catch {
    _ => ()
  }

  assert_true(renderer.failed_images.get(source) is None)
  assert_true(renderer.image_cache.get(source) is Some(_))
  guard renderer.image_lifecycle.lookup(source) is Some(ready) else {
    fail("expected ready local image lifecycle record after retry")
  }
  assert_true(ready.status == @render.ImageResourceStatus::ImageReady)
  inspect(ready.width, content="1")
  inspect(ready.height, content="1")
}

///|
test "skia image placement records contain and cover sampling geometry" {
  let frame = @core.Rect::new(x=10.0, y=20.0, width=100.0, height=100.0)

  let wide_contain = skia_image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::Contain,
  )
  inspect(wide_contain.frame.origin.x, content="10")
  inspect(wide_contain.frame.origin.y, content="45")
  inspect(wide_contain.frame.size.width, content="100")
  inspect(wide_contain.frame.size.height, content="50")
  inspect(wide_contain.u0, content="0")
  inspect(wide_contain.v0, content="0")
  inspect(wide_contain.u1, content="1")
  inspect(wide_contain.v1, content="1")

  let tall_contain = skia_image_placement(
    frame,
    @core.Size::new(width=100.0, height=200.0),
    @core.ImageFit::Contain,
  )
  inspect(tall_contain.frame.origin.x, content="35")
  inspect(tall_contain.frame.origin.y, content="20")
  inspect(tall_contain.frame.size.width, content="50")
  inspect(tall_contain.frame.size.height, content="100")
  inspect(tall_contain.u0, content="0")
  inspect(tall_contain.v0, content="0")
  inspect(tall_contain.u1, content="1")
  inspect(tall_contain.v1, content="1")

  let wide_cover = skia_image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::Cover,
  )
  inspect(wide_cover.frame.origin.x, content="10")
  inspect(wide_cover.frame.origin.y, content="20")
  inspect(wide_cover.frame.size.width, content="100")
  inspect(wide_cover.frame.size.height, content="100")
  inspect(wide_cover.u0, content="0.25")
  inspect(wide_cover.v0, content="0")
  inspect(wide_cover.u1, content="0.75")
  inspect(wide_cover.v1, content="1")

  let tall_cover = skia_image_placement(
    frame,
    @core.Size::new(width=100.0, height=200.0),
    @core.ImageFit::Cover,
  )
  inspect(tall_cover.u0, content="0")
  inspect(tall_cover.v0, content="0.25")
  inspect(tall_cover.u1, content="1")
  inspect(tall_cover.v1, content="0.75")

  let stretch = skia_image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::Stretch,
  )
  inspect(stretch.frame.origin.x, content="10")
  inspect(stretch.frame.origin.y, content="20")
  inspect(stretch.frame.size.width, content="100")
  inspect(stretch.frame.size.height, content="100")
  inspect(stretch.u0, content="0")
  inspect(stretch.v0, content="0")
  inspect(stretch.u1, content="1")
  inspect(stretch.v1, content="1")

  let small_scale_down = skia_image_placement(
    frame,
    @core.Size::new(width=40.0, height=20.0),
    @core.ImageFit::ScaleDown,
  )
  inspect(small_scale_down.frame.origin.x, content="40")
  inspect(small_scale_down.frame.origin.y, content="60")
  inspect(small_scale_down.frame.size.width, content="40")
  inspect(small_scale_down.frame.size.height, content="20")
  inspect(small_scale_down.u0, content="0")
  inspect(small_scale_down.v0, content="0")
  inspect(small_scale_down.u1, content="1")
  inspect(small_scale_down.v1, content="1")

  let large_scale_down = skia_image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::ScaleDown,
  )
  inspect(large_scale_down.frame.origin.x, content="10")
  inspect(large_scale_down.frame.origin.y, content="45")
  inspect(large_scale_down.frame.size.width, content="100")
  inspect(large_scale_down.frame.size.height, content="50")

  let fit_width_short = skia_image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::FitWidth,
  )
  inspect(fit_width_short.frame.origin.x, content="10")
  inspect(fit_width_short.frame.origin.y, content="45")
  inspect(fit_width_short.frame.size.width, content="100")
  inspect(fit_width_short.frame.size.height, content="50")
  inspect(fit_width_short.u0, content="0")
  inspect(fit_width_short.v0, content="0")
  inspect(fit_width_short.u1, content="1")
  inspect(fit_width_short.v1, content="1")

  let fit_width_tall = skia_image_placement(
    frame,
    @core.Size::new(width=100.0, height=200.0),
    @core.ImageFit::FitWidth,
  )
  inspect(fit_width_tall.frame.origin.x, content="10")
  inspect(fit_width_tall.frame.origin.y, content="20")
  inspect(fit_width_tall.frame.size.width, content="100")
  inspect(fit_width_tall.frame.size.height, content="100")
  inspect(fit_width_tall.u0, content="0")
  inspect(fit_width_tall.v0, content="0.25")
  inspect(fit_width_tall.u1, content="1")
  inspect(fit_width_tall.v1, content="0.75")

  let fit_height_narrow = skia_image_placement(
    frame,
    @core.Size::new(width=100.0, height=200.0),
    @core.ImageFit::FitHeight,
  )
  inspect(fit_height_narrow.frame.origin.x, content="35")
  inspect(fit_height_narrow.frame.origin.y, content="20")
  inspect(fit_height_narrow.frame.size.width, content="50")
  inspect(fit_height_narrow.frame.size.height, content="100")
  inspect(fit_height_narrow.u0, content="0")
  inspect(fit_height_narrow.v0, content="0")
  inspect(fit_height_narrow.u1, content="1")
  inspect(fit_height_narrow.v1, content="1")

  let fit_height_wide = skia_image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::FitHeight,
  )
  inspect(fit_height_wide.frame.origin.x, content="10")
  inspect(fit_height_wide.frame.origin.y, content="20")
  inspect(fit_height_wide.frame.size.width, content="100")
  inspect(fit_height_wide.frame.size.height, content="100")
  inspect(fit_height_wide.u0, content="0.25")
  inspect(fit_height_wide.v0, content="0")
  inspect(fit_height_wide.u1, content="0.75")
  inspect(fit_height_wide.v1, content="1")

  let degenerate = skia_image_placement(
    frame,
    @core.Size::new(width=0.0, height=200.0),
    @core.ImageFit::Cover,
  )
  inspect(degenerate.frame.origin.x, content="10")
  inspect(degenerate.frame.origin.y, content="20")
  inspect(degenerate.frame.size.width, content="100")
  inspect(degenerate.frame.size.height, content="100")
  inspect(degenerate.u0, content="0")
  inspect(degenerate.v0, content="0")
  inspect(degenerate.u1, content="1")
  inspect(degenerate.v1, content="1")
}
