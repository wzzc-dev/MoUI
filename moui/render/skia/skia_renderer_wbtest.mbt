///|
test "skia transform maps MoUI affine fields to Skia matrix members" {
  let transform = @core.Transform2D::{
    a: 2.0,
    b: 3.0,
    c: 5.0,
    d: 7.0,
    tx: 11.0,
    ty: 13.0,
  }
  let matrix = skia_matrix(transform)
  assert_true(
    matrix.values() == [2.0, 5.0, 11.0, 3.0, 7.0, 13.0, 0.0, 0.0, 1.0],
  )
  assert_true(
    matrix.map_point(@moui_skia.Point::new(17.0, 19.0)) ==
    @moui_skia.Point::new(140.0, 197.0),
  )
}

///|
fn skia_test_temp_env(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) => {
      let clean = value.trim().to_owned()
      if clean == "" {
        None
      } else {
        Some(clean)
      }
    }
    None => None
  }
}

///|
fn skia_test_temp_dir() -> String {
  let names = ["MOUI_TEST_TMPDIR", "TMPDIR", "TEMP", "TMP"]
  for name in names {
    match skia_test_temp_env(name) {
      Some(value) => return value
      None => ()
    }
  }
  "/tmp"
}

///|
fn skia_test_temp_path(filename : String) -> String {
  let dir = skia_test_temp_dir()
  let chars = dir.to_array()
  if chars.length() == 0 {
    filename
  } else if chars[chars.length() - 1] == '/' ||
    chars[chars.length() - 1] == '\\' {
    dir + filename
  } else {
    dir + "/" + filename
  }
}

///|
test "skia raster surface preflight consumes moui_skia resource descriptors" {
  let preflight = raster_surface_preflight(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=12.0, height=8.0),
      scale_factor=2.0,
    ),
  )
  inspect(preflight.physical_width, content="24")
  inspect(preflight.physical_height, content="16")
  assert_true(preflight.target_ready)
  assert_true(preflight.frame_ready)
  assert_true(preflight.finalization_ready)
  assert_true(preflight.submission_ready)
  inspect(preflight.resource_count, content="2")
  inspect(preflight.cacheable_resource_count, content="1")
  inspect(preflight.uncacheable_resource_count, content="1")
  inspect(preflight.gpu_backed_resource_count, content="0")
  inspect(preflight.surface_resource_count, content="2")
  assert_true(preflight.byte_size > 0L)
}

///|
test "skia raster surface preflight clamps empty physical targets" {
  let preflight = raster_surface_preflight(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=0.0, height=8.0),
      scale_factor=2.0,
    ),
  )
  inspect(preflight.physical_width, content="1")
  inspect(preflight.physical_height, content="16")
  assert_true(preflight.target_ready)
  assert_true(preflight.frame_ready)
  assert_true(preflight.finalization_ready)
  inspect(preflight.resource_count, content="2")
}

///|
test "skia text descriptor preflight consumes fallback and shaping resource plans" {
  let preflight = skia_text_descriptor_preflight(
    @core.FontSpec::new(size=18.0, weight=600, style=@core.FontStyle::Italic),
    "MoUI",
  )
  assert_true(preflight.family_count > 0)
  inspect(preflight.fallback_character, content="77")
  assert_true(preflight.fallback_ready)
  inspect(preflight.fallback_resource_count, content="2")
  assert_true(preflight.measurement_ready)
  inspect(preflight.measurement_resource_count, content="4")
  assert_true(preflight.shaping_ready)
  inspect(preflight.shaping_resource_count, content="4")
  assert_true(preflight.shaped_run_ready)
  inspect(preflight.shaped_run_resource_count, content="5")
  assert_true(preflight.glyph_run_ready)
  inspect(preflight.glyph_run_resource_count, content="6")
}

///|
test "skia font fallback request prefers emoji and non-ascii representative characters" {
  inspect(skia_representative_fallback_codepoint(""), content="0")
  inspect(skia_representative_fallback_codepoint("MoUI"), content="77")
  inspect(skia_representative_fallback_codepoint("A你B"), content="20320")
  inspect(
    skia_representative_fallback_codepoint("A\u{1F642}B"),
    content="128578",
  )
  inspect(
    skia_representative_fallback_codepoint("A\u{2615}\u{FE0F}B"),
    content="9749",
  )
  inspect(
    skia_representative_fallback_codepoint("A\u{1F469}\u{200D}\u{1F373}B"),
    content="128105",
  )
}

///|
fn assert_skia_fallback_languages(
  text : String,
  expected : Array[Bytes],
) -> Unit raise {
  let request = skia_font_fallback_request(@core.FontSpec::new(size=18.0), text)
  inspect(request.language_count(), content="\{expected.length()}")
  for index in 0..<expected.length() {
    assert_true(request.language_at(index) == Some(expected[index]))
  }
  assert_true(request.language_at(expected.length()) is None)
}

///|
test "skia font fallback request records script language tags" {
  assert_skia_fallback_languages("", [])
  assert_skia_fallback_languages("MoUI", [b"en"])
  assert_skia_fallback_languages("A你B", [b"zh-Hans", b"en"])
  assert_skia_fallback_languages("A\u{3042}B", [b"ja", b"en"])
  assert_skia_fallback_languages("A\u{D55C}B", [b"ko", b"en"])
  assert_skia_fallback_languages("A\u{05D0}B", [b"he", b"en"])
  assert_skia_fallback_languages("A\u{0628}B", [b"ar", b"en"])
  assert_skia_fallback_languages("A\u{0915}B", [b"hi", b"en"])
  assert_skia_fallback_languages("A\u{0E01}B", [b"th", b"en"])
  assert_skia_fallback_languages("A\u{0E81}B", [b"lo", b"en"])
  assert_skia_fallback_languages("A\u{0D9A}B", [b"si", b"en"])
  assert_skia_fallback_languages("A\u{1780}B", [b"km", b"en"])
  assert_skia_fallback_languages("A\u{1000}B", [b"my", b"en"])
  assert_skia_fallback_languages("A\u{1F642}B", [b"und-Zsye", b"en"])
}

///|
test "skia text visual order proof records rtl glyph layout evidence" {
  guard skia_available() else { return () }
  guard skia_text_visual_order_proof("ABC \u{05D0}\u{05D1}\u{05D2} 123")
    is Some(proof) else {
    fail("expected Skia visual order proof")
  }
  inspect(proof.logical_text, content="ABC \u{05D0}\u{05D1}\u{05D2} 123")
  inspect(proof.visual_text, content="ABC \u{05D2}\u{05D1}\u{05D0} 123")
  assert_true(proof.visual_order_differs)
  assert_true(proof.logical_cluster_count == proof.visual_cluster_count)
  assert_true(proof.segment_count >= 3)
  assert_true(proof.glyph_count >= 6)
  assert_true(proof.width > 0.0)
}

///|
test "skia font fallback request preserves family chain style and coverage character" {
  let font = @core.FontSpec::new(
    families=@core.FontFamilyStack::system_ui().with_fallback(
      @core.FontFamily::Emoji,
    ),
    size=18.0,
    weight=650,
    style=@core.FontStyle::Italic,
  )
  let request = skia_font_fallback_request(font, "A\u{1F642}B")
  inspect(request.character, content="128578")
  assert_true(request.has_character())
  inspect(request.language_count(), content="2")
  assert_true(request.language_at(0) == Some(b"und-Zsye"))
  assert_true(request.language_at(1) == Some(b"en"))
  assert_true(request.families.length() >= 2)
  assert_true(request.families.family_at(0) == Some(b"Helvetica Neue"))
  assert_true(request.families.contains_family(b"Apple Color Emoji"))
  inspect(request.style.weight, content="650")
  inspect(request.style.width, content="5")
  inspect(request.style.slant, content="1")
  assert_true(request.resource_key().kind == @moui_skia.TypefaceResource)
  assert_true(
    request.font_descriptor(size=18.0).resource_key().kind ==
    @moui_skia.FontResource,
  )
}

///|
test "skia text descriptor preflight keeps empty text cacheable" {
  let preflight = skia_text_descriptor_preflight(
    @core.FontSpec::new(size=12.0, weight=400),
    "",
  )
  assert_true(preflight.fallback_ready)
  assert_true(preflight.measurement_ready)
  assert_true(preflight.shaping_ready)
  assert_true(preflight.shaped_run_ready)
  assert_true(preflight.glyph_run_ready)
}

///|
test "skia text maturity preflight separates covered baseline from gaps" {
  let preflight = skia_text_maturity_preflight()
  assert_true(preflight.descriptor_ready)
  assert_true(preflight.fallback_request_ready)
  assert_true(preflight.shaped_cluster_caret_ready)
  assert_true(preflight.fallback_cluster_caret_ready)
  assert_true(preflight.emoji_hint_ready)
  assert_true(preflight.empty_typeface_emoji_retry_disabled)
  assert_true(preflight.missing_glyph_recovery_ready)
  assert_false(preflight.bidi_reordering_ready)
  assert_false(preflight.paragraph_line_breaking_ready)
  assert_true(preflight.mixed_run_font_fallback_ready)
  assert_false(preflight.deterministic_color_emoji_ready)
  assert_true(preflight.unicode_17_grapheme_boundary_ready)
  inspect(preflight.ready_count, content="9")
  inspect(preflight.gap_count, content="3")
  assert_true(preflight.summary().contains("text maturity audit partial"))
  assert_true(preflight.summary().contains("mixed-run fallback ready"))
  assert_true(preflight.summary().contains("missing-glyph recovery ready"))
  assert_true(
    preflight.summary().contains("Unicode 17 grapheme boundary contract ready"),
  )
  assert_true(preflight.summary().contains("bidi"))
}

