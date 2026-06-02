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
fn assert_diagnostic_native_text_matrix(
  system : @core.TextSystem,
) -> Unit raise {
  assert_diagnostic_native_text_layout(system, "abc")
  assert_diagnostic_native_text_layout(system, "你好")
  assert_diagnostic_native_text_layout(system, "🙂")
  assert_diagnostic_native_text_layout(system, "☕")
  assert_diagnostic_native_text_layout(system, "☕️")
  assert_diagnostic_native_text_layout(system, "👩‍💻")
  assert_diagnostic_native_text_layout(system, "a你🙂b")
  assert_diagnostic_native_text_layout(system, "text 👩‍💻 🙂")
  assert_diagnostic_native_text_layout(system, "abc אבג def")
  assert_diagnostic_native_text_layout(system, "กิ")
  assert_diagnostic_native_text_layout(system, "ກິ")
  assert_diagnostic_native_text_layout(system, "කා")
  assert_diagnostic_native_text_layout(system, "កា")
  assert_diagnostic_native_text_layout(system, "ក្រ")
  assert_diagnostic_native_text_layout(system, "က်")
  assert_diagnostic_native_text_layout(system, "က္ခ")
}

///|
fn diagnostic_native_text_field_view(
  value : @core.Binding[String],
) -> @core.View[Unit] {
  @core.View::text_field(
    value~,
    placeholder="Input",
    size=@core.Size::new(width=180.0, height=40.0),
    font=@core.FontSpec::new(size=18.0, weight=500),
    foreground=@core.Color::black(),
    placeholder_color=@core.Color::gray(),
    background=@core.Brush::solid(@core.Color::white()),
    cursor_color=@core.Color::blue(),
    corner_radius=4.0,
  )
}

///|
fn focus_diagnostic_native_text_field(runtime : @core.AppRuntime) -> Unit {
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
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
test "diagnostic native skia text system matrix conforms" {
  assert_diagnostic_native_text_matrix(@skia_renderer.skia_text_system())
}

///|
test "diagnostic native skia text system drives runtime text field geometry" {
  let value = @core.State::new("")
  let runtime = @core.AppRuntime::new_view(
    root=diagnostic_native_text_field_view(value.binding()),
    size=@core.Size::new(width=220.0, height=80.0),
  )
  let skia_system = @skia_renderer.skia_text_system()
  runtime.set_text_system(skia_system)
  focus_diagnostic_native_text_field(runtime)
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::CompositionStart),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(
      @core.TextInputEvent::CompositionUpdate(
        @core.CompositionUpdate::new(
          text="你🙂a",
          cursor=Some(@core.TextRange::new(start=2, end=2)),
        ),
      ),
    ),
  )
  let composing = runtime.focused_text_input()
  guard composing.composition is Some(composition) else {
    fail("expected Skia-backed composition preview")
  }
  inspect(composition, content="你🙂a")
  let font = @core.FontSpec::new(size=18.0, weight=500)
  let layout = skia_system.measure_text(
    @core.TextLayoutInput::new(text="你🙂a", font~, max_width=160.0),
  )
  assert_true(composing.caret_rect.origin.x > 10.0)
  assert_true(composing.caret_rect.origin.x == 10.0 + layout.caret_positions[2])

  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::CompositionEnd("你🙂a")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    ),
  )
  let selected = runtime.focused_text_input()
  guard selected.selection is Some(selection) else {
    fail("expected Skia-backed text field selection")
  }
  inspect(selection.normalized().start, content="2")
  inspect(selection.normalized().end, content="3")
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      match command {
        @core.DrawCommand::FillRect(_, color) => color.a == 0.18
        _ => false
      }
    }),
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
