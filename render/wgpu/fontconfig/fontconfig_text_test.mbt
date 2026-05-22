///|
test "fontconfig provider is an explicit fallback scaffold" {
  let measurer = @wgpu_renderer.native_text_measurer_with_engine(
    fontconfig_text_engine(),
  )
  inspect(
    measurer.id(),
    content="native-wgpu-fontconfig-harfbuzz-freetype-planned",
  )
}