///|
test "skia font resolver maps MoUI font families to platform candidates" {
  assert_true(
    skia_font_family_candidates(@core.FontFamily::Name("Acme Sans")) ==
    ["Acme Sans"],
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::SystemUi).contains(
      "Helvetica Neue",
    ),
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::SansSerif).contains(
      "Segoe UI",
    ),
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::Serif).contains(
      "Times New Roman",
    ),
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::UiMonospace).contains("Menlo"),
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::Emoji).contains(
      "Apple Color Emoji",
    ),
  )
  assert_true(skia_font_slant(@core.FontStyle::Normal) == 0)
  assert_true(skia_font_slant(@core.FontStyle::Italic) == 1)
}

///|
test "skia brush shader maps radial gradients when native Skia is linked" {
  let radial = @core.Brush::radial_gradient(
    center=@core.Point::new(x=12.0, y=10.0),
    radius=8.0,
    center_color=@core.Color::blue(),
    edge_color=@core.Color::gray(),
  )
  assert_true(
    skia_brush_shader(@core.Brush::solid(@core.Color::blue())) is None,
  )
  if skia_available() {
    assert_true(skia_brush_shader(radial) is Some(_))
  } else {
    assert_true(skia_brush_shader(radial) is None)
  }
}

///|
test "skia emoji hints cover representative diagnostic samples" {
  assert_true(skia_text_contains_emoji_hint("\u{1F642}"))
  assert_true(skia_text_contains_emoji_hint("\u{2615}\u{FE0F}"))
  assert_true(skia_text_contains_emoji_hint("\u{1F469}\u{200D}\u{1F373}"))
  assert_false(skia_text_contains_emoji_hint("Plain MoUI"))
}

///|
test "skia emoji fallback is limited to the system font manager path" {
  let font = @core.FontSpec::new(size=18.0, weight=400)
  assert_true(
    skia_emoji_fallback_draw_font(
      font,
      "\u{1F642}",
      SkiaFontResolution::EmptyTypeface,
    )
    is None,
  )
  assert_true(
    skia_emoji_fallback_draw_font(
      font,
      "Plain MoUI",
      SkiaFontResolution::SystemFontMgr,
    )
    is None,
  )
  match
    skia_emoji_fallback_draw_font(
      font,
      "\u{1F642}",
      SkiaFontResolution::SystemFontMgr,
    ) {
    Some(emoji_font) => assert_true(emoji_font.size() == 18.0)
    None =>
      assert_true(!skia_available() || skia_system_emoji_font(font) is None)
  }
}

///|
test "skia font resolver preserves fallback availability" {
  match skia_test_font(@core.FontSpec::new(size=14.0, weight=400)) {
    Some(font) => assert_true(font.size() == 14.0)
    None => assert_true(!skia_available())
  }
  let missing = @core.FontSpec::new(
    families=@core.FontFamilyStack::named("Definitely Missing MoUI Font"),
    size=15.0,
    weight=700,
    style=@core.FontStyle::Italic,
  )
  match skia_test_font(missing) {
    Some(font) => assert_true(font.size() == 15.0)
    None => assert_true(!skia_available())
  }
}

///|
fn skia_test_native_text_available() -> Bool {
  match skia_test_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => skia_test_font_has_visible_text(font, "Slim")
    None => false
  }
}

///|
fn skia_test_font_has_visible_text(
  font : @skia_native.Font,
  text : String,
) -> Bool {
  skia_measure_text_width(font, text) > 0.0 &&
  skia_glyph_run_has_visible_glyphs(skia_glyph_run(font, text))
}

///|
fn skia_test_region_has_dark_pixel(
  frame : SkiaPixelFrame,
  rect : @core.Rect,
) -> Bool {
  skia_test_region_has_matching_pixel(frame, rect, (r, g, b, a) => {
    a > 0 && r < 210 && g < 210 && b < 210
  })
}

///|
fn skia_test_region_has_matching_pixel(
  frame : SkiaPixelFrame,
  rect : @core.Rect,
  matches : (Int, Int, Int, Int) -> Bool,
) -> Bool {
  let min_x = rect.origin.x.floor().to_int().max(0)
  let min_y = rect.origin.y.floor().to_int().max(0)
  let max_x = (rect.origin.x + rect.size.width).ceil().to_int().min(frame.width)
  let max_y = (rect.origin.y + rect.size.height)
    .ceil()
    .to_int()
    .min(frame.height)
  for y in min_y..<max_y {
    for x in min_x..<max_x {
      let offset = y * frame.row_bytes + x * 4
      if offset + 3 < frame.pixels.length() {
        let actual_r = frame.pixels[offset].to_int()
        let actual_g = frame.pixels[offset + 1].to_int()
        let actual_b = frame.pixels[offset + 2].to_int()
        let actual_a = frame.pixels[offset + 3].to_int()
        if matches(actual_r, actual_g, actual_b, actual_a) {
          return true
        }
      }
    }
  }
  false
}

///|
fn skia_test_font(font : @core.FontSpec) -> @skia_native.Font? {
  skia_font_with_resolution_for_text(
    font,
    "",
    SkiaFontResolution::SystemFontMgr,
  )
}

///|
test "skia empty typeface resolution avoids system font manager" {
  let font_spec = @core.FontSpec::new(size=14.0, weight=400)
  match
    skia_font_with_resolution_for_text(
      font_spec,
      "",
      SkiaFontResolution::EmptyTypeface,
    ) {
    None => assert_true(!skia_available())
    Some(font) => {
      assert_true(font.size() == 14.0)
      let run = skia_glyph_run_with_shaper(font, "Slim", use_shaper=false)
      assert_true(run.glyphs.length() == run.positions.length())
      assert_true(run.clusters.is_empty())
    }
  }
}

///|
test "skia empty typeface drawing falls back when the glyph run is blank" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=1.0, height=1.0),
    ),
    target,
    font_resolution=SkiaFontResolution::EmptyTypeface,
  ) catch {
    _ => return ()
  }
  ignore(renderer)
  match
    skia_draw_text_payload_for_resolution(
      @core.FontSpec::new(size=18.0, weight=400),
      "Slim",
      SkiaFontResolution::EmptyTypeface,
    ) {
    Some((font, run)) => {
      assert_true(font.size() == 18.0)
      assert_true(skia_glyph_run_has_visible_glyphs(run))
    }
    None => assert_false(skia_test_native_text_available())
  }
}

///|
test "skia text drawing clips glyphs to the TextRun frame" {
  guard skia_test_native_text_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=96.0, height=36.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="MMMMMMMM",
        frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=36.0),
        font=@core.FontSpec::new(size=18.0, weight=400),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
  ]) catch {
    err => fail("expected Skia text render: \{err.message()}")
  }
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_false(
    skia_test_region_has_dark_pixel(
      frame,
      @core.Rect::new(x=8.0, y=0.0, width=84.0, height=36.0),
    ),
  )
}

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
    @render.RendererSurfaceMetrics::from_logical(
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
test "skia renderer decodes jpeg and bmp local files through encoded image api" {
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
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    SkiaPresentTarget::new(description="test", present=_ => true),
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }

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
test "skia renderer dispose clears cached image resources and records disposal" {
  guard skia_available() else { return () }
  let source = skia_test_png_data_uri()
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
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
test "skia renderer notifies image lifecycle revisions for ready and disposed resources" {
  guard skia_available() else { return () }
  let source = skia_test_png_data_uri()
  let revisions : Array[Int] = []
  let record_counts : Array[Int] = []
  let statuses : Array[@render.ImageResourceStatus] = []
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
    on_image_resource_change=Some(snapshot => {
      revisions.push(snapshot.revision)
      record_counts.push(snapshot.records.length())
      if snapshot.records.length() > 0 {
        statuses.push(snapshot.records[0].status)
      }
    }),
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
  assert_true(revisions == [1, 2])
  assert_true(record_counts == [1, 1])
  assert_true(
    statuses ==
    [
      @render.ImageResourceStatus::ImageLoading,
      @render.ImageResourceStatus::ImageReady,
    ],
  )

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
  inspect(revisions.length(), content="2")

  renderer.dispose()
  assert_true(revisions == [1, 2, 3])
  assert_true(record_counts == [1, 1, 1])
  assert_true(
    statuses ==
    [
      @render.ImageResourceStatus::ImageLoading,
      @render.ImageResourceStatus::ImageReady,
      @render.ImageResourceStatus::ImageDisposed,
    ],
  )
}

///|
test "skia renderer applies image load completions and notifies revision callbacks" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.mark_image_loading("async.png")
  let revisions : Array[Int] = []
  let async_statuses : Array[@render.ImageResourceStatus] = []
  let missing_statuses : Array[@render.ImageResourceStatus] = []
  renderer.set_image_resource_change_callback(
    Some(snapshot => {
      revisions.push(snapshot.revision)
      for record in snapshot.records {
        if record.source == "async.png" {
          async_statuses.push(record.status)
        } else if record.source == "missing.png" {
          missing_statuses.push(record.status)
        }
      }
    }),
  )
  let ready = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::ready("async.png", width=18, height=10),
  )
  inspect(ready.revision, content="2")
  assert_true(revisions == [2])
  assert_true(async_statuses == [@render.ImageResourceStatus::ImageReady])
  let stale = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::failed(
      "async.png",
      diagnostic="late failure",
    ),
  )
  inspect(stale.revision, content="2")
  inspect(revisions.length(), content="1")
  renderer.mark_image_loading("missing.png")
  let failed = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::failed(
      "missing.png",
      diagnostic="decode failed",
    ),
  )
  inspect(failed.revision, content="4")
  inspect(revisions.length(), content="3")
  assert_true(
    missing_statuses ==
    [
      @render.ImageResourceStatus::ImageLoading,
      @render.ImageResourceStatus::ImageFailed,
    ],
  )
  assert_true(renderer.failed_images.get("missing.png") is Some(_))
}

