///|
fn skia_reset_red_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR42mP4z8DwH4QZYAwAR8oH+Rq28akAAAAASUVORK5CYII="
}

///|
fn skia_reset_blue_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEElEQVR42mNgYPj/H4KhDAA/0gf5XBPgQgAAAABJRU5ErkJggg=="
}

///|
fn skia_reset_write_png(path : String, data_uri : String) -> Bool {
  match skia_image_data_uri_bytes(data_uri) {
    Some(bytes) => {
      @fs.write_bytes_to_file(path, bytes) catch {
        _ => return false
      }
      true
    }
    None => false
  }
}

///|
fn skia_reset_has_pixel_color(
  frame : SkiaPixelFrame,
  rect : @core.Rect,
  channel : Int32,
) -> Bool {
  skia_test_region_has_matching_pixel(frame, rect, (r, g, b, a) => {
    let value = if channel == 0 { r } else if channel == 1 { g } else { b }
    a > 200 &&
    value > 200 &&
    (if channel == 0 { g < 80 && b < 80 } else { true })
  })
}

///|
fn skia_reset_render_image(
  renderer : SkiaRasterRenderer,
  source : String,
  size : Int32,
) -> SkiaPixelFrame? {
  let side = size.to_double()
  let frame = skia_test_draw_frame([
    Clear(@core.Color::white()),
    DrawImage(
      @core.ImageRun::new(
        source,
        @core.Rect::new(x=0.0, y=0.0, width=side, height=side),
        fit=Stretch,
      ),
    ),
  ])
  ignore(renderer.render_frame(frame))
  renderer.last_frame()
}

///|
fn skia_reset_fixture_font_path(relative : String) -> String? {
  let candidates = [relative, "../" + relative, "../../" + relative]
  for candidate in candidates {
    if @fs.path_exists(candidate) {
      return Some(candidate)
    }
  }
  None
}

///|
fn skia_reset_write_font(path : String, source : String) -> Bool {
  let bytes = @fs.read_file_to_bytes(source) catch { _ => return false }
  @fs.write_bytes_to_file(path, bytes) catch {
    _ => return false
  }
  true
}

///|
fn skia_reset_restore_font_env(previous : String?) -> Unit {
  match previous {
    Some(value) => @env.set_env_var("MOUI_SKIA_OPEN_SANS_DIR", value)
    None => @env.unset_env_var("MOUI_SKIA_OPEN_SANS_DIR")
  }
}

///|
fn skia_reset_region_checksum(
  frame : SkiaPixelFrame,
  rect : @core.Rect,
) -> Int64 {
  let min_x = rect.origin.x.floor().to_int().max(0)
  let min_y = rect.origin.y.floor().to_int().max(0)
  let max_x = (rect.origin.x + rect.size.width).ceil().to_int().min(frame.width)
  let max_y = (rect.origin.y + rect.size.height)
    .ceil()
    .to_int()
    .min(frame.height)
  let mut checksum = 0L
  for y in min_y..<max_y {
    for x in min_x..<max_x {
      let offset = y * frame.row_bytes + x * 4
      if offset + 3 < frame.pixels.length() {
        checksum = checksum +
          frame.pixels[offset].to_int().to_int64() +
          frame.pixels[offset + 1].to_int().to_int64() +
          frame.pixels[offset + 2].to_int().to_int64()
      }
    }
  }
  checksum
}

///|
test "skia reset_host_caches refreshes a same-path image" {
  guard skia_available() else { return }
  let source = skia_test_temp_path("moui-skia-reset-image.png")
  defer (@fs.remove_file(source) catch { _ => () })
  if !skia_reset_write_png(source, skia_reset_red_png_data_uri()) {
    fail("expected the red image fixture write")
  }
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    SkiaPresentTarget::new(description="test", present=_ => true),
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let session = renderer.to_renderer_session()
  let region = @core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0)
  guard skia_reset_render_image(renderer, source, 8) is Some(first) else {
    fail("expected a first reset-test frame")
  }
  assert_true(skia_reset_has_pixel_color(first, region, 0))
  // Rewrite the same path with different content. Without a reset the
  // path-keyed cache keeps the first image, which is exactly the post-swap
  // stale frame this regression test guards.
  if !skia_reset_write_png(source, skia_reset_blue_png_data_uri()) {
    fail("expected the blue image fixture write")
  }
  guard skia_reset_render_image(renderer, source, 8) is Some(stale) else {
    fail("expected a stale reset-test frame")
  }
  assert_true(skia_reset_has_pixel_color(stale, region, 0))
  assert_true(session.reset_caches())
  guard skia_reset_render_image(renderer, source, 8) is Some(fresh) else {
    fail("expected a fresh reset-test frame")
  }
  assert_true(skia_reset_has_pixel_color(fresh, region, 2))
  assert_false(skia_reset_has_pixel_color(fresh, region, 0))
}

