///|
fn glyph_atlas_entry_count(atlas : GlyphAtlas) -> Int {
  atlas.entries.length()
}

///|
fn atlas_entry_nonzero_row_bounds(
  atlas : GlyphAtlas,
  entry : GlyphAtlasEntry,
) -> (Int, Int)? {
  let mut min_y = entry.height
  let mut max_y = -1
  for y in 0..<entry.height {
    for x in 0..<entry.width {
      let offset = ((entry.y + y) * atlas.width + entry.x + x) * 4 + 3
      if atlas.pixels[offset] != b'\x00' {
        min_y = min_y.min(y)
        max_y = max_y.max(y)
      }
    }
  }
  if max_y >= 0 {
    Some((min_y, max_y))
  } else {
    None
  }
}

///|
fn text_vertices_have_visible_position(vertices : Array[TextVertex]) -> Bool {
  for vertex in vertices {
    if vertex.x >= -1.0 &&
      vertex.x <= 1.0 &&
      vertex.y >= -1.0 &&
      vertex.y <= 1.0 {
      return true
    }
  }
  false
}

///|
test "native text system exposes default fallback engine id" {
  inspect(native_text_system().id(), content="native-wgpu-noop-text")
}

///|
test "native text provider values have stable constructors" {
  let key = native_platform_glyph_key(
    cache_key="test-platform:constructor",
    payload=Bytes::from_array([b'\x01']),
  )
  let placement = NativeGlyphPlacement::new(key~, x=3.0, y=4.0)
  inspect(placement.x, content="3")
  inspect(placement.y, content="4")
  let layout = NativeTextLayout::new(
    size=@core.Size::new(width=12.0, height=18.0),
    baseline=11.0,
    caret_positions=[0.0, 12.0],
    glyphs=[placement],
  )
  inspect(layout.size.width, content="12")
  inspect(layout.baseline, content="11")
  inspect(layout.caret_positions.length(), content="2")
  inspect(layout.glyphs.length(), content="1")
  let glyph = NativeRasterGlyph::new(
    width=2,
    height=2,
    bearing_x=1,
    bearing_y=-2,
    pixels=Bytes::from_array([b'\x00', b'\xff', b'\xff', b'\x00']),
  )
  inspect(glyph.width, content="2")
  inspect(glyph.height, content="2")
  inspect(glyph.pixels.length(), content="4")
}

///|
test "native platform provider receives registered font data before fallback cache" {
  let registered : Ref[Int] = Ref(0)
  let family_name : Ref[String] = Ref("")
  let data_len : Ref[Int] = Ref(0)
  let fallback_registered : Ref[Int] = Ref(0)
  let system = native_text_system_with_engine(
    native_platform_text_engine_with_fallback(
      NativePlatformTextProvider::new(
        id="test-platform-text",
        measure=_input => None,
        layout_run=(_run, _scale) => None,
        raster_glyph=(_cache_key, _payload) => None,
        register_font_data=(family, data) => {
          registered.val = registered.val + 1
          family_name.val = family.css_name()
          data_len.val = data.length()
        },
      ),
      fallback=native_platform_text_engine(
        NativePlatformTextProvider::new(
          id="test-fallback-text",
          measure=_input => None,
          layout_run=(_run, _scale) => None,
          raster_glyph=(_cache_key, _payload) => None,
          register_font_data=(_family, _data) => {
            fallback_registered.val = fallback_registered.val + 1
          },
        ),
      ),
    ),
  )
  system.register_font_data(
    @core.FontFamily::Name("Acme"),
    Bytes::from_array([b'A', b'c', b'm', b'e']),
  )
  inspect(registered.val, content="1")
  inspect(fallback_registered.val, content="1")
  inspect(family_name.val, content="Acme")
  inspect(data_len.val, content="4")
}

