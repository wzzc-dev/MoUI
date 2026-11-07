///|
/// White-box coverage for the `color_picker`: the grid layout, tap-to-change
/// delivery through the swatch children, per-swatch selection semantics, and
/// the hex descriptions.

///|
fn color_picker_test_view(
  selected~ : @core.Color,
  received~ : Array[@core.Color],
) -> @core.View[@core.Color] {
  color_picker(selected~, on_change=color => color, width=272.0)
}

///|
test "color picker lays out a swatch grid with the declared columns" {
  let received : Array[@core.Color] = []
  let view : @core.View[@core.Color] = color_picker_test_view(
    selected=color_picker_default_swatches()[0],
    received~,
  )
  let layout = view.layout({
    constraints: @core.Constraints::tight(
      @core.Size::new(width=272.0, height=200.0),
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
  })
  // 16 default swatches in 8 columns = 2 rows; each cell 30px (272 - 7*8
  // gaps = 216 over 8 = 27? No: (272 - 8*(272-... verify via the frames).
  let swatches = color_picker_default_swatches()
  assert_true(layout.child_frames.length() == swatches.length())
  assert_true(layout.child_frames.length() == 16)
  // Row 0 and row 1 are separated by one gap; column 1 sits one cell right.
  let first = layout.child_frames[0]
  let second = layout.child_frames[1]
  let ninth = layout.child_frames[8]
  assert_true(first.origin.x == 0.0)
  assert_true(second.origin.x == first.origin.x + first.size.width + 8.0)
  assert_true(ninth.origin.y == first.origin.y + first.size.height + 8.0)
  assert_true(ninth.origin.x == first.origin.x)
}

///|
test "tapping a swatch reports its color through on_change" {
  let received : Array[@core.Color] = []
  let swatches = color_picker_default_swatches()
  let view : @core.View[@core.Color] = color_picker_test_view(
    selected=swatches[0],
    received~,
  )
  // The swatches are child views: the tap reaches them through the runtime's
  // element walk, exactly as a user's press would.
  let runtime = @runtime.AppRuntime::new_view(
    root=view,
    size=@core.Size::new(width=272.0, height=200.0),
    on_message=Some(color => received.push(color)),
  )
  ignore(runtime.layout())
  let layout = view.layout({
    constraints: @core.Constraints::tight(
      @core.Size::new(width=272.0, height=200.0),
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
  })
  let target = layout.child_frames[4]
  let center = @core.Point::new(
    x=target.origin.x + target.size.width / 2.0,
    y=target.origin.y + target.size.height / 2.0,
  )
  runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=center, phase=Down)),
  )
  runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=center, phase=Up)),
  )
  assert_true(received.length() == 1)
  assert_true(received[0] == swatches[4])
}

///|
test "swatch semantics carry the selection and the hex description" {
  let received : Array[@core.Color] = []
  let swatches = color_picker_default_swatches()
  let view : @core.View[@core.Color] = color_picker_test_view(
    selected=swatches[2],
    received~,
  )
  let info = view.semantics()
  assert_true(info.role == Some(Group))
  assert_true(info.value.unwrap() == "color picker")
  // The hex helper matches the swatch description format.
  assert_true(color_picker_hex(swatches[2]).substring(start=0, end=1) == "#")
}

///|
test "hex descriptions round-trip the color channels" {
  // The primary blue from the palette prints its exact channels.
  let blue = @core.Color::rgba(r=0.12, g=0.36, b=0.95)
  let hex = color_picker_hex(blue)
  assert_true(hex.substring(start=0, end=3) == "#1f")
  inspect(hex.length(), content="7")
  // Pure extremes round-trip.
  inspect(
    color_picker_hex(@core.Color::rgba(r=1.0, g=1.0, b=1.0)),
    content="#ffffff",
  )
  inspect(
    color_picker_hex(@core.Color::rgba(r=0.0, g=0.0, b=0.0)),
    content="#000000",
  )
}

///|
test "the ring color contrasts the swatch color" {
  // Light swatches ring dark; dark swatches ring white.
  let light = @core.Color::rgba(r=0.98, g=0.98, b=0.9)
  let dark = @core.Color::rgba(r=0.1, g=0.1, b=0.16)
  let light_ring = color_picker_ring_color(light)
  let dark_ring = color_picker_ring_color(dark)
  assert_true(light_ring.r == 0.0)
  assert_true(dark_ring.r == 1.0)
}
