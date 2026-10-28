///|
fn test_fallback_text_engine() -> NativeTextEngine {
  native_platform_text_engine(test_fallback_text_provider())
}

///|
fn test_fallback_text_provider() -> NativePlatformTextProvider {
  NativePlatformTextProvider::new(
    id="test-fallback-text",
    measure=input => {
      let char_count = input.text.to_array().length()
      let width = char_count.to_double() * input.font.size * 0.5
      let carets : Array[Double] = []
      for index in 0..<=char_count {
        carets.push(index.to_double() * input.font.size * 0.5)
      }
      Some(
        NativeTextLayout::new(
          size=@core.Size::new(width~, height=input.font.size * 1.25),
          baseline=input.font.size * 0.8,
          caret_positions=carets,
        ),
      )
    },
    layout_run=(_run, _scale) => None,
    raster_glyph=(_cache_key, _payload) => None,
  )
}

///|
test "native text system exposes default fallback engine id" {
  inspect(native_text_system().id(), content="native-noop-text")
}

///|
test "native text provider values have stable constructors" {
  let key = native_platform_glyph_key(
    cache_key="test-platform:constructor",
    payload=Bytes::from_array([b'\x01']),
  )
  let placement = NativeGlyphPlacement::new(key~, x=3.0, y=4.0)
  inspect(placement.x(), content="3")
  inspect(placement.y(), content="4")
  let layout = NativeTextLayout::new(
    size=@core.Size::new(width=12.0, height=18.0),
    baseline=11.0,
    caret_positions=[0.0, 12.0],
    glyphs=[placement],
  )
  inspect(layout.size().width, content="12")
  inspect(layout.baseline(), content="11")
  inspect(layout.caret_positions().length(), content="2")
  inspect(layout.glyphs().length(), content="1")
  let glyph = NativeRasterGlyph::new(
    width=2,
    height=2,
    bearing_x=1,
    bearing_y=-2,
    pixels=Bytes::from_array([b'\x00', b'\xff', b'\xff', b'\x00']),
  )
  inspect(glyph.width(), content="2")
  inspect(glyph.height(), content="2")
  inspect(glyph.pixels().length(), content="4")
}

///|
test "native platform provider receives registered font data before fallback cache" {
  let registered : Ref[Int32] = Ref(0)
  let family_name : Ref[String] = Ref("")
  let data_len : Ref[Int32] = Ref(0)
  let fallback_registered : Ref[Int32] = Ref(0)
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
    Name("Acme"),
    Bytes::from_array([b'A', b'c', b'm', b'e']),
  )
  inspect(registered.val, content="1")
  inspect(fallback_registered.val, content="1")
  inspect(family_name.val, content="Acme")
  inspect(data_len.val, content="4")
}

///|
test "native text engine keeps explicit fallback path available" {
  let cache = NativeTextCache::new_with_engine(test_fallback_text_engine())
  let input = @core.TextLayoutInput::new(
    text="fallback",
    font=@core.FontSpec::new(size=14.0, weight=400),
  )
  let measured = cache.measure(input)
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
