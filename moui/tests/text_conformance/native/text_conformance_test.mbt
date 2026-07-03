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
  let font = diagnostic_native_text_font()
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
fn diagnostic_native_text_font() -> @core.FontSpec {
  @core.FontSpec::new(size=18.0, weight=500)
}

///|
fn assert_diagnostic_native_skia_maturity_gap(gap : String) -> Unit raise {
  let description = @skia_renderer.backend_info().description
  assert_true(description.contains("text maturity audit partial"))
  assert_true(
    description.contains("tracked gaps pending") ||
    description.contains("tracked gaps resolved")
  )
  assert_true(
    description.contains("\{gap} pending") ||
    description.contains("\{gap} confirmed")
  )
}

///|
fn assert_diagnostic_native_skia_maturity_ready(signal : String) -> Unit raise {
  let description = @skia_renderer.backend_info().description
  assert_true(description.contains("text maturity audit partial"))
  assert_true(description.contains(signal))
}

///|
fn assert_diagnostic_native_cluster_carets(
  system : @core.TextSystem,
  text : String,
  start : Int,
  end : Int,
) -> Unit raise {
  let layout = system.measure_text(
    @core.TextLayoutInput::new(text~, font=diagnostic_native_text_font()),
  )
  inspect(
    layout.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  assert_true(diagnostic_native_carets_are_monotonic(layout.caret_positions))
  assert_true(start >= 0)
  assert_true(end > start + 1)
  assert_true(end < layout.caret_positions.length())
  let anchor = layout.caret_positions[start]
  for index in (start + 1)..<end {
    assert_true(layout.caret_positions[index] == anchor)
  }
  assert_true(layout.caret_positions[end] > anchor)
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
  let field_style : @views.TextFieldStyle = {
    normal: {
      foreground: @core.Color::black(),
      background: @core.Brush::solid(@core.Color::white()),
      border: None,
      radius: 4.0,
      shadow: None,
      bottom_border_only: false,
      inner_focus_border: None,
    },
    focused: {
      foreground: @core.Color::black(),
      background: @core.Brush::solid(@core.Color::white()),
      border: None,
      radius: 4.0,
      shadow: None,
      bottom_border_only: false,
      inner_focus_border: None,
    },
    disabled: {
      foreground: @core.Color::black(),
      background: @core.Brush::solid(@core.Color::white()),
      border: None,
      radius: 4.0,
      shadow: None,
      bottom_border_only: false,
      inner_focus_border: None,
    },
    placeholder_color: @core.Color::gray(),
    cursor_color: @core.Color::blue(),
    font: @core.FontSpec::new(size=18.0, weight=500),
  }
  let mirror = @core.State::new(value.get())
  @views.text_field(
    mirror.get(),
    on_input=next => {
      mirror.set(next)
      value.set(next)
    },
    placeholder="Input",
    style=field_style,
    width=180.0,
    height=40.0,
  )
}

///|
fn focus_diagnostic_native_text_field(runtime : @runtime.AppRuntime) -> Unit {
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
test "diagnostic native skia bidi sample keeps logical carets and marks reordering ready" {
  let system = @skia_renderer.skia_text_system()
  let sample = "abc אבג def"
  assert_diagnostic_native_text_layout(system, sample)
  let layout = system.measure_text(
    @core.TextLayoutInput::new(text=sample, font=diagnostic_native_text_font()),
  )
  inspect(
    layout.caret_positions.length(),
    content="\{sample.to_array().length() + 1}",
  )
  assert_true(diagnostic_native_carets_are_monotonic(layout.caret_positions))
  assert_true(
    layout.caret_positions[layout.caret_positions.length() - 1] ==
    layout.size.width,
  )
  assert_diagnostic_native_skia_maturity_ready(
    "bidi and paragraph line breaking ready",
  )
}

///|
test "diagnostic native skia paragraph layout exposes line metrics and gates readiness" {
  let system = @skia_renderer.skia_text_system()
  let sample = "alpha beta gamma delta epsilon"
  let font = diagnostic_native_text_font()
  let unbounded = system.measure_text(
    @core.TextLayoutInput::new(text=sample, font~),
  )
  let max_width = 72.0
  let clamped = system.measure_text(
    @core.TextLayoutInput::new(text=sample, font~, max_width~),
  )
  assert_true(unbounded.size.width > max_width)
  assert_true(clamped.size.width <= max_width)
  assert_true(clamped.size.height == unbounded.size.height)
  assert_true(clamped.baseline == unbounded.baseline)
  inspect(
    clamped.caret_positions.length(),
    content="\{sample.to_array().length() + 1}",
  )
  assert_true(diagnostic_native_carets_are_monotonic(clamped.caret_positions))
  assert_true(
    clamped.caret_positions[clamped.caret_positions.length() - 1] == max_width,
  )
  for caret in clamped.caret_positions {
    assert_true(caret <= max_width)
  }

  let paragraph = system.layout_paragraph(
    @core.TextLayoutInput::new(text=sample, font~, max_width~),
  )
  assert_true(paragraph.metadata.paragraph_layout_available)
  assert_true(paragraph.metadata.line_metrics_available)
  assert_true(paragraph.metadata.selection_rects_available)
  assert_true(paragraph.metadata.hit_test_available)
  if @skia_native.skia_paragraph_available() {
    assert_true(paragraph.metadata.native_paragraph_ready)
  } else {
    assert_false(paragraph.metadata.native_paragraph_ready)
    assert_false(paragraph.metadata.bidi_visual_order_ready)
  }
  assert_true(paragraph.line_count() >= 2)
  assert_true(paragraph.size.height > clamped.size.height)
  inspect(
    paragraph.caret_rects.length(),
    content="\{sample.to_array().length() + 1}",
  )
  for line in paragraph.lines {
    assert_true(line.size.height > 0.0)
    assert_true(line.baseline > line.origin.y)
    assert_true(line.size.width <= max_width + 0.01)
  }
  let selection_rects = paragraph.selection_rects(
    @core.TextRange::new(start=0, end=sample.to_array().length()),
  )
  assert_true(selection_rects.length() >= 2)
  let second_line_y = paragraph.lines[1].origin.y + 1.0
  let hit = paragraph.hit_test(
    @core.Point::new(x=max_width + 100.0, y=second_line_y),
  )
  inspect(hit.line_index, content="1")
  assert_true(hit.offset >= paragraph.lines[1].text_range.start)
  assert_true(hit.offset <= paragraph.lines[1].text_range.end)
  if !@skia_native.skia_paragraph_available() {
    assert_diagnostic_native_skia_maturity_ready(
      "bidi and paragraph line breaking ready",
    )
  }
}

///|
test "diagnostic native skia zwj and color emoji samples keep caret coverage without readiness claim" {
  let system = @skia_renderer.skia_text_system()
  assert_diagnostic_native_text_layout(system, "A👩‍💻B")
  assert_diagnostic_native_cluster_carets(system, "A👩‍💻B", 1, 4)
  assert_diagnostic_native_text_layout(system, "A☕️B")
  assert_diagnostic_native_cluster_carets(system, "A☕️B", 1, 3)
  assert_diagnostic_native_text_layout(system, "A🙂B")
  assert_diagnostic_native_skia_maturity_gap("color emoji")
  assert_diagnostic_native_skia_maturity_ready(
    "Unicode 17 grapheme boundary contract ready",
  )
}

///|
test "diagnostic native skia text system drives runtime text field geometry" {
  let value = @core.State::new("")
  let runtime = @runtime.AppRuntime::new_view(
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
