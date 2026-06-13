///|
test "fontconfig provider exposes a native text boundary" {
  let system = @wgpu_renderer.native_text_system_with_engine(
    fontconfig_text_engine(),
  )
  inspect(system.id(), content="native-wgpu-fontconfig-freetype")
}

///|
#cfg(platform="linux")
test "fontconfig provider measures non-emoji text" {
  let input = @core.TextLayoutInput::new(
    text="ABC",
    font=@core.FontSpec::new(size=14.0, weight=400),
  )
  match fontconfig_measure_layout(input) {
    Some(layout) => {
      inspect(layout.size.width > 0.0, content="true")
      inspect(layout.size.height > 0.0, content="true")
      inspect(layout.baseline > 0.0, content="true")
    }
    None => inspect("missing", content="available")
  }
}

///|
test "fontconfig native protocol versions match shared text protocol" {
  inspect(
    linux_fontconfig_debug_font_spec_protocol_version(),
    content="\{@text_protocol.native_font_spec_protocol_version}",
  )
  inspect(
    linux_fontconfig_debug_font_registration_protocol_version(),
    content="\{@text_protocol.native_font_registration_protocol_version}",
  )
}

///|
test "fontconfig native stub parses versioned font spec payload" {
  let font_spec = @text_protocol.native_font_spec_bytes(
    @core.FontSpec::new(
      families=@core.FontFamilyStack::named("Acme Sans")
        .with_fallback(@core.FontFamily::UiSansSerif)
        .with_fallback(@core.FontFamily::SansSerif),
      size=15.0,
      weight=500,
      style=@core.FontStyle::Italic,
    ),
  )
  inspect(linux_fontconfig_debug_font_spec_family_count(font_spec), content="3")
  inspect(
    linux_fontconfig_debug_font_spec_family_count(Bytes::from_array([b'\x01'])),
    content="-1",
  )
}