///|
test "skia renderer async image loading waits for explicit completion before caching" {
  guard skia_available() else { return () }
  let source = skia_test_png_data_uri()
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
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
  inspect(completed.revision, content="2")
  guard renderer.image_lifecycle.lookup(source) is Some(ready) else {
    fail("expected ready image lifecycle record")
  }
  assert_true(ready.status == @render.ImageResourceStatus::ImageReady)
  assert_true(renderer.image_cache.get(source) is None)

  renderer.render(commands) catch {
    err => fail("expected Skia async second-frame render: \{err.message()}")
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
    @render.RendererSurfaceMetrics::from_logical(
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
test "skia renderer notifies failed image lifecycle revision once for unchanged failed cache" {
  guard skia_available() else { return () }
  let missing_source = "moui-skia-missing-image-resource://not-a-file"
  let callback_count = Ref(0)
  let revisions : Array[Int] = []
  let record_counts : Array[Int] = []
  let statuses : Array[@render.ImageResourceStatus] = []
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.set_image_resource_change_callback(
    Some(snapshot => {
      callback_count.val = callback_count.val + 1
      revisions.push(snapshot.revision)
      record_counts.push(snapshot.records.length())
      if snapshot.records.length() > 0 {
        statuses.push(snapshot.records[0].status)
      }
    }),
  )

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
  inspect(callback_count.val, content="1")
  assert_true(revisions == [1])
  assert_true(record_counts == [1])
  assert_true(statuses == [@render.ImageResourceStatus::ImageFailed])

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
  inspect(callback_count.val, content="1")
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
    @render.RendererSurfaceMetrics::from_logical(
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
    err => fail("expected Skia placeholder render: \{err.message()}")
  }
  assert_true(renderer.image_cache.get(source) is None)
  assert_true(renderer.failed_images.get(source) is Some(_))
  guard renderer.image_lifecycle.lookup(source) is Some(failed) else {
    fail("expected failed local image lifecycle record")
  }
  assert_true(failed.status == @render.ImageResourceStatus::ImageFailed)

  match skia_image_data_uri_bytes(skia_test_png_data_uri()) {
    Some(bytes) =>
      @fs.write_bytes_to_file(source, bytes) catch {
        _ => fail("expected local image retry fixture write")
      }
    None => fail("expected embedded test PNG bytes")
  }
  renderer.render([
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]) catch {
    err => fail("expected Skia retry image render: \{err.message()}")
  }
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

///|
test "skia renderer resize updates presented frame metrics" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=3.0, height=2.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=6.0),
      scale_factor=2.0,
    ),
  ) catch {
    err => fail("expected Skia renderer resize: \{err.message()}")
  }
  renderer.render([@core.DrawCommand::Clear(@core.Color::white())]) catch {
    err => fail("expected Skia renderer render: \{err.message()}")
  }
  guard renderer.last_frame() is Some(frame) else {
    fail("expected Skia renderer to keep last frame after render")
  }
  inspect(frame.width, content="16")
  inspect(frame.height, content="12")
  inspect(frame.scale_factor, content="2")
  inspect(renderer.present_count(), content="1")
}

///|
test "skia renderer reports presenter failure without counting present" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="failing-presenter", present=_ => {
    false
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let result = try? renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
  ])
  match result {
    Err(SkiaRendererError::PresentFailed(description)) =>
      inspect(description, content="failing-presenter")
    _ => fail("expected Skia presenter failure")
  }
  inspect(renderer.present_count(), content="0")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected failed presentation to keep rendered frame for diagnostics")
  }
  inspect(frame.width, content="4")
  inspect(frame.height, content="4")
}

///|
test "skia unmatched scope pops are ignored and counted" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopRoundedClip,
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::PopOpacity,
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::black(),
    ),
  ]) catch {
    err =>
      fail("expected Skia renderer to ignore unmatched pops: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="6")
  let diagnostics = renderer.unsupported_command_diagnostics()
  inspect(diagnostics.length(), content="6")
  inspect(diagnostics[0].command, content="PopClip")
  assert_true(diagnostics[0].reason.contains("no matching push"))
  inspect(diagnostics[5].command, content="PopFilter")
  inspect(renderer.present_count(), content="1")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  inspect(frame.width, content="8")
  inspect(frame.height, content="8")
}

///|
test "skia mismatched scope pop preserves the active scope" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=12.0, height=8.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=8.0),
    ),
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=12.0, height=8.0),
      @core.Color::black(),
    ),
    @core.DrawCommand::PopClip,
  ]) catch {
    err =>
      fail("expected Skia renderer to ignore mismatched pop: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="1")
  let diagnostics = renderer.unsupported_command_diagnostics()
  inspect(diagnostics.length(), content="1")
  inspect(diagnostics[0].command, content="PopTransform")
  assert_true(diagnostics[0].reason.contains("active clip scope"))
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      frame,
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=8.0),
    ),
  )
  assert_false(
    skia_test_region_has_dark_pixel(
      frame,
      @core.Rect::new(x=6.0, y=0.0, width=4.0, height=8.0),
    ),
  )
}

///|
test "skia unclosed scopes are counted and restored at frame boundary" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=12.0, height=8.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=8.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=12.0, height=8.0),
      @core.Color::black(),
    ),
  ]) catch {
    err =>
      fail("expected Skia renderer to restore unclosed clip: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="1")
  let diagnostics = renderer.unsupported_command_diagnostics()
  inspect(diagnostics.length(), content="1")
  inspect(diagnostics[0].command, content="PushClip")
  assert_true(diagnostics[0].reason.contains("open clip scope"))
  guard renderer.last_frame() is Some(clipped_frame) else {
    fail("expected clipped rendered frame")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      clipped_frame,
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=8.0),
    ),
  )
  assert_false(
    skia_test_region_has_dark_pixel(
      clipped_frame,
      @core.Rect::new(x=6.0, y=0.0, width=4.0, height=8.0),
    ),
  )

  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=12.0, height=8.0),
      @core.Color::black(),
    ),
  ]) catch {
    err =>
      fail("expected next Skia frame after unclosed clip: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  inspect(renderer.unsupported_command_diagnostics().length(), content="0")
  inspect(renderer.present_count(), content="2")
  guard renderer.last_frame() is Some(restored_frame) else {
    fail("expected restored rendered frame")
  }
  assert_true(
    skia_test_region_has_dark_pixel(
      restored_frame,
      @core.Rect::new(x=6.0, y=0.0, width=4.0, height=8.0),
    ),
  )
}

///|
test "skia unsupported command diagnostics reset per frame" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="missing-shader",
        frame=@core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
        fallback=@core.Brush::solid(@core.Color::blue()),
      ),
    ),
  ]) catch {
    err => fail("expected Skia fallback render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="1")
  let diagnostics = renderer.unsupported_command_diagnostics()
  inspect(diagnostics.length(), content="1")
  inspect(diagnostics[0].command, content="DrawShaderEffect")
  assert_true(diagnostics[0].reason.contains("missing-shader"))
  assert_true(diagnostics[0].reason.contains("fallback brush"))
  inspect(renderer.present_count(), content="1")
  renderer.render([@core.DrawCommand::Clear(@core.Color::white())]) catch {
    err => fail("expected Skia supported render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  inspect(renderer.unsupported_command_diagnostics().length(), content="0")
  inspect(renderer.present_count(), content="2")
}

///|
test "skia color matrix normalizes short and long payloads" {
  let identity = skia_color_filter_matrix_values([])
  inspect(identity.length(), content="20")
  inspect(identity[0], content="1")
  inspect(identity[6], content="1")
  inspect(identity[12], content="1")
  inspect(identity[18], content="1")
  inspect(identity[1], content="0")
  inspect(identity[19], content="0")

  let short = skia_color_filter_matrix_values([0.25, 0.5])
  inspect(short.length(), content="20")
  inspect(short[0], content="0.25")
  inspect(short[1], content="0.5")
  inspect(short[6], content="1")
  inspect(short[12], content="1")
  inspect(short[18], content="1")

  let long = skia_color_filter_matrix_values([
    0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0,
    15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0,
  ])
  inspect(long.length(), content="20")
  inspect(long[0], content="0")
  inspect(long[18], content="18")
  inspect(long[19], content="19")
}

///|
test "skia renderer composites masked opacity layer pixels" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=24.0, height=24.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(
        opacity=0.5,
        mask=@core.LayerMask::RectMask(
          @core.Rect::new(x=4.0, y=4.0, width=12.0, height=12.0),
        ),
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=24.0, height=24.0),
      @core.Color::black(),
    ),
    @core.DrawCommand::PopLayer,
  ]) catch {
    err => fail("expected Skia masked layer render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  inspect(renderer.present_count(), content="1")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=8.0, y=8.0, width=4.0, height=4.0),
      (r, g, b, a) => {
        a > 0 && r > 80 && r < 220 && g > 80 && g < 220 && b > 80 && b < 220
      },
    ),
  )
  assert_false(
    skia_test_region_has_dark_pixel(
      frame,
      @core.Rect::new(x=0.0, y=0.0, width=3.0, height=3.0),
    ),
  )
}

///|
test "skia renderer paints blend and saturation filter pixels" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=32.0, height=16.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(blend_mode=@core.BlendMode::Multiply),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
      @core.Color::rgba(r=0.0, g=0.0, b=1.0),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PushFilter(@core.FilterEffect::Saturate(0.0)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=16.0, y=0.0, width=16.0, height=16.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0),
    ),
    @core.DrawCommand::PopFilter,
  ]) catch {
    err => fail("expected Skia blend/filter render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  inspect(renderer.present_count(), content="1")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=4.0, y=4.0, width=8.0, height=8.0),
      (r, g, b, a) => a > 0 && r < 80 && g < 80 && b < 80,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=20.0, y=4.0, width=8.0, height=8.0),
      (r, g, b, a) => {
        a > 0 && r > 25 && r < 120 && g > 25 && g < 120 && b > 25 && b < 120
      },
    ),
  )
}

