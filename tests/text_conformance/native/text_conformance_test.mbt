///|
fn diagnostic_native_carets_are_monotonic(carets : Array[Double]) -> Bool {
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
fn assert_diagnostic_native_text_layout(
  system : @core.TextSystem,
  text : String,
) -> Unit raise {
  let font = @core.FontSpec::new(size=18.0, weight=500)
  let measured = system.measure_text(@core.TextLayoutInput::new(text~, font~))
  inspect(measured.size.width > 0.0, content="true")
  inspect(measured.size.height > 0.0, content="true")
  inspect(measured.baseline > 0.0, content="true")
  inspect(
    measured.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  inspect(
    diagnostic_native_carets_are_monotonic(measured.caret_positions),
    content="true",
  )
  let clamped = system.measure_text(
    @core.TextLayoutInput::new(text~, font~, max_width=36.0),
  )
  inspect(clamped.size.width <= 36.0, content="true")
  inspect(
    clamped.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  inspect(
    diagnostic_native_carets_are_monotonic(clamped.caret_positions),
    content="true",
  )
  for caret in clamped.caret_positions {
    inspect(caret <= 36.0, content="true")
  }
}

///|
fn assert_diagnostic_native_text_matrix(system : @core.TextSystem) -> Unit raise {
  assert_diagnostic_native_text_layout(system, "abc")
  assert_diagnostic_native_text_layout(system, "你好")
  assert_diagnostic_native_text_layout(system, "🙂")
  assert_diagnostic_native_text_layout(system, "☕")
  assert_diagnostic_native_text_layout(system, "☕️")
  assert_diagnostic_native_text_layout(system, "👩‍💻")
  assert_diagnostic_native_text_layout(system, "a你🙂b")
  assert_diagnostic_native_text_layout(system, "text 👩‍💻 🙂")
  assert_diagnostic_native_text_layout(system, "abc אבג def")
}

///|
test "diagnostic native core fallback engine matrix conforms" {
  assert_diagnostic_native_text_matrix(@core.TextSystem::fallback())
}

///|
test "diagnostic native cosmic engine matrix conforms" {
  assert_diagnostic_native_text_matrix(
    @wgpu_renderer.native_text_system_with_engine(
      @cosmic_text.cosmic_text_engine(),
    ),
  )
}

///|
test "diagnostic native directwrite scaffold matrix uses cosmic fallback" {
  assert_diagnostic_native_text_matrix(
    @wgpu_renderer.native_text_system_with_engine(
      @wgpu_renderer.native_platform_text_engine_with_fallback(
        @directwrite.directwrite_text_provider(),
        fallback=@cosmic_text.cosmic_text_engine(),
      ),
    ),
  )
}

///|
test "diagnostic native fontconfig scaffold matrix uses cosmic fallback" {
  assert_diagnostic_native_text_matrix(
    @wgpu_renderer.native_text_system_with_engine(
      @wgpu_renderer.native_platform_text_engine_with_fallback(
        @fontconfig.fontconfig_text_provider(),
        fallback=@cosmic_text.cosmic_text_engine(),
      ),
    ),
  )
}

///|
test "diagnostic native composed fallback keeps malformed providers safe" {
  let system = @wgpu_renderer.native_text_system_with_engine(
    @wgpu_renderer.native_platform_text_engine_with_fallback(
      @wgpu_renderer.NativePlatformTextProvider::new(
        id="diagnostic-bad-provider",
        measure=_input => {
          Some(
            @wgpu_renderer.NativeTextLayout::new(
              size=@core.Size::new(width=50.0, height=20.0),
              baseline=12.0,
              caret_positions=[0.0, 32.0, 16.0],
            ),
          )
        },
        layout_run=(_run, _scale) => None,
        raster_glyph=(_cache_key, _payload) => None,
      ),
      fallback=@cosmic_text.cosmic_text_engine(),
    ),
  )
  assert_diagnostic_native_text_matrix(system)
}
