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
            glyph_run: {
              glyphs: [@skia_native.GlyphId::new(1)],
              positions: [@moui_skia.Point::zero()],
              clusters: [0],
              width: 4.0,
            },
            x_offset: 0.0,
          },
        ],
        width: 4.0,
        metrics: { baseline: 8.0, height: 10.0, },
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
  let first = cache.resolve(font, "MoUI", SystemFontMgr, shape("MoUI"))
  let hit = cache.resolve(font, "MoUI", SystemFontMgr, shape("MoUI"))
  assert_true(first is Some(_))
  assert_true(hit is Some(_))
  inspect(cache.total_misses, content="1")
  inspect(cache.total_hits, content="1")
  inspect(shapes, content="1")
  // Different text, font spec, or resolution must miss despite key overlap.
  let _ = cache.resolve(font, "MoUl", SystemFontMgr, shape("MoUl"))
  let _ = cache.resolve(other_font, "MoUI", SystemFontMgr, shape("MoUI"))
  let _ = cache.resolve(font, "MoUI", EmptyTypeface, shape("MoUI"))
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
  let _ = cache.resolve(font, "fail", SystemFontMgr, () => None)
  let _ = cache.resolve(font, "fail", SystemFontMgr, () => None)
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
    let _ = cache.resolve(font, text, SystemFontMgr, () => {
      skia_test_shaping_layout(text)
    })
    assert_true(cache.entries.length() <= skia_text_shaping_cache_capacity)
  }
  inspect(cache.entries.length(), content="256")
  // The most recent key survived eviction; the very oldest was evicted.
  let recent = cache.resolve(
    font,
    "text-" + (skia_text_shaping_cache_capacity + 8).to_string(),
    SystemFontMgr,
    () => skia_test_shaping_layout("recent"),
  )
  assert_true(recent is Some(_))
  inspect(cache.total_hits, content="1")
  let mut reshaped = 0
  let evicted = cache.resolve(font, "text-0", SystemFontMgr, () => {
    reshaped += 1
    skia_test_shaping_layout("text-0")
  })
  assert_true(evicted is Some(_))
  inspect(reshaped, content="1")
}

