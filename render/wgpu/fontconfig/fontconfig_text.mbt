///|
pub fn fontconfig_text_engine() -> @wgpu_renderer.NativeTextEngine {
  @wgpu_renderer.native_platform_text_engine(
    @wgpu_renderer.NativePlatformTextProvider::new(
      id="native-wgpu-fontconfig-harfbuzz-freetype-planned",
      measure=fontconfig_measure_layout,
      layout_run=fontconfig_layout_run,
      raster_glyph=fontconfig_raster_glyph,
      register_font_data=fontconfig_register_font_data,
    ),
  )
}

///|
fn fontconfig_register_font_data(
  family : @core.FontFamily,
  data : Bytes,
) -> Unit {
  ignore(
    linux_fontconfig_register_font_data(
      @text_protocol.native_font_registration_bytes(
        family_name=@utf8.encode(family.css_name()[:], bom=false),
        data~,
      ),
    ),
  )
}

///|
#borrow(payload)
fn fontconfig_raster_glyph(
  payload : Bytes,
) -> @wgpu_renderer.NativeRasterGlyph? {
  @text_protocol.native_raster_glyph_from_bytes(
    linux_fontconfig_raster_glyph(payload),
  )
}

///|
fn fontconfig_layout_run(
  run : @core.TextRun,
  scale_factor : Double,
) -> @wgpu_renderer.NativeTextLayout? {
  @text_protocol.native_run_layout_from_bytes(
    linux_fontconfig_layout_run_utf32(
      @text_protocol.native_utf32_bytes(run.text),
      @text_protocol.native_font_spec_bytes(run.font),
      run.frame.size.width,
      scale_factor,
    ),
  )
}

///|
fn fontconfig_measure_layout(
  input : @core.TextLayoutInput,
) -> @wgpu_renderer.NativeTextLayout? {
  @text_protocol.native_measure_layout_from_bytes(
    input,
    linux_fontconfig_measure_utf32(
      @text_protocol.native_utf32_bytes(input.text),
      @text_protocol.native_font_spec_bytes(input.font),
    ),
  )
}

///|
#borrow(utf32, font_spec)
extern "C" fn linux_fontconfig_measure_utf32(
  utf32 : Bytes,
  font_spec : Bytes,
) -> Bytes = "moui_linux_fontconfig_measure_utf32"

///|
#borrow(utf32, font_spec)
extern "C" fn linux_fontconfig_layout_run_utf32(
  utf32 : Bytes,
  font_spec : Bytes,
  max_width : Double,
  scale_factor : Double,
) -> Bytes = "moui_linux_fontconfig_layout_run_utf32"

///|
#borrow(payload)
extern "C" fn linux_fontconfig_raster_glyph(payload : Bytes) -> Bytes = "moui_linux_fontconfig_raster_glyph"

///|
#borrow(payload)
extern "C" fn linux_fontconfig_register_font_data(payload : Bytes) -> Int = "moui_linux_fontconfig_register_font_data"