///|
test "skia reset_host_caches refreshes a retained layer at the same revision" {
  guard skia_available() else { return }
  let source = skia_test_temp_path("moui-skia-reset-layer.png")
  defer (@fs.remove_file(source) catch { _ => () })
  if !skia_reset_write_png(source, skia_reset_red_png_data_uri()) {
    fail("expected the red layer fixture write")
  }
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=16.0),
    ),
    SkiaPresentTarget::new(description="test", present=_ => true),
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let session = renderer.to_renderer_session()
  let spec = @core.RetainedLayerSpec::new(
    key="swap-layer",
    frame=@core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
    content_revision=1,
  )
  let draw = skia_test_draw_frame([
    Clear(@core.Color::white()),
    BeginRetainedLayer(spec),
    DrawImage(
      @core.ImageRun::new(
        source,
        @core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
        fit=Stretch,
      ),
    ),
    EndRetainedLayer(spec.key),
  ])
  ignore(renderer.render_frame(draw))
  guard renderer.last_frame() is Some(first) else {
    fail("expected first retained-layer frame")
  }
  let region = @core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0)
  assert_true(skia_reset_has_pixel_color(first, region, 0))
  assert_true(
    renderer.layer_cache.length() + renderer.picture_layer_cache.length() > 0,
  )
  if !skia_reset_write_png(source, skia_reset_blue_png_data_uri()) {
    fail("expected the blue layer fixture write")
  }
  let stale = renderer.render_frame(draw)
  assert_true(stale.cache_hit_count > 0)
  guard renderer.last_frame() is Some(stale_frame) else {
    fail("expected stale retained-layer frame")
  }
  assert_true(skia_reset_has_pixel_color(stale_frame, region, 0))
  assert_true(session.reset_caches())
  let fresh = renderer.render_frame(draw)
  assert_true(fresh.cache_update_count > 0)
  guard renderer.last_frame() is Some(fresh_frame) else {
    fail("expected fresh retained-layer frame")
  }
  assert_true(skia_reset_has_pixel_color(fresh_frame, region, 2))
  assert_false(skia_reset_has_pixel_color(fresh_frame, region, 0))
}

