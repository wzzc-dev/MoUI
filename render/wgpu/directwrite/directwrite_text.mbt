///|
pub fn directwrite_text_engine() -> @wgpu_renderer.NativeTextEngine {
  @wgpu_renderer.native_platform_text_engine(
    @wgpu_renderer.NativePlatformTextProvider::new(
      id="native-wgpu-directwrite-planned",
      measure=directwrite_measure_layout,
      layout_run=directwrite_layout_run,
      raster_glyph=directwrite_raster_glyph,
      register_font_data=directwrite_register_font_data,
    ),
  )
}

///|
fn directwrite_register_font_data(
  family : @core.FontFamily,
  data : Bytes,
) -> Unit {
  ignore(
    windows_directwrite_register_font_data(
      @text_protocol.native_font_registration_bytes(
        family_name=@utf8.encode(family.css_name()[:], bom=false),
        data~,
      ),
    ),
  )
}

///|
#borrow(payload)
fn directwrite_raster_glyph(
  payload : Bytes,
) -> @wgpu_renderer.NativeRasterGlyph? {
  @text_protocol.native_raster_glyph_from_bytes(
    windows_directwrite_raster_glyph(payload),
  )
}

///|
fn directwrite_layout_run(
  run : @core.TextRun,
  scale_factor : Double,
) -> @wgpu_renderer.NativeTextLayout? {
  @text_protocol.native_run_layout_from_bytes(
    windows_directwrite_layout_run_utf32(
      @text_protocol.native_utf32_bytes(run.text),
      @text_protocol.native_font_spec_bytes(run.font),
      run.frame.size.width,
      scale_factor,
    ),
  )
}

///|
fn directwrite_measure_layout(
  input : @core.TextLayoutInput,
) -> @wgpu_renderer.NativeTextLayout? {
  @text_protocol.native_measure_layout_from_bytes(
    input,
    windows_directwrite_measure_utf32(
      @text_protocol.native_utf32_bytes(input.text),
      @text_protocol.native_font_spec_bytes(input.font),
    ),
  )
}

///|
#borrow(utf32, font_spec)
extern "C" fn windows_directwrite_measure_utf32(
  utf32 : Bytes,
  font_spec : Bytes,
) -> Bytes = "moui_windows_directwrite_measure_utf32"

///|
#borrow(utf32, font_spec)
extern "C" fn windows_directwrite_layout_run_utf32(
  utf32 : Bytes,
  font_spec : Bytes,
  max_width : Double,
  scale_factor : Double,
) -> Bytes = "moui_windows_directwrite_layout_run_utf32"

///|
#borrow(payload)
extern "C" fn windows_directwrite_raster_glyph(payload : Bytes) -> Bytes = "moui_windows_directwrite_raster_glyph"

///|
#borrow(payload)
extern "C" fn windows_directwrite_register_font_data(payload : Bytes) -> Int = "moui_windows_directwrite_register_font_data"