///|
/// G1: the shaping cache key is a structural hash of the FontSpec fields —
/// no JSON stringify, no string concatenation — so structurally equal specs
/// hit regardless of which value instance arrives, and per-field differences
/// never collide. Hits also share the cached layout by reference instead of
/// deep-copying it.
test "skia shaping cache keys are structural and hits share the layout" {
  guard skia_available() else { return () }
  let cache = SkiaTextShapingCache::new()
  let base = @core.FontSpec::new(
    families=@core.FontFamilyStack::new([Name("Test")]),
    size=12.0,
    weight=500,
    style=Italic,
    variations=[@core.FontVariation::new(axis="wght", value=500.0)],
  )
  let mut shapes = 0
  let shape = (text : String) => {
    () => {
      shapes += 1
      skia_test_shaping_layout(text)
    }
  }
  cache.begin_frame()
  assert_true(cache.resolve(base, "A", SystemFontMgr, shape("A")) is Some(_))
  inspect(cache.total_misses, content="1")
  // A freshly built, structurally equal spec hits without reshaping.
  let equal = @core.FontSpec::new(
    families=@core.FontFamilyStack::new([Name("Test")]),
    size=12.0,
    weight=500,
    style=Italic,
    variations=[@core.FontVariation::new(axis="wght", value=500.0)],
  )
  assert_true(cache.resolve(equal, "A", SystemFontMgr, shape("A")) is Some(_))
  inspect(cache.total_hits, content="1")
  inspect(shapes, content="1")
  // Every spec field must split keys: resolution, size, weight, style,
  // family, and variation axes/values.
  let split_specs = [
    ("resolution", cache.resolve(base, "A", EmptyTypeface, shape("A"))),
    (
      "size",
      cache.resolve(
        @core.FontSpec::new(
          families=@core.FontFamilyStack::new([Name("Test")]),
          size=13.0,
          weight=500,
          style=Italic,
          variations=[@core.FontVariation::new(axis="wght", value=500.0)],
        ),
        "A",
        SystemFontMgr,
        shape("A"),
      ),
    ),
    (
      "weight",
      cache.resolve(
        @core.FontSpec::new(
          families=@core.FontFamilyStack::new([Name("Test")]),
          size=12.0,
          weight=600,
          style=Italic,
          variations=[@core.FontVariation::new(axis="wght", value=500.0)],
        ),
        "A",
        SystemFontMgr,
        shape("A"),
      ),
    ),
    (
      "style",
      cache.resolve(
        @core.FontSpec::new(
          families=@core.FontFamilyStack::new([Name("Test")]),
          size=12.0,
          weight=500,
          style=Normal,
          variations=[@core.FontVariation::new(axis="wght", value=500.0)],
        ),
        "A",
        SystemFontMgr,
        shape("A"),
      ),
    ),
    (
      "family",
      cache.resolve(
        @core.FontSpec::new(
          families=@core.FontFamilyStack::new([Name("Other")]),
          size=12.0,
          weight=500,
          style=Italic,
          variations=[@core.FontVariation::new(axis="wght", value=500.0)],
        ),
        "A",
        SystemFontMgr,
        shape("A"),
      ),
    ),
    (
      "named-vs-preset-family",
      cache.resolve(
        @core.FontSpec::new(
          families=@core.FontFamilyStack::new([SystemUi]),
          size=12.0,
          weight=500,
          style=Italic,
          variations=[@core.FontVariation::new(axis="wght", value=500.0)],
        ),
        "A",
        SystemFontMgr,
        shape("A"),
      ),
    ),
    (
      "variation-value",
      cache.resolve(
        @core.FontSpec::new(
          families=@core.FontFamilyStack::new([Name("Test")]),
          size=12.0,
          weight=500,
          style=Italic,
          variations=[@core.FontVariation::new(axis="wght", value=600.0)],
        ),
        "A",
        SystemFontMgr,
        shape("A"),
      ),
    ),
    (
      "variation-axis",
      cache.resolve(
        @core.FontSpec::new(
          families=@core.FontFamilyStack::new([Name("Test")]),
          size=12.0,
          weight=500,
          style=Italic,
          variations=[@core.FontVariation::new(axis="wdth", value=500.0)],
        ),
        "A",
        SystemFontMgr,
        shape("A"),
      ),
    ),
  ]
  for (label, result) in split_specs {
    guard result is Some(_) else { fail("expected shaped layout for \{label}") }
  }
  inspect(cache.total_misses, content="9")
  inspect(shapes, content="9")
  // 0.0 and -0.0 are equal under Eq, so they must share one cache slot (the
  // key normalizes zeros; otherwise a bit-derived hash could disagree with
  // the derived Eq and strand the entry).
  let zero = @core.FontSpec::new(
    families=@core.FontFamilyStack::new([Name("Test")]),
    size=0.0,
    weight=500,
    style=Italic,
    variations=[@core.FontVariation::new(axis="wght", value=500.0)],
  )
  assert_true(cache.resolve(zero, "A", SystemFontMgr, shape("A")) is Some(_))
  inspect(cache.total_misses, content="10")
  let negative_zero = @core.FontSpec::new(
    families=@core.FontFamilyStack::new([Name("Test")]),
    size=-0.0,
    weight=500,
    style=Italic,
    variations=[@core.FontVariation::new(axis="wght", value=500.0)],
  )
  assert_true(
    cache.resolve(negative_zero, "A", SystemFontMgr, shape("A")) is Some(_),
  )
  inspect(cache.total_hits, content="2")
  inspect(shapes, content="10")
  // A hit hands back the cached layout itself (no deep copy): the segments
  // array is the same storage the cache holds. Production consumers only
  // read layouts, which is what makes the sharing safe — this mutation is
  // the observable that pins the no-copy replay.
  let shared = cache.resolve(base, "A", SystemFontMgr, shape("A"))
  guard shared is Some(layout) else { fail("expected shared layout") }
  inspect(layout.segments.length(), content="1")
  layout.segments.push(layout.segments[0])
  let after = cache.resolve(base, "A", SystemFontMgr, shape("A"))
  guard after is Some(cached) else {
    fail("expected cached layout after shared mutation")
  }
  inspect(cached.segments.length(), content="2")
  inspect(cache.total_hits, content="4")
  inspect(shapes, content="10")
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
    DrawText(
      @core.TextRun::new(
        text="Slim",
        frame=@core.Rect::new(x=2.0, y=2.0, width=56.0, height=12.0),
        font=@core.FontSpec::new(size=10.0, weight=400),
        color=@core.Color::black(),
        align=TextStart,
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
      Clear(@core.Color::white()),
      DrawText(
        @core.TextRun::new(
          text="Slimmer",
          frame=@core.Rect::new(x=2.0, y=2.0, width=56.0, height=12.0),
          font=@core.FontSpec::new(size=10.0, weight=400),
          color=@core.Color::black(),
          align=TextStart,
        ),
      ),
    ]),
  )
  assert_true(third.cache_miss_count > 0)
}
