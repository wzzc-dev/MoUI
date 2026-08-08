///|
fn diagnostic_web_carets_are_monotonic(carets : Array[Double]) -> Bool {
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
fn diagnostic_web_port() -> @webgpu_adapter.WebGpuHostRendererPort {
  @webgpu_adapter.WebGpuHostRendererPort::new(
    capabilities=() => @webgpu_adapter.required_capabilities(),
    create_surface=(canvas_id, metrics) => {
      @webgpu_adapter.WebGpuHostSurface::new(canvas_id~, metrics~)
    },
    create_renderer=_surface => (),
    resize=(_metrics : @core.SurfaceMetrics) => (),
    measure_text=input => @core.TextSystem::fallback().measure_text(input),
    register_font_data=(_family, _data) => (),
    image_resource=_source => None,
    submit=_calls => (),
    dispose=() => (),
  )
}

///|
fn assert_diagnostic_web_text_layout(
  system : @core.TextSystem,
  text : String,
) -> Unit raise {
  let font = @core.FontSpec::new(size=16.0, weight=400)
  let measured = system.measure_text(@core.TextLayoutInput::new(text~, font~))
  inspect(measured.size.width > 0.0, content="true")
  inspect(measured.size.height > 0.0, content="true")
  inspect(
    measured.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  inspect(
    diagnostic_web_carets_are_monotonic(measured.caret_positions),
    content="true",
  )
  let clamped = system.measure_text(
    @core.TextLayoutInput::new(text~, font~, max_width=24.0),
  )
  inspect(clamped.size.width <= 24.0, content="true")
  inspect(
    diagnostic_web_carets_are_monotonic(clamped.caret_positions),
    content="true",
  )
  for caret in clamped.caret_positions {
    inspect(caret <= 24.0, content="true")
  }
}

///|
fn assert_diagnostic_web_text_matrix(system : @core.TextSystem) -> Unit raise {
  assert_diagnostic_web_text_layout(system, "abc")
  assert_diagnostic_web_text_layout(system, "你好")
  assert_diagnostic_web_text_layout(system, "🙂")
  assert_diagnostic_web_text_layout(system, "☕")
  assert_diagnostic_web_text_layout(system, "☕️")
  assert_diagnostic_web_text_layout(system, "👩‍💻")
  assert_diagnostic_web_text_layout(system, "a你🙂b")
  assert_diagnostic_web_text_layout(system, "text 👩‍💻 🙂")
  assert_diagnostic_web_text_layout(system, "abc אבג def")
}

///|
test "diagnostic web core fallback engine matrix conforms" {
  assert_diagnostic_web_text_matrix(@core.TextSystem::fallback())
}

///|
test "diagnostic web host text system matrix conforms" {
  let renderer = @webgpu_adapter.create_renderer(
    canvas_id="text-conformance",
    logical_size=@core.Size::new(width=120.0, height=60.0),
    port=diagnostic_web_port(),
  )
  assert_diagnostic_web_text_matrix(renderer.text_system())
}