///|
test "skia renderer paints path fill and stroke pixels" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=40.0, height=40.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=6.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=32.0, y=6.0)),
          @core.PathVerb::QuadTo(
            @core.Point::new(x=36.0, y=18.0),
            @core.Point::new(x=30.0, y=32.0),
          ),
          @core.PathVerb::CubicTo(
            @core.Point::new(x=22.0, y=36.0),
            @core.Point::new(x=12.0, y=34.0),
            @core.Point::new(x=6.0, y=28.0),
          ),
          @core.PathVerb::Close,
        ],
        fill=Some(@core.Brush::solid(@core.Color::rgba(r=0.95, g=0.08, b=0.08))),
        stroke=Some(@core.Brush::solid(@core.Color::black())),
        stroke_width=2.0,
      ),
    ),
  ]) catch {
    err => fail("expected Skia path render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  inspect(renderer.present_count(), content="1")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=14.0, y=14.0, width=12.0, height=12.0),
      (r, g, b, a) => a > 0 && r > 180 && g < 120 && b < 120,
    ),
  )
  assert_true(
    skia_test_region_has_dark_pixel(
      frame,
      @core.Rect::new(x=5.0, y=5.0, width=28.0, height=4.0),
    ),
  )
}

///|
test "skia renderer paints path linear gradient pixels" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=40.0, height=20.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=2.0, y=2.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=38.0, y=2.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=38.0, y=18.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=2.0, y=18.0)),
          @core.PathVerb::Close,
        ],
        fill=Some(
          @core.Brush::linear_gradient(
            start=@core.Point::new(x=2.0, y=0.0),
            end=@core.Point::new(x=38.0, y=0.0),
            start_color=@core.Color::rgba(r=0.95, g=0.05, b=0.05),
            end_color=@core.Color::rgba(r=0.05, g=0.10, b=0.95),
          ),
        ),
      ),
    ),
  ]) catch {
    err => fail("expected Skia path gradient render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=5.0, y=8.0, width=6.0, height=4.0),
      (r, g, b, a) => a > 0 && r > 150 && g < 140 && b < 120,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=29.0, y=8.0, width=6.0, height=4.0),
      (r, g, b, a) => a > 0 && b > 150 && r < 120 && g < 140,
    ),
  )
}

///|
test "skia renderer paints radial gradient brush pixels" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=24.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=2.0, y=2.0, width=20.0, height=20.0),
        radius=10.0,
      ),
      @core.Brush::radial_gradient(
        center=@core.Point::new(x=12.0, y=12.0),
        radius=10.0,
        center_color=@core.Color::rgba(r=0.95, g=0.05, b=0.05),
        edge_color=@core.Color::rgba(r=0.05, g=0.10, b=0.95),
      ),
    ),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=26.0, y=2.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=46.0, y=2.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=46.0, y=22.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=26.0, y=22.0)),
          @core.PathVerb::Close,
        ],
        fill=Some(
          @core.Brush::radial_gradient(
            center=@core.Point::new(x=36.0, y=12.0),
            radius=10.0,
            center_color=@core.Color::rgba(r=0.05, g=0.85, b=0.18),
            edge_color=@core.Color::black(),
          ),
        ),
      ),
    ),
  ]) catch {
    err => fail("expected Skia radial gradient render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=10.0, y=10.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && r > 150 && g < 130 && b < 130,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=19.0, y=10.0, width=3.0, height=4.0),
      (r, _, b, a) => a > 0 && b > 130 && r < 150,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=34.0, y=10.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && g > 130 && r < 130 && b < 130,
    ),
  )
}

///|
test "skia renderer paints built-in shader effect pixels" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=24.0, height=16.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="checker",
        frame=@core.Rect::new(x=0.0, y=0.0, width=24.0, height=16.0),
        uniforms=[4.0],
        fallback=@core.Brush::linear_gradient(
          start=@core.Point::new(x=0.0, y=0.0),
          end=@core.Point::new(x=24.0, y=0.0),
          start_color=@core.Color::rgba(r=0.95, g=0.05, b=0.05),
          end_color=@core.Color::rgba(r=0.05, g=0.20, b=0.95),
        ),
      ),
    ),
  ]) catch {
    err => fail("expected Skia shader effect render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=1.0, y=1.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && r > 180 && g < 100 && b < 100,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=7.0, y=1.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && r < 100 && g < 120 && b > 180,
    ),
  )
}

///|
test "skia renderer paints shader gradient and vignette pixels" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=24.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="linear-gradient-debug",
        frame=@core.Rect::new(x=0.0, y=0.0, width=24.0, height=24.0),
        fallback=@core.Brush::linear_gradient(
          start=@core.Point::new(x=0.0, y=0.0),
          end=@core.Point::new(x=24.0, y=0.0),
          start_color=@core.Color::rgba(r=0.95, g=0.05, b=0.05),
          end_color=@core.Color::rgba(r=0.05, g=0.10, b=0.95),
        ),
      ),
    ),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="vignette",
        frame=@core.Rect::new(x=24.0, y=0.0, width=24.0, height=24.0),
        uniforms=[1.0],
        fallback=@core.Brush::solid(@core.Color::rgba(r=0.05, g=0.85, b=0.20)),
      ),
    ),
  ]) catch {
    err => fail("expected Skia shader variant render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=2.0, y=10.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && r > 150 && g < 140 && b < 120,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=18.0, y=10.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && b > 150 && r < 120 && g < 140,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=34.0, y=10.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && g > 130 && r < 120 && b < 120,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=45.0, y=0.0, width=3.0, height=3.0),
      (r, g, b, a) => a > 0 && r < 80 && g < 80 && b < 80,
    ),
  )
}

///|
test "skia text baseline is centered in taller text frames" {
  let frame = @core.Rect::new(x=4.0, y=10.0, width=120.0, height=44.0)
  let metrics = SkiaTextMetrics::{ baseline: 12.0, height: 20.0 }
  inspect(skia_text_baseline_y(frame, metrics), content="34")
}

///|
test "skia text placement clips to the TextRun frame" {
  let frame = @core.Rect::new(x=20.0, y=4.0, width=100.0, height=30.0)
  let run = @core.TextRun::new(
    text="Bounded",
    frame~,
    font=@core.FontSpec::new(size=16.0),
    color=@core.Color::black(),
    align=@core.TextAlign::TextEnd,
  )
  let glyph_run = SkiaGlyphRun::{
    glyphs: [@skia_native.GlyphId::new(10)],
    positions: [@moui_skia.Point::zero()],
    clusters: [0],
    width: 70.0,
  }
  let placement = skia_text_placement(run, glyph_run, SkiaTextMetrics::{
    baseline: 10.0,
    height: 20.0,
  })
  assert_true(placement.clip == frame)
  inspect(placement.origin.x.to_double(), content="50")
  inspect(placement.origin.y.to_double(), content="19")
}

///|
test "skia text draw skips non-positive text frames" {
  assert_true(
    skia_text_frame_can_draw(
      @core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
    ),
  )
  assert_false(
    skia_text_frame_can_draw(
      @core.Rect::new(x=0.0, y=0.0, width=0.0, height=1.0),
    ),
  )
  assert_false(
    skia_text_frame_can_draw(
      @core.Rect::new(x=0.0, y=0.0, width=1.0, height=0.0),
    ),
  )
}

///|
test "skia empty typeface text system follows drawing fallback font metrics" {
  let input = @core.TextLayoutInput::new(
    text="你好 MoUI",
    font=@core.FontSpec::new(size=18.0, weight=400),
  )
  let system = skia_text_system(resolution=SkiaFontResolution::EmptyTypeface)
  if !skia_available() {
    assert_true(system.id() == @core.TextSystem::fallback().id())
  } else {
    assert_true(system.id() == "skia-raster-empty-typeface-text-system")
    match
      skia_resolved_text_layout_for_resolution(
        input.font,
        input.text,
        SkiaFontResolution::EmptyTypeface,
      ) {
      Some(layout) => {
        let measured = system.measure_text(input)
        assert_true(measured.size.width == layout.width)
        assert_true(
          measured.caret_positions[input.text.to_array().length()] ==
          layout.width,
        )
        assert_true(layout.segments.length() > 0)
      }
      None => {
        let measured = system.measure_text(input)
        let fallback = @core.TextSystem::fallback().measure_text(input)
        assert_true(measured == fallback)
      }
    }
  }
}

