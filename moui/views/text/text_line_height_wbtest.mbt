///|
fn text_line_height_layout_context() -> @core.ViewLayoutContext {
  {
    constraints: @core.Constraints::loose(
      @core.Size::new(width=200.0, height=500.0),
    ),
    child_sizes: [],
    child_flex_weights: [],
    state: {
      focused: false,
      hovered: false,
      pressed: false,
      selected: false,
      checked: false,
      expanded: false,
      disabled: false,
      slots: @core.ViewStateSlots::empty(),
    },
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
  }
}

///|
fn text_line_height_theme(line_height : Double?) -> @core.Theme {
  let theme = @core.Theme::neutral()
  let font = @core.FontSpec::new(size=10.0, line_height?)
  theme.with_typography({ ..theme.typography, body: font, })
}

///|
test "text applies an explicit line height to wrapped lines" {
  let view : @core.View[Unit] = text(
    "a\nb\nc",
    role=Body,
    theme=text_line_height_theme(Some(30.0)),
    wrap=true,
  )
  let result = view.layout(text_line_height_layout_context())
  assert_eq(result.size.height, 90.0)
}

///|
test "text without a line height keeps provider leading" {
  let view : @core.View[Unit] = text(
    "a\nb\nc",
    role=Body,
    theme=text_line_height_theme(None),
    wrap=true,
  )
  let result = view.layout(text_line_height_layout_context())
  // The fallback provider's natural leading is `max(measured, size × 1.25)`,
  // strictly below the 30 DIP override used above.
  assert_true(result.size.height < 90.0)
  assert_true(result.size.height > 0.0)
}