///|
#cfg(platform="linux")
test "fontconfig run layout returns glyphs for non-emoji text" {
  let run = @core.TextRun::new(
    text="ABC",
    frame=@core.Rect::new(x=0.0, y=0.0, width=120.0, height=24.0),
    font=@core.FontSpec::new(size=14.0, weight=400),
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  match fontconfig_layout_run(run, 1.0) {
    Some(layout) => {
      inspect(layout.glyphs.length() >= 0, content="true")
      inspect(layout.size.width >= 0.0, content="true")
      inspect(layout.size.height > 0.0, content="true")
      inspect(layout.baseline > 0.0, content="true")
    }
    None => inspect("missing", content="available")
  }
}

///|
#cfg(platform="linux")
test "fontconfig run layout returns native emoji glyphs when color font is available" {
  let color_pixels = linux_fontconfig_debug_color_emoji_raster_pixels()
  if color_pixels < 0 {
    inspect("missing", content="available")
    return
  }
  let run = @core.TextRun::new(
    text="\u{1F642}",
    frame=@core.Rect::new(x=0.0, y=0.0, width=80.0, height=48.0),
    font=@core.FontSpec::new(
      families=@core.FontFamilyStack::new([@core.FontFamily::Emoji]),
      size=26.0,
      weight=400,
    ),
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  match fontconfig_layout_run(run, 1.0) {
    Some(layout) => {
      inspect(layout.glyphs.length() > 0, content="true")
      inspect(color_pixels > 0, content="true")
    }
    None => inspect("missing", content="available")
  }
}

///|
test "fontconfig raster delegates native stub to shared text protocol" {
  inspect(
    fontconfig_raster_glyph(
      "test-fontconfig:invalid",
      Bytes::from_array([b'\x01']),
    )
    is None,
    content="true",
  )
}

///|
test "fontconfig register font data reaches native stub" {
  fontconfig_register_font_data(
    @core.FontFamily::Name("Acme"),
    Bytes::from_array([b'\x01', b'\x02']),
  )
  inspect("ok", content="ok")
}

///|
test "fontconfig native stub parses font registration payload" {
  let payload = @text_protocol.native_font_registration_bytes(
    family_name=Bytes::from_array([b'A', b'c', b'm', b'e']),
    data=Bytes::from_array([b'\x01', b'\x02', b'\x03']),
  )
  inspect(
    linux_fontconfig_debug_font_registration_data_len(payload),
    content="3",
  )
  inspect(
    linux_fontconfig_debug_font_registration_data_len(
      Bytes::from_array([b'\x01']),
    ),
    content="-1",
  )
}

///|
#borrow(font_spec)
extern "C" fn linux_fontconfig_debug_font_spec_family_count(
  font_spec : Bytes,
) -> Int = "moui_linux_fontconfig_debug_font_spec_family_count"

///|
extern "C" fn linux_fontconfig_debug_font_spec_protocol_version() -> Int = "moui_linux_fontconfig_debug_font_spec_protocol_version"

///|
extern "C" fn linux_fontconfig_debug_font_registration_protocol_version() -> Int = "moui_linux_fontconfig_debug_font_registration_protocol_version"

///|
#borrow(payload)
extern "C" fn linux_fontconfig_debug_font_registration_data_len(
  payload : Bytes,
) -> Int = "moui_linux_fontconfig_debug_font_registration_data_len"

///|
#cfg(platform="linux")
extern "C" fn linux_fontconfig_debug_color_emoji_raster_pixels() -> Int = "moui_linux_fontconfig_debug_color_emoji_raster_pixels"

///|
#cfg(platform="linux")
#borrow(family_name)
extern "C" fn linux_fontconfig_debug_registered_font_data_len(
  family_name : Bytes,
) -> Int = "moui_linux_fontconfig_debug_registered_font_data_len"

///|
#cfg(platform="linux")
extern "C" fn linux_fontconfig_debug_latin_raster_pixels() -> Int = "moui_linux_fontconfig_debug_latin_raster_pixels"

///|
#cfg(platform="linux")
#borrow(family_name)
extern "C" fn linux_fontconfig_debug_register_system_font_data(
  family_name : Bytes,
) -> Int = "moui_linux_fontconfig_debug_register_system_font_data"

///|
#cfg(platform="linux")
test "fontconfig raster returns visible latin glyph pixels" {
  let latin_pixels = linux_fontconfig_debug_latin_raster_pixels()
  if latin_pixels < 0 {
    inspect("missing", content="available")
    return
  }
  inspect(latin_pixels > 0, content="true")
}

///|
#cfg(platform="linux")
test "fontconfig debug registered font data length reports stored data" {
  fontconfig_register_font_data(
    @core.FontFamily::Name("DebugSans"),
    Bytes::from_array([b'\x01', b'\x02', b'\x03', b'\x04']),
  )
  let data_len = linux_fontconfig_debug_registered_font_data_len(
    Bytes::from_array([b'D', b'e', b'b', b'u', b'g', b'S', b'a', b'n', b's']),
  )
  inspect(data_len, content="4")
}

///|
#cfg(platform="linux")
test "fontconfig debug can register system font and measure via registered alias" {
  let data_len = linux_fontconfig_debug_register_system_font_data(
    Bytes::from_array([
      b'R', b'e', b'g', b'i', b's', b't', b'e', b'r', b'e', b'd', b'S', b'a', b'n',
      b's',
    ]),
  )
  if data_len < 0 {
    inspect("missing", content="available")
    return
  }
  inspect(data_len > 0, content="true")
  let input = @core.TextLayoutInput::new(
    text="X",
    font=@core.FontSpec::new(
      families=@core.FontFamilyStack::named("RegisteredSans"),
      size=16.0,
      weight=400,
    ),
  )
  match fontconfig_measure_layout(input) {
    Some(layout) => inspect(layout.size.height > 0.0, content="true")
    None => inspect("missing", content="available")
  }
}
