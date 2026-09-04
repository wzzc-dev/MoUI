///|
fn skia_test_shaping_layout(text : String) -> SkiaResolvedTextLayout? {
  match @skia_native.Font::empty(size=Float::from_double(10.0)) {
    None => None
    Some(font) =>
      Some({
        segments: [
          {
            text,
            font,
            glyph_run: SkiaGlyphRun::{
              glyphs: [@skia_native.GlyphId::new(1)],
              positions: [@moui_skia.Point::zero()],
              clusters: [0],
              width: 4.0,
            },
            x_offset: 0.0,
          },
        ],
        width: 4.0,
        metrics: SkiaTextMetrics::{ baseline: 8.0, height: 10.0 },
      })
  }
}

///|
test "skia shaping cache replays identical font/text/resolution keys" {
  guard skia_available() else { return () }
  let cache = SkiaTextShapingCache::new()
  let font = @core.FontSpec::new(size=10.0, weight=400)
  let other_font = @core.FontSpec::new(size=11.0, weight=400)
  let mut shapes = 0
  let shape = (text : String) => {
    () => {
      shapes += 1
      skia_test_shaping_layout(text)
    }
  }
  cache.begin_frame()
  let first = cache.resolve(
    font,
    "MoUI",
    SkiaFontResolution::SystemFontMgr,
    shape("MoUI"),
  )
  let hit = cache.resolve(
    font,
    "MoUI",
    SkiaFontResolution::SystemFontMgr,
    shape("MoUI"),
  )
  assert_true(first is Some(_))
  assert_true(hit is Some(_))
  inspect(cache.total_misses, content="1")
  inspect(cache.total_hits, content="1")
  inspect(shapes, content="1")
  // Different text, font spec, or resolution must miss despite key overlap.
  let _ = cache.resolve(
    font,
    "MoUl",
    SkiaFontResolution::SystemFontMgr,
    shape("MoUl"),
  )
  let _ = cache.resolve(
    other_font,
    "MoUI",
    SkiaFontResolution::SystemFontMgr,
    shape("MoUI"),
  )
  let _ = cache.resolve(
    font,
    "MoUI",
    SkiaFontResolution::EmptyTypeface,
    shape("MoUI"),
  )
  inspect(cache.total_misses, content="4")
  inspect(shapes, content="4")
  let (frame_hits, frame_misses) = cache.frame_delta()
  inspect(frame_hits, content="1")
  inspect(frame_misses, content="4")
  cache.begin_frame()
  let (reset_hits, reset_misses) = cache.frame_delta()
  inspect(reset_hits, content="0")
  inspect(reset_misses, content="0")
  // A failed shaping attempt is a miss but is not cached, so it reshapes again.
  cache.begin_frame()
  let _ = cache.resolve(font, "fail", SkiaFontResolution::SystemFontMgr, () => {
    None
  })
  let _ = cache.resolve(font, "fail", SkiaFontResolution::SystemFontMgr, () => {
    None
  })
  inspect(cache.total_misses, content="6")
  inspect(cache.entries.length(), content="4")
}

///|
test "skia shaping cache bounds entries with LRU eviction" {
  guard skia_available() else { return () }
  let cache = SkiaTextShapingCache::new()
  let font = @core.FontSpec::new(size=10.0, weight=400)
  for index in 0..<=(skia_text_shaping_cache_capacity + 8) {
    let text = "text-" + index.to_string()
    let _ = cache.resolve(font, text, SkiaFontResolution::SystemFontMgr, () => {
      skia_test_shaping_layout(text)
    })
    assert_true(cache.entries.length() <= skia_text_shaping_cache_capacity)
  }
  inspect(cache.entries.length(), content="256")
  // The most recent key survived eviction; the very oldest was evicted.
  let recent = cache.resolve(
    font,
    "text-" + (skia_text_shaping_cache_capacity + 8).to_string(),
    SkiaFontResolution::SystemFontMgr,
    () => skia_test_shaping_layout("recent"),
  )
  assert_true(recent is Some(_))
  inspect(cache.total_hits, content="1")
  let mut reshaped = 0
  let evicted = cache.resolve(
    font,
    "text-0",
    SkiaFontResolution::SystemFontMgr,
    () => {
      reshaped += 1
      skia_test_shaping_layout("text-0")
    },
  )
  assert_true(evicted is Some(_))
  inspect(reshaped, content="1")
}

///|
test "skia render_frame reports shaping cache hits across identical frames" {
  guard skia_test_native_text_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=64.0, height=16.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let commands = [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="Slim",
        frame=@core.Rect::new(x=2.0, y=2.0, width=56.0, height=12.0),
        font=@core.FontSpec::new(size=10.0, weight=400),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
  ]
  let first = renderer.render_frame(skia_test_draw_frame(commands))
  inspect(first.cache_hit_count, content="0")
  assert_true(first.cache_miss_count > 0)
  let second = renderer.render_frame(skia_test_draw_frame(commands))
  assert_true(second.cache_hit_count > 0)
  inspect(second.cache_miss_count, content="0")
  // A different text run under the same frame shape is a fresh miss.
  let third = renderer.render_frame(
    skia_test_draw_frame([
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::DrawText(
        @core.TextRun::new(
          text="Slimmer",
          frame=@core.Rect::new(x=2.0, y=2.0, width=56.0, height=12.0),
          font=@core.FontSpec::new(size=10.0, weight=400),
          color=@core.Color::black(),
          align=@core.TextAlign::TextStart,
        ),
      ),
    ]),
  )
  assert_true(third.cache_miss_count > 0)
}