///|
test "native text engine keeps explicit fallback path available" {
  let cache = NativeFontCache::new_with_engine(test_fallback_text_engine())
  let input = @core.TextLayoutInput::new(
    text="fallback",
    font=@core.FontSpec::new(size=14.0, weight=400),
  )
  let measured = native_measure_text_layout(cache, input)
  inspect(measured.size.width > 0.0, content="true")
  inspect(measured.caret_positions.length(), content="9")
}

///|
test "native text engine falls back when platform measure is invalid" {
  let system = native_text_system_with_engine(
    native_platform_text_engine_with_fallback(
      NativePlatformTextProvider::new(
        id="test-platform-text",
        measure=_input => {
          Some(
            NativeTextLayout::new(
              size=@core.Size::new(width=-1.0, height=0.0),
              baseline=4.0,
              caret_positions=[0.0, -2.0],
            ),
          )
        },
        layout_run=(_run, _scale) => None,
        raster_glyph=(_cache_key, _payload) => None,
      ),
      fallback=test_fallback_text_engine(),
    ),
  )
  let result = system.measure_text(
    @core.TextLayoutInput::new(
      text="fallback",
      font=@core.FontSpec::new(size=14.0, weight=400),
    ),
  )
  inspect(result.size.width > 0.0, content="true")
  inspect(result.size.height > 0.0, content="true")
  inspect(result.caret_positions.length(), content="9")
}

///|
test "native text engine rejects non monotonic platform measure carets" {
  let system = native_text_system_with_engine(
    native_platform_text_engine_with_fallback(
      NativePlatformTextProvider::new(
        id="test-platform-text",
        measure=_input => {
          Some(
            NativeTextLayout::new(
              size=@core.Size::new(width=42.0, height=18.0),
              baseline=12.0,
              caret_positions=[0.0, 20.0, 12.0, 42.0],
            ),
          )
        },
        layout_run=(_run, _scale) => None,
        raster_glyph=(_cache_key, _payload) => None,
      ),
      fallback=test_fallback_text_engine(),
    ),
  )
  let text = "abc"
  let result = system.measure_text(
    @core.TextLayoutInput::new(
      text~,
      font=@core.FontSpec::new(size=14.0, weight=400),
    ),
  )
  inspect(result.size.width > 0.0, content="true")
  inspect(result.caret_positions.length(), content="4")
  inspect(
    result.caret_positions[2] >= result.caret_positions[1],
    content="true",
  )
}