///|
test "skia text system exposes measured caret positions" {
  match skia_test_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let input = @core.TextLayoutInput::new(
        text="Slim",
        font=@core.FontSpec::new(size=18.0, weight=400),
      )
      let fallback = @core.TextSystem::fallback().measure_text(input)
      let glyph_run = skia_glyph_run(font, input.text)
      let layout = skia_text_layout_result(font, input, fallback, glyph_run~)
      inspect(layout.caret_positions.length(), content="5")
      inspect(layout.caret_positions[0], content="0")
      if skia_test_font_has_visible_text(font, "Slim") {
        assert_true(layout.size.width == skia_measure_text_width(font, "Slim"))
        assert_true(layout.caret_positions[4] == layout.size.width)
        assert_true(layout.baseline > 0.0)
        assert_true(layout.size.height >= layout.baseline)
        assert_true(layout.caret_positions[1] > 0.0)
        assert_true(layout.caret_positions[2] > layout.caret_positions[1])
      } else {
        assert_true(layout == fallback)
      }
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia mixed text segmentation preserves grapheme clusters" {
  let clusters = skia_grapheme_cluster_texts(
    "A\u{1F469}\u{200D}\u{1F4BB}B\u{1F1FA}\u{1F1F8}",
  )
  inspect(clusters.length(), content="4")
  inspect(clusters[0], content="A")
  inspect(clusters[1].to_array().length(), content="3")
  inspect(clusters[2], content="B")
  inspect(clusters[3].to_array().length(), content="2")

  let indic_clusters = skia_grapheme_cluster_texts("क़्ष")
  inspect(indic_clusters.length(), content="1")
  inspect(indic_clusters[0].to_array().length(), content="4")
  let indic_latin_clusters = skia_grapheme_cluster_texts("क़्A")
  inspect(indic_latin_clusters.length(), content="2")
  inspect(indic_latin_clusters[0].to_array().length(), content="3")
  inspect(indic_latin_clusters[1], content="A")
  let musical_clusters = skia_grapheme_cluster_texts("A\u{1D165}B")
  inspect(musical_clusters.length(), content="2")
  inspect(musical_clusters[0].to_array().length(), content="2")
  inspect(musical_clusters[1], content="B")

  let segments = skia_mixed_text_segments("AB你好\u{1F642}CD")
  inspect(segments.length(), content="4")
  inspect(segments[0], content="AB")
  inspect(segments[1], content="你好")
  inspect(segments[2], content="\u{1F642}")
  inspect(segments[3], content="CD")

  let indic_segments = skia_mixed_text_segments("Aक़्षB")
  inspect(indic_segments.length(), content="3")
  inspect(indic_segments[0], content="A")
  inspect(indic_segments[1], content="क़्ष")
  inspect(indic_segments[2], content="B")

  let musical_segments = skia_mixed_text_segments("A\u{1D165}B")
  inspect(musical_segments.length(), content="2")
  inspect(musical_segments[0].to_array().length(), content="2")
  inspect(musical_segments[1], content="B")
}

///|
fn skia_test_core_grapheme_cluster_texts(text : String) -> Array[String] {
  let chars = text.to_array()
  let boundaries = @core.TextGraphemeBoundaries::new(text~).boundaries()
  let clusters : Array[String] = []
  if boundaries.length() < 2 {
    return clusters
  }
  for boundary_index in 0..<(boundaries.length() - 1) {
    let start = boundaries[boundary_index]
    let end = boundaries[boundary_index + 1]
    clusters.push(String::from_array(chars[start:end]))
  }
  clusters
}

///|
fn assert_skia_grapheme_clusters_match_core(
  text : String,
  expected_boundaries : Array[Int],
) -> Unit raise {
  let boundaries = @core.TextGraphemeBoundaries::new(text~).boundaries()
  if boundaries.length() != expected_boundaries.length() {
    fail(
      "expected \{expected_boundaries.length()} core grapheme boundaries, got \{boundaries.length()}",
    )
  }
  for index in 0..<expected_boundaries.length() {
    inspect(boundaries[index], content="\{expected_boundaries[index]}")
  }
  let expected = skia_test_core_grapheme_cluster_texts(text)
  let actual = skia_grapheme_cluster_texts(text)
  if actual.length() != expected.length() {
    fail(
      "expected \{expected.length()} Skia grapheme clusters, got \{actual.length()}",
    )
  }
  for index in 0..<expected.length() {
    inspect(actual[index], content=expected[index])
  }
}

///|
fn assert_skia_grapheme_utf8_offsets(
  text : String,
  indexes : Array[Int],
  expected : Array[Int],
) -> Unit raise {
  if indexes.length() != expected.length() {
    fail("expected matching index and utf8-offset fixture lengths")
  }
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  for index in 0..<indexes.length() {
    inspect(
      boundaries.utf8_offset(indexes[index]),
      content="\{expected[index]}",
    )
  }
}

///|
test "skia grapheme clustering follows core IME boundary contract" {
  assert_skia_grapheme_clusters_match_core("A\u{1F469}\u{200D}\u{1F4BB}B", [
    0, 1, 4, 5,
  ])
  assert_skia_grapheme_clusters_match_core(
    "A\u{1F3F4}\u{E0067}\u{E0062}\u{E007F}B",
    [0, 1, 5, 6],
  )
  assert_skia_grapheme_clusters_match_core("A1\u{FE0F}\u{20E3}B", [0, 1, 4, 5])
  assert_skia_grapheme_clusters_match_core("\u{1F1FA}\u{1F1F8}\u{1F1E8}", [
    0, 2, 3,
  ])
  assert_skia_grapheme_clusters_match_core("A\u{0600}B", [0, 1, 3])
  assert_skia_grapheme_clusters_match_core("A\u{0D4E}\u{0D15}B", [0, 1, 3, 4])
  assert_skia_grapheme_clusters_match_core("A\u{13430}\u{0301}B", [
    0, 1, 2, 3, 4,
  ])
  assert_skia_grapheme_clusters_match_core("A\u{1FC00}\u{200D}\u{1FC01}B", [
    0, 1, 4, 5,
  ])
  assert_skia_grapheme_clusters_match_core("A\u{0600}\u{0628}\u{0651}B", [
    0, 1, 4, 5,
  ])
  assert_skia_grapheme_clusters_match_core("A\u{1100}\u{1161}\u{11A8}B", [
    0, 1, 4, 5,
  ])
  assert_skia_grapheme_clusters_match_core("A\u{A960}\u{D7B0}\u{D7CB}B", [
    0, 1, 4, 5,
  ])
  assert_skia_grapheme_clusters_match_core("Aक्‍षB", [0, 1, 5, 6])
  assert_skia_grapheme_clusters_match_core("Aक़्षB", [0, 1, 5, 6])
  assert_skia_grapheme_clusters_match_core("Aक्‌षB", [0, 1, 4, 5, 6])
  assert_skia_grapheme_clusters_match_core("\u{094D}\u{0915}", [0, 1, 2])
  assert_skia_grapheme_clusters_match_core("a\u{094D}\u{0924}", [0, 2, 3])
  assert_skia_grapheme_clusters_match_core("A\u{1B32}\u{1B44}\u{1B2F}B", [
    0, 1, 4, 5,
  ])
  assert_skia_grapheme_clusters_match_core(
    "A\u{179F}\u{17D2}\u{178F}\u{17D2}\u{179A}\u{17B8}B",
    [0, 1, 7, 8],
  )
  assert_skia_grapheme_clusters_match_core("A\u{1000}\u{1039}\u{1001}B", [
    0, 1, 4, 5,
  ])
  assert_skia_grapheme_utf8_offsets(
    "A\u{1F469}\u{200D}\u{1F4BB}B",
    [0, 1, 4, 5],
    [0, 1, 12, 13],
  )
  assert_skia_grapheme_utf8_offsets("A1\u{FE0F}\u{20E3}B", [0, 1, 4, 5], [
    0, 1, 8, 9,
  ])
  assert_skia_grapheme_utf8_offsets(
    "A\u{1F3F4}\u{E0067}\u{E0062}\u{E007F}B",
    [0, 1, 5, 6],
    [0, 1, 17, 18],
  )
  assert_skia_grapheme_utf8_offsets("Aक्‍षB", [0, 1, 5, 6], [
    0, 1, 13, 14,
  ])
  assert_skia_grapheme_utf8_offsets("Aक्‌षB", [0, 1, 4, 5, 6], [
    0, 1, 10, 13, 14,
  ])
}

///|
test "skia resolved mixed text layout accumulates segment carets" {
  guard skia_available() else { return () }
  let text = "A你\u{1F642}B"
  let font = @core.FontSpec::new(
    families=@core.FontFamilyStack::system_ui().with_fallback(
      @core.FontFamily::Emoji,
    ),
    size=18.0,
    weight=400,
  )
  match
    skia_resolved_text_layout_for_resolution(
      font,
      text,
      SkiaFontResolution::SystemFontMgr,
    ) {
    Some(layout) => {
      inspect(layout.segments.length(), content="4")
      assert_true(layout.width > 0.0)
      assert_true(layout.metrics.baseline > 0.0)
      let carets = skia_resolved_text_caret_positions(text, layout)
      inspect(carets.length(), content="\{text.to_array().length() + 1}")
      assert_true(skia_test_carets_are_monotonic(carets))
      assert_true(carets[carets.length() - 1] == layout.width)

      let system = skia_text_system()
      let measured = system.measure_text(
        @core.TextLayoutInput::new(text~, font~),
      )
      assert_true(measured.size.width == layout.width)
      assert_true(
        measured.caret_positions[measured.caret_positions.length() - 1] ==
        layout.width,
      )
    }
    None => {
      let system = skia_text_system()
      let input = @core.TextLayoutInput::new(text~, font~)
      let measured = system.measure_text(input)
      let fallback = @core.TextSystem::fallback().measure_text(input)
      assert_true(measured == fallback)
    }
  }
}

