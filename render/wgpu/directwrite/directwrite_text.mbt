///|
pub fn directwrite_text_engine() -> @wgpu_renderer.NativeTextEngine {
  @wgpu_renderer.native_platform_text_engine(
    @wgpu_renderer.NativePlatformTextProvider::new(
      id="native-wgpu-directwrite-planned",
      measure=_input => None,
      layout_run=(_run, _scale_factor) => None,
      raster_glyph=_payload => None,
      register_font_data=(_family, _data) => (),
    ),
  )
}