///|
test "native text engine rejects undersized platform measure carets" {
  let system = native_text_system_with_engine(
    native_platform_text_engine_with_fallback(
      NativePlatformTextProvider::new(
        id="test-platform-text",
        measure=_input => {
          Some(
            NativeTextLayout::new(
              size=@core.Size::new(width=42.0, height=18.0),
              baseline=12.0,
              caret_positions=[0.0, 42.0],
            ),
          )
        },
        layout_run=(_run, _scale) => None,
        raster_glyph=(_cache_key, _payload) => None,
      ),
      fallback=test_fallback_text_engine(),
    ),
  )
  let text = "abc"
  let result = system.measure_text(
    @core.TextLayoutInput::new(
      text~,
      font=@core.FontSpec::new(size=14.0, weight=400),
    ),
  )
  inspect(result.size.width > 0.0, content="true")
  inspect(
    result.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
}

///|
test "native text engine rejects invalid platform measure baseline" {
  let system = native_text_system_with_engine(
    native_platform_text_engine_with_fallback(
      NativePlatformTextProvider::new(
        id="test-platform-text",
        measure=_input => {
          Some(
            NativeTextLayout::new(
              size=@core.Size::new(width=42.0, height=18.0),
              baseline=24.0,
              caret_positions=[0.0, 14.0, 28.0, 42.0],
            ),
          )
        },
        layout_run=(_run, _scale) => None,
        raster_glyph=(_cache_key, _payload) => None,
      ),
      fallback=test_fallback_text_engine(),
    ),
  )
  let text = "abc"
  let result = system.measure_text(
    @core.TextLayoutInput::new(
      text~,
      font=@core.FontSpec::new(size=14.0, weight=400),
    ),
  )
  inspect(result.size.width > 0.0, content="true")
  inspect(result.size.height > 0.0, content="true")
  inspect(result.baseline <= result.size.height, content="true")
  inspect(
    result.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
}

///|
test "native text engine falls back when platform glyph raster fails" {
  let cache = NativeFontCache::new_with_engine(
    native_platform_text_engine_with_fallback(
      NativePlatformTextProvider::new(
        id="test-platform-text",
        measure=_input => None,
        layout_run=(_run, _scale) => None,
        raster_glyph=(_cache_key, _payload) => None,
      ),
      fallback=test_fallback_text_engine(),
    ),
  )
  let atlas = GlyphAtlas::new(width=atlas_width, height=atlas_height)
  let run = @core.TextRun::new(
    text="fallback",
    frame=@core.Rect::new(x=0.0, y=0.0, width=160.0, height=32.0),
    font=@core.FontSpec::new(size=16.0, weight=500),
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  let vertices : Array[TextVertex] = []
  let bad_platform_layout = NativeTextLayout::new(
    size=@core.Size::new(width=64.0, height=20.0),
    baseline=14.0,
    glyphs=[
      NativeGlyphPlacement::new(
        key=native_platform_glyph_key(
          cache_key="test-platform:missing",
          payload=Bytes::from_array([b'\x00']),
        ),
        x=0.0,
      ),
    ],
  )
  let atlas_full = append_text_layout_or_fallback(
    cache,
    atlas,
    run,
    native_paint_state_default(),
    @core.Size::new(width=320.0, height=120.0),
    1.0,
    bad_platform_layout,
    vertices,
  )
  inspect(atlas_full, content="false")
  inspect(vertices.length() > 0, content="true")
  inspect(glyph_atlas_entry_count(atlas) > 0, content="true")
}

///|
test "native text engine falls back when platform run layout metrics are invalid" {
  let bad_key = native_platform_glyph_key(
    cache_key="test-platform:bad-layout",
    payload=Bytes::from_array([b'\x02']),
  )
  let cache = NativeFontCache::new_with_engine(
    native_platform_text_engine_with_fallback(
      NativePlatformTextProvider::new(
        id="test-platform-text",
        measure=_input => None,
        layout_run=(_run, _scale) => {
          Some(
            NativeTextLayout::new(
              size=@core.Size::new(width=-1.0, height=0.0),
              baseline=12.0,
              caret_positions=[2.0, 1.0],
              glyphs=[NativeGlyphPlacement::new(key=bad_key, x=0.0)],
            ),
          )
        },
        raster_glyph=(_cache_key, _payload) => {
          Some(
            NativeRasterGlyph::new(
              width=2,
              height=2,
              bearing_x=0,
              bearing_y=-2,
              pixels=Bytes::from_array([b'\xff', b'\xff', b'\xff', b'\xff']),
            ),
          )
        },
      ),
      fallback=test_fallback_text_engine(),
    ),
  )
  let atlas = GlyphAtlas::new(width=atlas_width, height=atlas_height)
  let run = @core.TextRun::new(
    text="fallback",
    frame=@core.Rect::new(x=0.0, y=0.0, width=160.0, height=32.0),
    font=@core.FontSpec::new(size=16.0, weight=500),
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  let vertices : Array[TextVertex] = []
  let atlas_full = append_text_run_vertices(
    cache,
    atlas,
    run,
    native_paint_state_default(),
    @core.Size::new(width=320.0, height=120.0),
    1.0,
    vertices,
  )
  inspect(atlas_full, content="false")
  inspect(vertices.length() > 0, content="true")
  inspect(atlas.entries.get("test-platform:bad-layout") is None, content="true")
  inspect(glyph_atlas_entry_count(atlas) > 0, content="true")
}

///|
test "native text engine falls back when platform layout has no glyphs" {
  let cache = NativeFontCache::new_with_engine(
    native_platform_text_engine_with_fallback(
      NativePlatformTextProvider::new(
        id="test-platform-text",
        measure=_input => None,
        layout_run=(_run, _scale) => None,
        raster_glyph=(_cache_key, _payload) => None,
      ),
      fallback=test_fallback_text_engine(),
    ),
  )
  let atlas = GlyphAtlas::new(width=atlas_width, height=atlas_height)
  let run = @core.TextRun::new(
    text="fallback",
    frame=@core.Rect::new(x=0.0, y=0.0, width=160.0, height=32.0),
    font=@core.FontSpec::new(size=16.0, weight=500),
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  let vertices : Array[TextVertex] = []
  let empty_platform_layout = NativeTextLayout::new(
    size=@core.Size::new(width=64.0, height=20.0),
    baseline=14.0,
  )
  let atlas_full = append_text_layout_or_fallback(
    cache,
    atlas,
    run,
    native_paint_state_default(),
    @core.Size::new(width=320.0, height=120.0),
    1.0,
    empty_platform_layout,
    vertices,
  )
  inspect(atlas_full, content="false")
  inspect(vertices.length() > 0, content="true")
  inspect(glyph_atlas_entry_count(atlas) > 0, content="true")
}

///|
test "native text engine rejects invalid platform raster glyphs" {
  let cache = NativeFontCache::new_with_engine(
    native_platform_text_engine_with_fallback(
      NativePlatformTextProvider::new(
        id="test-platform-text",
        measure=_input => None,
        layout_run=(_run, _scale) => None,
        raster_glyph=(_cache_key, _payload) => {
          Some(
            NativeRasterGlyph::new(
              width=8,
              height=8,
              bearing_x=0,
              bearing_y=-8,
              pixels=Bytes::from_array([b'\xff']),
            ),
          )
        },
      ),
      fallback=test_fallback_text_engine(),
    ),
  )
  let atlas = GlyphAtlas::new(width=atlas_width, height=atlas_height)
  let run = @core.TextRun::new(
    text="fallback",
    frame=@core.Rect::new(x=0.0, y=0.0, width=160.0, height=32.0),
    font=@core.FontSpec::new(size=16.0, weight=500),
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  let vertices : Array[TextVertex] = []
  let bad_raster_layout = NativeTextLayout::new(
    size=@core.Size::new(width=64.0, height=20.0),
    baseline=14.0,
    glyphs=[
      NativeGlyphPlacement::new(
        key=native_platform_glyph_key(
          cache_key="test-platform:invalid-raster",
          payload=Bytes::from_array([b'\x01']),
        ),
        x=0.0,
      ),
    ],
  )
  let atlas_full = append_text_layout_or_fallback(
    cache,
    atlas,
    run,
    native_paint_state_default(),
    @core.Size::new(width=320.0, height=120.0),
    1.0,
    bad_raster_layout,
    vertices,
  )
  inspect(atlas_full, content="false")
  inspect(vertices.length() > 0, content="true")
  inspect(
    atlas.entries.get("test-platform:invalid-raster") is None,
    content="true",
  )
  inspect(glyph_atlas_entry_count(atlas) > 0, content="true")
}

///|
test "native renderer builds text vertices and atlas entries" {
  let glyph_key = native_platform_glyph_key(
    cache_key="test-platform:counter",
    payload=Bytes::from_array([b'M']),
  )
  let renderer = new_test_renderer_handle_with_text_engine(
    native_platform_text_engine(
      NativePlatformTextProvider::new(
        id="test-platform-text",
        measure=_input => None,
        layout_run=(_run, _scale) => {
          Some({
            size: @core.Size::new(width=64.0, height=20.0),
            baseline: 14.0,
            caret_positions: [],
            glyphs: [{ key: glyph_key, x: 0.0, y: 0.0 }],
          })
        },
        raster_glyph=(_cache_key, _payload) => {
          Some(
            NativeRasterGlyph::new(
              width=4,
              height=4,
              bearing_x=0,
              bearing_y=-4,
              pixels=Bytes::from_array([
                b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\x00', b'\x00', b'\xff',
                b'\xff', b'\x00', b'\x00', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
              ]),
            ),
          )
        },
      ),
    ),
  )
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=200.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::DrawText({
      text: "MoUI Counter",
      frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
      font: @core.FontSpec::new(size=16.0, weight=500),
      color: @core.Color::black(),
      align: @core.TextAlign::TextCenter,
    }),
  ])
  inspect(renderer.text_vertices.length() > 0, content="true")
  inspect(
    text_vertices_have_visible_position(renderer.text_vertices),
    content="true",
  )
  inspect(glyph_atlas_entry_count(renderer.glyph_atlas) > 0, content="true")
}

///|
test "native renderer accepts layouts that omit whitespace glyphs" {
  let fallback_layout_count : Ref[Int] = Ref(0)
  let fallback_raster_count : Ref[Int] = Ref(0)
  let renderer = new_test_renderer_handle_with_text_engine(
    native_platform_text_engine_with_fallback(
      NativePlatformTextProvider::new(
        id="test-platform-text",
        measure=_input => None,
        layout_run=(run, _scale) => {
          let glyphs : Array[NativeGlyphPlacement] = []
          let mut x = 0.0
          for ch in run.text {
            if ch.is_whitespace() {
              x = x + run.font.size * 0.32
            } else {
              let key = native_platform_glyph_key(
                cache_key="test-platform:\{ch.to_uint()}",
                payload=Bytes::from_array([b'\x08']),
              )
              glyphs.push(NativeGlyphPlacement::new(key~, x~))
              x = x + run.font.size * 0.5
            }
          }
          Some(
            NativeTextLayout::new(
              size=@core.Size::new(width=x, height=run.font.size * 1.25),
              baseline=run.font.size * 0.8,
              glyphs~,
            ),
          )
        },
        raster_glyph=(_cache_key, _payload) => {
          Some(
            NativeRasterGlyph::new(
              width=8,
              height=10,
              bearing_x=0,
              bearing_y=-8,
              pixels=Bytes::from_array(Array::make(80, b'\xff')),
            ),
          )
        },
      ),
      fallback=native_platform_text_engine(
        NativePlatformTextProvider::new(
          id="test-fallback-text",
          measure=_input => None,
          layout_run=(_run, _scale) => {
            fallback_layout_count.val = fallback_layout_count.val + 1
            None
          },
          raster_glyph=(_cache_key, _payload) => {
            fallback_raster_count.val = fallback_raster_count.val + 1
            None
          },
        ),
      ),
    ),
  )
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=160.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::DrawText({
      text: "Layered card with image",
      frame: @core.Rect::new(x=0.0, y=0.0, width=240.0, height=36.0),
      font: @core.FontSpec::new(size=16.0, weight=500),
      color: @core.Color::black(),
      align: @core.TextAlign::TextStart,
    }),
  ])
  inspect(renderer.text_vertices.length() > 0, content="true")
  inspect(glyph_atlas_entry_count(renderer.glyph_atlas) > 0, content="true")
  inspect(fallback_layout_count.val, content="0")
  inspect(fallback_raster_count.val, content="0")
}

///|
test "native renderer blits platform glyph rows away from atlas top edge" {
  let glyph_key = native_platform_glyph_key(
    cache_key="test-platform:H",
    payload=Bytes::from_array([b'H']),
  )
  let renderer = new_test_renderer_handle_with_text_engine(
    native_platform_text_engine(
      NativePlatformTextProvider::new(
        id="test-platform-text",
        measure=_input => None,
        layout_run=(_run, _scale) => {
          Some({
            size: @core.Size::new(width=24.0, height=36.0),
            baseline: 28.0,
            caret_positions: [],
            glyphs: [{ key: glyph_key, x: 0.0, y: 0.0 }],
          })
        },
        raster_glyph=(_cache_key, _payload) => {
          Some(
            NativeRasterGlyph::new(
              width=8,
              height=12,
              bearing_x=0,
              bearing_y=-10,
              pixels=Bytes::from_array([
                b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
                b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
                b'\xff', b'\x00', b'\x00', b'\xff', b'\xff', b'\x00', b'\x00', b'\xff',
                b'\xff', b'\x00', b'\x00', b'\xff', b'\xff', b'\x00', b'\x00', b'\xff',
                b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
                b'\xff', b'\x00', b'\x00', b'\xff', b'\xff', b'\x00', b'\x00', b'\xff',
                b'\xff', b'\x00', b'\x00', b'\xff', b'\xff', b'\x00', b'\x00', b'\xff',
                b'\xff', b'\x00', b'\x00', b'\xff', b'\xff', b'\x00', b'\x00', b'\xff',
                b'\xff', b'\x00', b'\x00', b'\xff', b'\xff', b'\x00', b'\x00', b'\xff',
                b'\xff', b'\x00', b'\x00', b'\xff', b'\xff', b'\x00', b'\x00', b'\xff',
                b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
                b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
              ]),
            ),
          )
        },
      ),
    ),
  )
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=200.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::DrawText({
      text: "H",
      frame: @core.Rect::new(x=0.0, y=0.0, width=80.0, height=48.0),
      font: @core.FontSpec::new(size=32.0, weight=700),
      color: @core.Color::black(),
      align: @core.TextAlign::TextStart,
    }),
  ])
  inspect(renderer.draw_items.length(), content="1")
  assert_true(renderer.draw_items[0] is NativeDrawItem::NativeText(_, _, _))
  match renderer.glyph_atlas.entries.get("test-platform:H") {
    Some(entry) =>
      match atlas_entry_nonzero_row_bounds(renderer.glyph_atlas, entry) {
        Some((min_row, max_row)) => {
          let baseline_row = -entry.bearing_y
          inspect(min_row > 0, content="true")
          inspect(baseline_row > 0, content="true")
          inspect(baseline_row < entry.height, content="true")
          inspect(max_row < baseline_row, content="true")
        }
        None => fail("expected non-empty atlas glyph alpha")
      }
    None => fail("expected platform H glyph atlas entry")
  }
}