///|
test "skia text drawing builds best available glyph runs" {
  match skia_test_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let run = skia_glyph_run(font, "Slim")
      if skia_test_font_has_visible_text(font, "Slim") {
        inspect(run.glyphs.length(), content="4")
        inspect(run.positions.length(), content="4")
        assert_true(run.width > 0.0)
        assert_true(run.positions[0] == @moui_skia.Point::zero())
        assert_true(run.positions[1].x > run.positions[0].x)
        assert_true(run.positions[2].x > run.positions[1].x)
        if @skia_native.skia_shaper_available() {
          assert_true(run.clusters.length() == run.glyphs.length())
        } else {
          assert_true(run.clusters.is_empty())
        }
      } else {
        assert_false(skia_glyph_run_has_visible_glyphs(run))
      }
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia missing glyph recovery requires improved fallback coverage" {
  let partial = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(12),
      @skia_native.GlyphId::new(0),
      @skia_native.GlyphId::new(0),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  let improved = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(12),
      @skia_native.GlyphId::new(13),
      @skia_native.GlyphId::new(0),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  let same = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(14),
      @skia_native.GlyphId::new(0),
      @skia_native.GlyphId::new(0),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  let complete = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(12),
      @skia_native.GlyphId::new(13),
      @skia_native.GlyphId::new(14),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  inspect(skia_glyph_run_missing_glyph_count(partial), content="2")
  inspect(skia_glyph_run_missing_glyph_count(improved), content="1")
  assert_false(skia_glyph_run_can_draw_text(partial))
  assert_true(skia_glyph_run_can_draw_text(complete))
  assert_true(skia_glyph_run_improves_missing_glyphs(partial, improved))
  assert_false(skia_glyph_run_improves_missing_glyphs(partial, same))
  assert_false(skia_glyph_run_improves_missing_glyphs(improved, partial))
  assert_true(skia_sample_missing_glyph_recovery_ready())
}

///|
test "skia text metrics derive baseline and height from font metrics" {
  match skia_test_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let metrics = skia_text_metrics(
        font,
        fallback_baseline=99.0,
        fallback_height=120.0,
      )
      if skia_test_font_has_visible_text(font, "Slim") {
        assert_true(metrics.baseline > 0.0)
        assert_true(metrics.height >= metrics.baseline)
        assert_true(metrics.baseline != 99.0)
        assert_true(metrics.height != 120.0)
      } else {
        assert_true(metrics.baseline == 99.0)
        assert_true(metrics.height == 120.0)
      }
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia text layout consumes the draw payload glyph run" {
  match skia_test_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let input = @core.TextLayoutInput::new(
        text="AB",
        font=@core.FontSpec::new(size=18.0, weight=400),
      )
      guard skia_font_can_measure_text(font, input.text) else { return () }
      let fallback = @core.TextSystem::fallback().measure_text(input)
      let glyph_run = SkiaGlyphRun::{
        glyphs: [@skia_native.GlyphId::new(10), @skia_native.GlyphId::new(11)],
        positions: [
          @moui_skia.Point::new(0.0, 0.0),
          @moui_skia.Point::new(77.0, 0.0),
        ],
        clusters: [0, 1],
        width: 123.0,
      }
      let layout = skia_text_layout_result(font, input, fallback, glyph_run~)
      inspect(layout.size.width, content="123")
      inspect(layout.caret_positions.length(), content="3")
      inspect(layout.caret_positions[0], content="0")
      inspect(layout.caret_positions[1], content="77")
      inspect(layout.caret_positions[2], content="123")
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia text system clamps measured carets to max width" {
  match skia_test_font(@core.FontSpec::new(size=20.0, weight=400)) {
    Some(font) => {
      let input = @core.TextLayoutInput::new(
        text="MoUI",
        font=@core.FontSpec::new(size=20.0, weight=400),
        max_width=12.0,
      )
      let fallback = @core.TextSystem::fallback().measure_text(input)
      let glyph_run = skia_glyph_run(font, input.text)
      let layout = skia_text_layout_result(font, input, fallback, glyph_run~)
      inspect(layout.caret_positions.length(), content="5")
      inspect(layout.size.width, content="12")
      for caret in layout.caret_positions {
        assert_true(caret <= 12.0)
      }
      assert_true(layout.caret_positions[4] == 12.0)
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia shaped caret mapping uses glyph clusters when available" {
  let run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(10),
      @skia_native.GlyphId::new(11),
      @skia_native.GlyphId::new(12),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(9.0, 0.0),
      @moui_skia.Point::new(21.0, 0.0),
    ],
    clusters: [0, 1, 4],
    width: 30.0,
  }
  match skia_shaped_caret_positions("A你B", run) {
    Some(carets) => {
      inspect(carets.length(), content="4")
      inspect(carets[0], content="0")
      inspect(carets[1], content="9")
      inspect(carets[2], content="21")
      inspect(carets[3], content="30")
    }
    None => fail("expected shaped caret mapping")
  }
}

///|
test "skia shaped caret mapping fills cluster gaps monotonically" {
  let run = SkiaGlyphRun::{
    glyphs: [@skia_native.GlyphId::new(10), @skia_native.GlyphId::new(11)],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(18.0, 0.0),
    ],
    clusters: [0, 5],
    width: 24.0,
  }
  match skia_shaped_caret_positions("A🙂B", run) {
    Some(carets) => {
      inspect(carets.length(), content="4")
      inspect(carets[0], content="0")
      inspect(carets[1], content="0")
      inspect(carets[2], content="18")
      inspect(carets[3], content="24")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected shaped caret mapping")
  }
}

///|
test "skia shaped caret mapping keeps emoji cluster caret coverage" {
  let variation_run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(10),
      @skia_native.GlyphId::new(11),
      @skia_native.GlyphId::new(12),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(10.0, 0.0),
      @moui_skia.Point::new(22.0, 0.0),
    ],
    clusters: [0, 1, 7],
    width: 30.0,
  }
  match skia_shaped_caret_positions("A\u{2615}\u{FE0F}B", variation_run) {
    Some(carets) => {
      inspect(carets.length(), content="5")
      inspect(carets[0], content="0")
      inspect(carets[1], content="10")
      inspect(carets[2], content="10")
      inspect(carets[3], content="22")
      inspect(carets[4], content="30")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected variation-selector caret mapping")
  }
  let zwj_run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(20),
      @skia_native.GlyphId::new(21),
      @skia_native.GlyphId::new(22),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(14.0, 0.0),
      @moui_skia.Point::new(28.0, 0.0),
    ],
    clusters: [0, 1, 12],
    width: 34.0,
  }
  match skia_shaped_caret_positions("A\u{1F469}\u{200D}\u{1F373}B", zwj_run) {
    Some(carets) => {
      inspect(carets.length(), content="6")
      inspect(carets[0], content="0")
      inspect(carets[1], content="14")
      inspect(carets[2], content="14")
      inspect(carets[3], content="14")
      inspect(carets[4], content="28")
      inspect(carets[5], content="34")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected ZWJ caret mapping")
  }
}

///|
test "skia shaped caret mapping stabilizes Indic cluster interiors" {
  let matra_run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(10),
      @skia_native.GlyphId::new(11),
      @skia_native.GlyphId::new(12),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(11.0, 0.0),
      @moui_skia.Point::new(24.0, 0.0),
    ],
    clusters: [0, 1, 7],
    width: 32.0,
  }
  match skia_shaped_caret_positions("A\u{0915}\u{093F}B", matra_run) {
    Some(carets) => {
      inspect(carets.length(), content="5")
      inspect(carets[0], content="0")
      inspect(carets[1], content="11")
      inspect(carets[2], content="11")
      inspect(carets[3], content="24")
      inspect(carets[4], content="32")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected Devanagari matra shaped caret mapping")
  }

  let virama_run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(20),
      @skia_native.GlyphId::new(21),
      @skia_native.GlyphId::new(22),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(10.0, 0.0),
      @moui_skia.Point::new(30.0, 0.0),
    ],
    clusters: [0, 1, 13],
    width: 38.0,
  }
  match
    skia_shaped_caret_positions(
      "A\u{0915}\u{094D}\u{200D}\u{0937}B", virama_run,
    ) {
    Some(carets) => {
      inspect(carets.length(), content="7")
      inspect(carets[0], content="0")
      inspect(carets[1], content="10")
      inspect(carets[2], content="10")
      inspect(carets[3], content="10")
      inspect(carets[4], content="10")
      inspect(carets[5], content="30")
      inspect(carets[6], content="38")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected Devanagari virama ZWJ shaped caret mapping")
  }
}

///|
test "skia shaped caret mapping stabilizes Hangul Jamo cluster interiors" {
  let hangul_run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(10),
      @skia_native.GlyphId::new(11),
      @skia_native.GlyphId::new(12),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(9.0, 0.0),
      @moui_skia.Point::new(26.0, 0.0),
    ],
    clusters: [0, 1, 10],
    width: 34.0,
  }
  match skia_shaped_caret_positions("A\u{1100}\u{1161}\u{11A8}B", hangul_run) {
    Some(carets) => {
      inspect(carets.length(), content="6")
      inspect(carets[0], content="0")
      inspect(carets[1], content="9")
      inspect(carets[2], content="9")
      inspect(carets[3], content="9")
      inspect(carets[4], content="26")
      inspect(carets[5], content="34")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected Hangul Jamo shaped caret mapping")
  }
}

///|
test "skia shaped caret mapping stabilizes representative cluster interiors" {
  let combining_run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(10),
      @skia_native.GlyphId::new(11),
      @skia_native.GlyphId::new(12),
      @skia_native.GlyphId::new(13),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(7.0, 0.0),
      @moui_skia.Point::new(13.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [0, 1, 2, 4],
    width: 24.0,
  }
  match skia_shaped_caret_positions("Ae\u{0301}B", combining_run) {
    Some(carets) => {
      inspect(carets.length(), content="5")
      inspect(carets[0], content="0")
      inspect(carets[1], content="7")
      inspect(carets[2], content="7")
      inspect(carets[3], content="16")
      inspect(carets[4], content="24")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected combining-mark shaped caret mapping")
  }

  let skin_tone_run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(20),
      @skia_native.GlyphId::new(21),
      @skia_native.GlyphId::new(22),
      @skia_native.GlyphId::new(23),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(12.0, 0.0),
      @moui_skia.Point::new(18.0, 0.0),
      @moui_skia.Point::new(26.0, 0.0),
    ],
    clusters: [0, 1, 5, 9],
    width: 34.0,
  }
  match skia_shaped_caret_positions("A\u{1F44B}\u{1F3FD}B", skin_tone_run) {
    Some(carets) => {
      inspect(carets.length(), content="5")
      inspect(carets[0], content="0")
      inspect(carets[1], content="12")
      inspect(carets[2], content="12")
      inspect(carets[3], content="26")
      inspect(carets[4], content="34")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected emoji-modifier shaped caret mapping")
  }
}

