///|
test "directwrite provider is an explicit fallback scaffold" {
  let system = @wgpu_renderer.native_text_system_with_engine(
    directwrite_text_engine(),
  )
  inspect(system.id(), content="native-wgpu-directwrite-planned")
}

///|
test "directwrite provider delegates empty stub to shared text protocol" {
  let input = @core.TextLayoutInput::new(
    text="fallback",
    font=@core.FontSpec::new(size=14.0, weight=400),
  )
  inspect(directwrite_measure_layout(input) is None, content="true")
}

///|
test "directwrite native protocol versions match shared text protocol" {
  inspect(
    windows_directwrite_debug_font_spec_protocol_version(),
    content="\{@text_protocol.native_font_spec_protocol_version}",
  )
  inspect(
    windows_directwrite_debug_font_registration_protocol_version(),
    content="\{@text_protocol.native_font_registration_protocol_version}",
  )
}

///|
test "directwrite native stub parses versioned font spec payload" {
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
  inspect(
    windows_directwrite_debug_font_spec_family_count(font_spec),
    content="3",
  )
  inspect(
    windows_directwrite_debug_font_spec_family_count(
      Bytes::from_array([b'\x01']),
    ),
    content="-1",
  )
}

///|
test "directwrite run layout delegates native stub to shared text protocol" {
  let run = @core.TextRun::new(
    text="fallback",
    frame=@core.Rect::new(x=0.0, y=0.0, width=120.0, height=24.0),
    font=@core.FontSpec::new(size=14.0, weight=400),
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  inspect(directwrite_layout_run(run, 1.0) is None, content="true")
}

///|
test "directwrite raster delegates native stub to shared text protocol" {
  inspect(
    directwrite_raster_glyph(
      "test-directwrite:invalid",
      Bytes::from_array([b'\x01']),
    )
    is None,
    content="true",
  )
}

///|
test "directwrite register font data reaches native stub" {
  directwrite_register_font_data(
    @core.FontFamily::Name("Acme"),
    Bytes::from_array([b'\x01', b'\x02']),
  )
  inspect("ok", content="ok")
}

///|
test "directwrite native stub parses font registration payload" {
  let payload = @text_protocol.native_font_registration_bytes(
    family_name=Bytes::from_array([b'A', b'c', b'm', b'e']),
    data=Bytes::from_array([b'\x01', b'\x02', b'\x03']),
  )
  inspect(
    windows_directwrite_debug_font_registration_data_len(payload),
    content="3",
  )
  inspect(
    windows_directwrite_debug_font_registration_data_len(
      Bytes::from_array([b'\x01']),
    ),
    content="-1",
  )
}

///|
#borrow(font_spec)
extern "C" fn windows_directwrite_debug_font_spec_family_count(
  font_spec : Bytes,
) -> Int = "moui_windows_directwrite_debug_font_spec_family_count"

///|
extern "C" fn windows_directwrite_debug_font_spec_protocol_version() -> Int = "moui_windows_directwrite_debug_font_spec_protocol_version"

///|
extern "C" fn windows_directwrite_debug_font_registration_protocol_version() -> Int = "moui_windows_directwrite_debug_font_registration_protocol_version"

///|
#borrow(payload)
extern "C" fn windows_directwrite_debug_font_registration_data_len(
  payload : Bytes,
) -> Int = "moui_windows_directwrite_debug_font_registration_data_len"