///|
test "native renderer builds cjk text vertices with fallback font" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=200.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::DrawText({
      text: "你",
      frame: @core.Rect::new(x=0.0, y=0.0, width=80.0, height=40.0),
      font: @core.FontSpec::new(size=18.0, weight=500),
      color: @core.Color::black(),
      align: @core.TextAlign::TextStart,
    }),
  ])
  inspect(renderer.text_vertices.length() > 0, content="true")
  inspect(glyph_atlas_entry_count(renderer.glyph_atlas) > 0, content="true")
}

///|
test "native renderer keeps text in draw item order" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=200.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::DrawText({
      text: "A",
      frame: @core.Rect::new(x=0.0, y=0.0, width=40.0, height=20.0),
      font: @core.FontSpec::new(size=16.0, weight=500),
      color: @core.Color::black(),
      align: @core.TextAlign::TextCenter,
    }),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=20.0, width=10.0, height=10.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::DrawText({
      text: "B",
      frame: @core.Rect::new(x=0.0, y=40.0, width=40.0, height=20.0),
      font: @core.FontSpec::new(size=16.0, weight=500),
      color: @core.Color::black(),
      align: @core.TextAlign::TextCenter,
    }),
  ])
  inspect(renderer.draw_items.length(), content="3")
  assert_true(renderer.draw_items[0] is NativeDrawItem::NativeText(_, _, _))
  assert_true(renderer.draw_items[1] is NativeDrawItem::NativeVisual(_, _, _))
  assert_true(renderer.draw_items[2] is NativeDrawItem::NativeText(_, _, _))
}