///|
test "skia fallback caret stabilization keeps representative cluster interiors stable" {
  let combining = skia_stabilize_grapheme_cluster_carets("Ae\u{0301}B", [
    0.0, 7.0, 13.0, 16.0, 24.0,
  ])
  inspect(combining.length(), content="5")
  inspect(combining[0], content="0")
  inspect(combining[1], content="7")
  inspect(combining[2], content="7")
  inspect(combining[3], content="16")
  inspect(combining[4], content="24")
  assert_true(skia_test_carets_are_monotonic(combining))

  let variation = skia_stabilize_grapheme_cluster_carets("A\u{2615}\u{FE0F}B", [
    0.0, 10.0, 18.0, 22.0, 30.0,
  ])
  inspect(variation.length(), content="5")
  inspect(variation[0], content="0")
  inspect(variation[1], content="10")
  inspect(variation[2], content="10")
  inspect(variation[3], content="22")
  inspect(variation[4], content="30")
  assert_true(skia_test_carets_are_monotonic(variation))

  let zwj = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F469}\u{200D}\u{1F373}B",
    [0.0, 14.0, 20.0, 22.0, 28.0, 34.0],
  )
  inspect(zwj.length(), content="6")
  inspect(zwj[0], content="0")
  inspect(zwj[1], content="14")
  inspect(zwj[2], content="14")
  inspect(zwj[3], content="14")
  inspect(zwj[4], content="28")
  inspect(zwj[5], content="34")
  assert_true(skia_test_carets_are_monotonic(zwj))

  let variation_zwj = skia_stabilize_grapheme_cluster_carets(
    "A\u{2764}\u{FE0F}\u{200D}\u{1F525}B",
    [0.0, 8.0, 12.0, 14.0, 16.0, 26.0, 30.0],
  )
  inspect(variation_zwj.length(), content="7")
  inspect(variation_zwj[0], content="0")
  inspect(variation_zwj[1], content="8")
  inspect(variation_zwj[2], content="8")
  inspect(variation_zwj[3], content="8")
  inspect(variation_zwj[4], content="8")
  inspect(variation_zwj[5], content="26")
  inspect(variation_zwj[6], content="30")
  assert_true(skia_test_carets_are_monotonic(variation_zwj))

  let flag = skia_stabilize_grapheme_cluster_carets("A\u{1F1FA}\u{1F1F8}B", [
    0.0, 11.0, 18.0, 27.0, 34.0,
  ])
  inspect(flag.length(), content="5")
  inspect(flag[0], content="0")
  inspect(flag[1], content="11")
  inspect(flag[2], content="11")
  inspect(flag[3], content="27")
  inspect(flag[4], content="34")
  assert_true(skia_test_carets_are_monotonic(flag))

  let paired_flags = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F1FA}\u{1F1F8}\u{1F1EF}\u{1F1F5}B",
    [0.0, 9.0, 13.0, 21.0, 27.0, 35.0, 43.0],
  )
  inspect(paired_flags.length(), content="7")
  inspect(paired_flags[0], content="0")
  inspect(paired_flags[1], content="9")
  inspect(paired_flags[2], content="9")
  inspect(paired_flags[3], content="21")
  inspect(paired_flags[4], content="21")
  inspect(paired_flags[5], content="35")
  inspect(paired_flags[6], content="43")
  assert_true(skia_test_carets_are_monotonic(paired_flags))

  let tag_flag = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F3F4}\u{E0067}\u{E0062}\u{E007F}B",
    [0.0, 9.0, 11.0, 13.0, 15.0, 25.0, 33.0],
  )
  inspect(tag_flag.length(), content="7")
  inspect(tag_flag[0], content="0")
  inspect(tag_flag[1], content="9")
  inspect(tag_flag[2], content="9")
  inspect(tag_flag[3], content="9")
  inspect(tag_flag[4], content="9")
  inspect(tag_flag[5], content="25")
  inspect(tag_flag[6], content="33")
  assert_true(skia_test_carets_are_monotonic(tag_flag))

  let keycap = skia_stabilize_grapheme_cluster_carets("A1\u{FE0F}\u{20E3}B", [
    0.0, 9.0, 13.0, 15.0, 24.0, 31.0,
  ])
  inspect(keycap.length(), content="6")
  inspect(keycap[0], content="0")
  inspect(keycap[1], content="9")
  inspect(keycap[2], content="9")
  inspect(keycap[3], content="9")
  inspect(keycap[4], content="24")
  inspect(keycap[5], content="31")
  assert_true(skia_test_carets_are_monotonic(keycap))

  let skin_tone = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F44B}\u{1F3FD}B",
    [0.0, 12.0, 18.0, 26.0, 34.0],
  )
  inspect(skin_tone.length(), content="5")
  inspect(skin_tone[0], content="0")
  inspect(skin_tone[1], content="12")
  inspect(skin_tone[2], content="12")
  inspect(skin_tone[3], content="26")
  inspect(skin_tone[4], content="34")
  assert_true(skia_test_carets_are_monotonic(skin_tone))

  let skin_tone_zwj = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F9D1}\u{1F3FD}\u{200D}\u{1F4BB}B",
    [0.0, 10.0, 14.0, 16.0, 18.0, 30.0, 38.0],
  )
  inspect(skin_tone_zwj.length(), content="7")
  inspect(skin_tone_zwj[0], content="0")
  inspect(skin_tone_zwj[1], content="10")
  inspect(skin_tone_zwj[2], content="10")
  inspect(skin_tone_zwj[3], content="10")
  inspect(skin_tone_zwj[4], content="10")
  inspect(skin_tone_zwj[5], content="30")
  inspect(skin_tone_zwj[6], content="38")
  assert_true(skia_test_carets_are_monotonic(skin_tone_zwj))
}

///|
test "skia fallback caret stabilization keeps Indic and Arabic marks stable" {
  let devanagari_matra = skia_stabilize_grapheme_cluster_carets(
    "A\u{0915}\u{093F}B",
    [0.0, 8.0, 14.0, 22.0, 30.0],
  )
  inspect(devanagari_matra.length(), content="5")
  inspect(devanagari_matra[0], content="0")
  inspect(devanagari_matra[1], content="8")
  inspect(devanagari_matra[2], content="8")
  inspect(devanagari_matra[3], content="22")
  inspect(devanagari_matra[4], content="30")
  assert_true(skia_test_carets_are_monotonic(devanagari_matra))

  let devanagari_conjunct = skia_stabilize_grapheme_cluster_carets(
    "A\u{0915}\u{094D}\u{200D}\u{0937}B",
    [0.0, 10.0, 14.0, 16.0, 20.0, 30.0, 38.0],
  )
  inspect(devanagari_conjunct.length(), content="7")
  inspect(devanagari_conjunct[0], content="0")
  inspect(devanagari_conjunct[1], content="10")
  inspect(devanagari_conjunct[2], content="10")
  inspect(devanagari_conjunct[3], content="10")
  inspect(devanagari_conjunct[4], content="10")
  inspect(devanagari_conjunct[5], content="30")
  inspect(devanagari_conjunct[6], content="38")
  assert_true(skia_test_carets_are_monotonic(devanagari_conjunct))

  let devanagari_no_zwj_conjunct = skia_stabilize_grapheme_cluster_carets(
    "A\u{0915}\u{094D}\u{0937}B",
    [0.0, 10.0, 14.0, 20.0, 30.0, 38.0],
  )
  inspect(devanagari_no_zwj_conjunct.length(), content="6")
  inspect(devanagari_no_zwj_conjunct[0], content="0")
  inspect(devanagari_no_zwj_conjunct[1], content="10")
  inspect(devanagari_no_zwj_conjunct[2], content="10")
  inspect(devanagari_no_zwj_conjunct[3], content="10")
  inspect(devanagari_no_zwj_conjunct[4], content="30")
  inspect(devanagari_no_zwj_conjunct[5], content="38")
  assert_true(skia_test_carets_are_monotonic(devanagari_no_zwj_conjunct))

  let arabic_marks = skia_stabilize_grapheme_cluster_carets(
    "A\u{0646}\u{0651}\u{064E}B",
    [0.0, 9.0, 13.0, 15.0, 24.0, 31.0],
  )
  inspect(arabic_marks.length(), content="6")
  inspect(arabic_marks[0], content="0")
  inspect(arabic_marks[1], content="9")
  inspect(arabic_marks[2], content="9")
  inspect(arabic_marks[3], content="9")
  inspect(arabic_marks[4], content="24")
  inspect(arabic_marks[5], content="31")
  assert_true(skia_test_carets_are_monotonic(arabic_marks))

  let arabic_prepend = skia_stabilize_grapheme_cluster_carets(
    "A\u{0600}\u{0628}\u{0651}B",
    [0.0, 8.0, 11.0, 14.0, 23.0, 31.0],
  )
  inspect(arabic_prepend.length(), content="6")
  inspect(arabic_prepend[0], content="0")
  inspect(arabic_prepend[1], content="8")
  inspect(arabic_prepend[2], content="8")
  inspect(arabic_prepend[3], content="8")
  inspect(arabic_prepend[4], content="23")
  inspect(arabic_prepend[5], content="31")
  assert_true(skia_test_carets_are_monotonic(arabic_prepend))
}