///|
test "skia reset_host_caches reloads changed font data at the same path" {
  guard skia_available() else { return }
  let font_a = match
    skia_reset_fixture_font_path(
      ".mooncakes/Milky2018/moon_swash/docs/assets/NotoSans-Latin-wght.ttf",
    ) {
    Some(path) => path
    None => fail("missing Noto Sans font fixture")
  }
  let font_b = match
    skia_reset_fixture_font_path(
      ".mooncakes/Milky2018/moon_swash/docs/assets/SourceSans3-Regular.otf",
    ) {
    Some(path) => path
    None => fail("missing Source Sans font fixture")
  }
  let directory = skia_test_temp_path("moui-skia-reset-font")
  let path = directory + "/open-sans-v17-latin-ext_latin-regular.woff2"
  // A previous failed run may leave the font inside the directory, which
  // makes remove_dir refuse to clear it.
  @fs.remove_file(path) catch {
    _ => ()
  }
  @fs.remove_dir(directory) catch {
    _ => ()
  }
  @fs.create_dir(directory) catch {
    _ => fail("expected a writable reset-font directory")
  }
  defer (@fs.remove_file(path) catch { _ => () })
  defer (@fs.remove_dir(directory) catch { _ => () })
  let previous = @env.get_env_var("MOUI_SKIA_OPEN_SANS_DIR")
  defer skia_reset_restore_font_env(previous)
  @env.set_env_var("MOUI_SKIA_OPEN_SANS_DIR", directory)
  // The font-file cache is process-global and memoizes misses; start clean so
  // the generation-1 lookup below is the miss under test.
  clear_skia_font_file_typeface_cache()
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=200.0, height=40.0),
    ),
    SkiaPresentTarget::new(description="test", present=_ => true),
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let session = renderer.to_renderer_session()
  // "Open Sans" is the only family the font-file path serves; the generic
  // sans-serif fallback keeps the frame drawable while the file is absent and
  // on hosts whose font manager cannot load files (see the probe below).
  let font = @core.FontSpec::new(
    families=@core.FontFamilyStack::new([
      @core.FontFamily::Name("Open Sans"),
      @core.FontFamily::SansSerif,
    ]),
    size=20.0,
  )
  let input = @core.TextLayoutInput::new(text="Slim WWW WWWW", font~)
  let run = @core.TextRun::new(
    text="Slim WWW WWWW",
    frame=@core.Rect::new(x=0.0, y=0.0, width=200.0, height=32.0),
    font~,
    color=@core.Color::black(),
    align=TextStart,
  )
  let text_rect = @core.Rect::new(x=0.0, y=0.0, width=200.0, height=32.0)
  let draw = skia_test_draw_frame([Clear(@core.Color::white()), DrawText(run)])
  // Generation 1: the path does not exist yet, so the font-file lookup caches
  // a miss and the frame falls back to the system font.
  ignore(renderer.render_frame(draw))
  guard renderer.last_frame() is Some(missing) else {
    fail("expected a missing-font frame")
  }
  let missing_checksum = skia_reset_region_checksum(missing, text_rect)
  let width_missing = renderer.text_system().measure_text(input).size.width
  assert_true(renderer.text_shaping_cache.entries.length() > 0)
  assert_true(skia_font_file_typeface_cache.length() > 0)
  // Generation 2: the same path now exists with new content. Before the swap
  // reset the memoized miss and the shaped run both keep the old frame.
  if !skia_reset_write_font(path, font_a) {
    fail("expected the first font fixture copy")
  }
  let width_stale = renderer.text_system().measure_text(input).size.width
  assert_eq(width_stale, width_missing)
  ignore(renderer.render_frame(draw))
  guard renderer.last_frame() is Some(stale) else {
    fail("expected a stale font frame")
  }
  assert_eq(skia_reset_region_checksum(stale, text_rect), missing_checksum)
  assert_true(session.reset_caches())
  assert_eq(renderer.text_shaping_cache.entries.length(), 0)
  assert_eq(skia_font_file_typeface_cache.length(), 0)
  // File-based font resolution needs a font manager that creates a typeface
  // from caller bytes (makeFromData). The Linux prebuilt Skia stub's ordered
  // directory manager returns null there (upstream SkOrderedFontMgr
  // behaviour), so the content assertions only run where the platform manager
  // can load a font file.
  let file_fonts_supported = @skia_native.Typeface::from_file(
      @utf8.encode(path[:], bom=false),
    )
    is Some(_)
  if !file_fonts_supported {
    // The cache-eviction half of the fix still holds: the miss is gone, a
    // second generation retries the path, and the fallback frame is shaped
    // again rather than replayed from the previous generation.
    ignore(renderer.render_frame(draw))
    assert_true(renderer.text_shaping_cache.entries.length() > 0)
    renderer.reset_host_caches()
    return
  }
  let width_a = renderer.text_system().measure_text(input).size.width
  ignore(renderer.render_frame(draw))
  guard renderer.last_frame() is Some(frame_a) else {
    fail("expected a first loaded-font frame")
  }
  let checksum_a = skia_reset_region_checksum(frame_a, text_rect)
  assert_true(checksum_a != missing_checksum)
  // Replace the font behind the same path again. Without a reset both the
  // font-file entry and the shaped run stay on the first font.
  if !skia_reset_write_font(path, font_b) {
    fail("expected the replacement font fixture copy")
  }
  assert_eq(renderer.text_system().measure_text(input).size.width, width_a)
  ignore(renderer.render_frame(draw))
  guard renderer.last_frame() is Some(stale_a) else {
    fail("expected a stale first-font frame")
  }
  assert_eq(skia_reset_region_checksum(stale_a, text_rect), checksum_a)
  assert_true(session.reset_caches())
  assert_eq(renderer.text_shaping_cache.entries.length(), 0)
  assert_eq(skia_font_file_typeface_cache.length(), 0)
  let width_b = renderer.text_system().measure_text(input).size.width
  assert_true(width_b != width_a)
  ignore(renderer.render_frame(draw))
  guard renderer.last_frame() is Some(frame_b) else {
    fail("expected a refreshed font frame")
  }
  assert_true(skia_reset_region_checksum(frame_b, text_rect) != checksum_a)
  // Leave no temporary font in the process-global font-file cache.
  renderer.reset_host_caches()
}
