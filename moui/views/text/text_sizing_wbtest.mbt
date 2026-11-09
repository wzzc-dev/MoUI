///|
fn text_sizing_layout_context(
  constraints~ : @core.Constraints,
) -> @core.ViewLayoutContext {
  {
    constraints,
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
fn text_sizing_width(label : String) -> Double {
  let view : @core.View[Unit] = text(label)
  view.layout(
    text_sizing_layout_context(
      constraints=@core.Constraints::loose(
        @core.Size::new(width=1000.0, height=200.0),
      ),
    ),
  ).size.width
}

///|
fn text_sizing_width_of(label : String, width~ : Double) -> Double {
  let view : @core.View[Unit] = text(label, width~)
  view.layout(
    text_sizing_layout_context(
      constraints=@core.Constraints::loose(
        @core.Size::new(width=1000.0, height=200.0),
      ),
    ),
  ).size.width
}

///|
test "text sizes to its content by default" {
  // RFC 0007: an unsized label is its measured content, not the old 160x32
  // reserve. Width must track the string rather than sit at a fixed box.
  let short = text_sizing_width("Hi")
  let longer = text_sizing_width("Hello, world")
  assert_true(short > 0.0)
  assert_true(short < 160.0)
  assert_true(longer > short)
}

///|
test "an explicit width remains a minimum box" {
  assert_true(text_sizing_width_of("Hi", width=160.0) == 160.0)
}

///|
test "text grows past its requested width instead of clipping long strings" {
  // Regression: layout used to return the requested box verbatim, so the
  // renderer's clip to the TextRun frame truncated any string wider than the
  // box. Wider system fonts (Linux DejaVu vs Windows Segoe UI / macOS SF Pro)
  // push ordinary labels past a 160px budget, which is why the same view
  // clipped on Linux but looked fine elsewhere.
  let long_label = "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
  assert_true(text_sizing_width(long_label) > 160.0)
  assert_true(text_sizing_width_of(long_label, width=160.0) > 160.0)
}
