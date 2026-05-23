///|
test "cosmic text engine is exposed as standalone provider package" {
  let system = @wgpu_renderer.native_text_system_with_engine(
    cosmic_text_engine(),
  )
  inspect(system.id(), content="native-wgpu-cosmic-fallback")
}

///|
test "cosmic text engine measures through provider callback" {
  let system = @wgpu_renderer.native_text_system_with_engine(
    cosmic_text_engine(),
  )
  let measured = system.measure_text(
    @core.TextLayoutInput::new(
      text="fallback",
      font=@core.FontSpec::new(size=14.0, weight=400),
    ),
  )
  inspect(measured.size.width > 0.0, content="true")
  inspect(measured.caret_positions.length(), content="9")
}