///|
test "skia fallback caret stabilization keeps Southeast and South Asian marks stable" {
  let thai_mark = skia_stabilize_grapheme_cluster_carets("A\u{0E01}\u{0E34}B", [
    0.0, 8.0, 13.0, 21.0, 29.0,
  ])
  inspect(thai_mark.length(), content="5")
  inspect(thai_mark[0], content="0")
  inspect(thai_mark[1], content="8")
  inspect(thai_mark[2], content="8")
  inspect(thai_mark[3], content="21")
  inspect(thai_mark[4], content="29")
  assert_true(skia_test_carets_are_monotonic(thai_mark))

  let lao_mark = skia_stabilize_grapheme_cluster_carets("A\u{0E81}\u{0EB4}B", [
    0.0, 8.0, 13.0, 21.0, 29.0,
  ])
  inspect(lao_mark.length(), content="5")
  inspect(lao_mark[0], content="0")
  inspect(lao_mark[1], content="8")
  inspect(lao_mark[2], content="8")
  inspect(lao_mark[3], content="21")
  inspect(lao_mark[4], content="29")
  assert_true(skia_test_carets_are_monotonic(lao_mark))

  let sinhala_vowel = skia_stabilize_grapheme_cluster_carets(
    "A\u{0D9A}\u{0DCF}B",
    [0.0, 9.0, 15.0, 24.0, 31.0],
  )
  inspect(sinhala_vowel.length(), content="5")
  inspect(sinhala_vowel[0], content="0")
  inspect(sinhala_vowel[1], content="9")
  inspect(sinhala_vowel[2], content="9")
  inspect(sinhala_vowel[3], content="24")
  inspect(sinhala_vowel[4], content="31")
  assert_true(skia_test_carets_are_monotonic(sinhala_vowel))

  let sinhala_virama = skia_stabilize_grapheme_cluster_carets(
    "A\u{0D9A}\u{0DCA}\u{0DBB}B",
    [0.0, 9.0, 13.0, 18.0, 25.0, 32.0],
  )
  inspect(sinhala_virama.length(), content="6")
  inspect(sinhala_virama[0], content="0")
  inspect(sinhala_virama[1], content="9")
  inspect(sinhala_virama[2], content="9")
  inspect(sinhala_virama[3], content="18")
  inspect(sinhala_virama[4], content="25")
  inspect(sinhala_virama[5], content="32")
  assert_true(skia_test_carets_are_monotonic(sinhala_virama))

  let khmer_vowel = skia_stabilize_grapheme_cluster_carets(
    "A\u{1780}\u{17B6}B",
    [0.0, 9.0, 15.0, 24.0, 31.0],
  )
  inspect(khmer_vowel.length(), content="5")
  inspect(khmer_vowel[0], content="0")
  inspect(khmer_vowel[1], content="9")
  inspect(khmer_vowel[2], content="9")
  inspect(khmer_vowel[3], content="24")
  inspect(khmer_vowel[4], content="31")
  assert_true(skia_test_carets_are_monotonic(khmer_vowel))

  let khmer_coeng = skia_stabilize_grapheme_cluster_carets(
    "A\u{1780}\u{17D2}\u{179A}B",
    [0.0, 9.0, 13.0, 18.0, 25.0, 32.0],
  )
  inspect(khmer_coeng.length(), content="6")
  inspect(khmer_coeng[0], content="0")
  inspect(khmer_coeng[1], content="9")
  inspect(khmer_coeng[2], content="9")
  inspect(khmer_coeng[3], content="9")
  inspect(khmer_coeng[4], content="25")
  inspect(khmer_coeng[5], content="32")
  assert_true(skia_test_carets_are_monotonic(khmer_coeng))

  let myanmar_conjunct = skia_stabilize_grapheme_cluster_carets(
    "A\u{1000}\u{1039}\u{1001}B",
    [0.0, 10.0, 14.0, 18.0, 25.0, 32.0],
  )
  inspect(myanmar_conjunct.length(), content="6")
  inspect(myanmar_conjunct[0], content="0")
  inspect(myanmar_conjunct[1], content="10")
  inspect(myanmar_conjunct[2], content="10")
  inspect(myanmar_conjunct[3], content="10")
  inspect(myanmar_conjunct[4], content="25")
  inspect(myanmar_conjunct[5], content="32")
  assert_true(skia_test_carets_are_monotonic(myanmar_conjunct))

  let myanmar_mark = skia_stabilize_grapheme_cluster_carets(
    "A\u{1000}\u{103A}B",
    [0.0, 10.0, 14.0, 22.0, 30.0],
  )
  inspect(myanmar_mark.length(), content="5")
  inspect(myanmar_mark[0], content="0")
  inspect(myanmar_mark[1], content="10")
  inspect(myanmar_mark[2], content="10")
  inspect(myanmar_mark[3], content="22")
  inspect(myanmar_mark[4], content="30")
  assert_true(skia_test_carets_are_monotonic(myanmar_mark))
}

///|
test "skia fallback caret stabilization keeps Hangul Jamo clusters stable" {
  assert_true(skia_codepoint_is_hangul_l(0x1100))
  assert_true(skia_codepoint_is_hangul_l(0xA960))
  assert_true(skia_codepoint_is_hangul_v(0x1161))
  assert_true(skia_codepoint_is_hangul_v(0xD7B0))
  assert_true(skia_codepoint_is_hangul_t(0x11A8))
  assert_true(skia_codepoint_is_hangul_t(0xD7CB))
  assert_true(skia_codepoint_is_hangul_lv(0xAC00))
  assert_true(skia_codepoint_is_hangul_lvt(0xAC01))
  assert_false(skia_codepoint_is_hangul_cluster_codepoint(0x3131))

  let modern_jamo = skia_stabilize_grapheme_cluster_carets(
    "A\u{1100}\u{1161}\u{11A8}B",
    [0.0, 9.0, 13.0, 18.0, 26.0, 34.0],
  )
  inspect(modern_jamo.length(), content="6")
  inspect(modern_jamo[0], content="0")
  inspect(modern_jamo[1], content="9")
  inspect(modern_jamo[2], content="9")
  inspect(modern_jamo[3], content="9")
  inspect(modern_jamo[4], content="26")
  inspect(modern_jamo[5], content="34")
  assert_true(skia_test_carets_are_monotonic(modern_jamo))

  let extended_jamo = skia_stabilize_grapheme_cluster_carets(
    "A\u{A960}\u{D7B0}\u{D7CB}B",
    [0.0, 8.0, 12.0, 17.0, 25.0, 33.0],
  )
  inspect(extended_jamo.length(), content="6")
  inspect(extended_jamo[0], content="0")
  inspect(extended_jamo[1], content="8")
  inspect(extended_jamo[2], content="8")
  inspect(extended_jamo[3], content="8")
  inspect(extended_jamo[4], content="25")
  inspect(extended_jamo[5], content="33")
  assert_true(skia_test_carets_are_monotonic(extended_jamo))

  let lv_plus_trailing = skia_stabilize_grapheme_cluster_carets(
    "A\u{AC00}\u{11A8}B",
    [0.0, 9.0, 14.0, 24.0, 31.0],
  )
  inspect(lv_plus_trailing.length(), content="5")
  inspect(lv_plus_trailing[0], content="0")
  inspect(lv_plus_trailing[1], content="9")
  inspect(lv_plus_trailing[2], content="9")
  inspect(lv_plus_trailing[3], content="24")
  inspect(lv_plus_trailing[4], content="31")
  assert_true(skia_test_carets_are_monotonic(lv_plus_trailing))
}

///|
test "skia layout width follows caret source" {
  inspect(skia_layout_width_from_carets([0.0, 4.0, 9.0]), content="9")
  inspect(skia_layout_width_from_carets([]), content="0")
}

///|
test "skia shaped caret mapping rejects invalid shaped data" {
  let run = SkiaGlyphRun::{
    glyphs: [@skia_native.GlyphId::new(10)],
    positions: [@moui_skia.Point::new(0.0, 0.0)],
    clusters: [],
    width: 10.0,
  }
  assert_true(skia_shaped_caret_positions("A", run) is None)
}

///|
test "skia text system keeps unicode caret coverage" {
  match skia_test_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let text = "A你🙂"
      let carets = skia_caret_positions(font, text)
      inspect(carets.length(), content="4")
      if skia_font_can_measure_text(font, text) {
        assert_true(carets[0] == 0.0)
        assert_true(carets[1] > 0.0)
        assert_true(carets[2] >= carets[1])
        assert_true(carets[3] >= carets[2])
        assert_true(carets[3] == skia_measure_text_width(font, text))
      } else {
        assert_true(carets.all(caret => caret == 0.0))
      }
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia text system keeps representative emoji caret coverage" {
  let system = skia_text_system(resolution=SkiaFontResolution::SystemFontMgr)
  for text in ["\u{1F642}", "\u{2615}\u{FE0F}", "\u{1F469}\u{200D}\u{1F373}"] {
    let input = @core.TextLayoutInput::new(
      text~,
      font=@core.FontSpec::new(size=18.0, weight=400),
    )
    let layout = system.measure_text(input)
    assert_true(layout.caret_positions.length() == text.to_array().length() + 1)
    assert_true(skia_test_carets_are_monotonic(layout.caret_positions))
    assert_true(
      layout.size.width == layout.caret_positions[text.to_array().length()],
    )
  }
}

///|
fn skia_test_carets_are_monotonic(carets : Array[Double]) -> Bool {
  let mut previous = 0.0
  for index, caret in carets {
    if index == 0 {
      previous = caret
    } else if caret < previous {
      return false
    } else {
      previous = caret
    }
  }
  true
}