///|
test "native renderer applies text alignment" {
  let font = @core.FontSpec::new(size=16.0, weight=500)
  let frame = @core.Rect::new(x=10.0, y=0.0, width=160.0, height=24.0)
  let left = new_test_renderer_handle()
  left.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=120.0),
    ),
  )
  left.render([
    @core.DrawCommand::DrawText({
      text: "Align",
      frame,
      font,
      color: @core.Color::black(),
      align: @core.TextAlign::TextStart,
    }),
  ])
  let centered = new_test_renderer_handle()
  centered.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=120.0),
    ),
  )
  centered.render([
    @core.DrawCommand::DrawText({
      text: "Align",
      frame,
      font,
      color: @core.Color::black(),
      align: @core.TextAlign::TextCenter,
    }),
  ])
  assert_true(left.text_vertices.length() > 0)
  assert_true(centered.text_vertices.length() > 0)
  assert_true(centered.text_vertices[0].x > left.text_vertices[0].x)
}

///|
test "native renderer vertically centers text in taller frames" {
  let command = @core.DrawCommand::DrawText({
    text: "Center",
    frame: @core.Rect::new(x=0.0, y=20.0, width=160.0, height=44.0),
    font: @core.FontSpec::new(size=16.0, weight=500),
    color: @core.Color::black(),
    align: @core.TextAlign::TextStart,
  })
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=120.0),
    ),
  )
  renderer.render([command])
  assert_true(renderer.text_vertices.length() > 0)
  let top = text_vertex_min_y(renderer.text_vertices, 120.0)
  assert_true(top > 20.0)
}

