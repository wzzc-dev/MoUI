///|
test "directwrite provider is an explicit fallback scaffold" {
  let measurer = @wgpu_renderer.native_text_measurer_with_engine(
    directwrite_text_engine(),
  )
  inspect(measurer.id(), content="native-wgpu-directwrite-planned")
}
