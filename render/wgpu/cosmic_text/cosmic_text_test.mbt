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

///|
fn cosmic_text_carets_are_monotonic(carets : Array[Double]) -> Bool {
  if carets.length() <= 1 {
    return true
  }
  for index in 1..<carets.length() {
    if carets[index] < carets[index - 1] {
      return false
    }
  }
  true
}

///|
test "cosmic text engine conforms for mixed cjk emoji and bidi text" {
  let system = @wgpu_renderer.native_text_system_with_engine(
    cosmic_text_engine(),
  )
  let text = "a你🙂 אבג"
  let measured = system.measure_text(
    @core.TextLayoutInput::new(
      text~,
      font=@core.FontSpec::new(size=17.0, weight=500),
    ),
  )
  inspect(measured.size.width > 0.0, content="true")
  inspect(measured.size.height > 0.0, content="true")
  inspect(measured.baseline > 0.0, content="true")
  inspect(
    measured.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  inspect(
    cosmic_text_carets_are_monotonic(measured.caret_positions),
    content="true",
  )
  let clamped = system.measure_text(
    @core.TextLayoutInput::new(
      text~,
      font=@core.FontSpec::new(size=17.0, weight=500),
      max_width=24.0,
    ),
  )
  inspect(clamped.size.width <= 24.0, content="true")
  inspect(
    cosmic_text_carets_are_monotonic(clamped.caret_positions),
    content="true",
  )
  for caret in clamped.caret_positions {
    inspect(caret <= 24.0, content="true")
  }
}