///|
test "native renderer keeps text logical vertices stable across dpr" {
  let command = @core.DrawCommand::DrawText({
    text: "DPR",
    frame: @core.Rect::new(x=20.0, y=10.0, width=160.0, height=32.0),
    font: @core.FontSpec::new(size=18.0, weight=500),
    color: @core.Color::black(),
    align: @core.TextAlign::TextStart,
  })
  let scale_one = new_test_renderer_handle()
  scale_one.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=120.0),
      scale_factor=1.0,
    ),
  )
  scale_one.render([command])
  let scale_two = new_test_renderer_handle()
  scale_two.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=120.0),
      scale_factor=2.0,
    ),
  )
  scale_two.render([command])
  assert_true(scale_one.text_vertices.length() > 0)
  assert_true(scale_two.text_vertices.length() > 0)
  let delta = (text_vertex_x_to_pixel(scale_one.text_vertices[0], 320.0) -
  text_vertex_x_to_pixel(scale_two.text_vertices[0], 320.0)).abs()
  assert_true(delta <= 1.0)
  assert_true(
    scale_two.glyph_atlas.shelf_height > scale_one.glyph_atlas.shelf_height,
  )
}

///|
fn text_vertex_x_to_pixel(vertex : TextVertex, width : Double) -> Double {
  (vertex.x + 1.0) * width / 2.0
}

///|
fn text_vertex_min_y(vertices : Array[TextVertex], height : Double) -> Double {
  let mut min_y = height
  for vertex in vertices {
    let y = (1.0 - vertex.y) * height / 2.0
    if y < min_y {
      min_y = y
    }
  }
  min_y
}

///|
test "native renderer clears glyph atlas when dpr changes" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=120.0),
      scale_factor=1.0,
    ),
  )
  renderer.render([
    @core.DrawCommand::DrawText({
      text: "Scale",
      frame: @core.Rect::new(x=0.0, y=0.0, width=120.0, height=32.0),
      font: @core.FontSpec::new(size=16.0, weight=500),
      color: @core.Color::black(),
      align: @core.TextAlign::TextStart,
    }),
  ])
  assert_true(glyph_atlas_entry_count(renderer.glyph_atlas) > 0)
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=120.0),
      scale_factor=2.0,
    ),
  )
  inspect(glyph_atlas_entry_count(renderer.glyph_atlas), content="0")
}
