///|
test "cosmic text engine is exposed as standalone provider package" {
  let measurer = @wgpu_renderer.native_text_measurer_with_engine(
    cosmic_text_engine(),
  )
  inspect(measurer.id(), content="native-wgpu-cosmic-fallback")
}
