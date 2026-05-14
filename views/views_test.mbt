///|
test "views construct layout" {
  let root = @views.padding(
    @views.column([@views.label("A"), @views.button("B")], spacing=8.0),
    4.0,
  )
  let layout = @core.layout_node(
    root,
    @core.Rect::new(x=0.0, y=0.0, width=200.0, height=120.0),
  )
  inspect(layout.children.length(), content="1")
}

///|
test "button pointer states" {
  let node = @views.button("Tap")
  let frame = @core.Rect::new(x=0.0, y=0.0, width=100.0, height=50.0)
  let moved = @views.handle_button_pointer(
    node,
    @core.PointerEvent::new(
      position=@core.Point::new(x=10.0, y=10.0),
      phase=@core.PointerPhase::Move,
    ),
    frame,
  )
  guard moved
    is @core.ViewNode::Button({ state: @core.ButtonState::Hovered, .. }) else {
    fail("expected hovered")
  }
}

///|
test "button on click callback" {
  let clicks = Ref(0)
  let frame = @core.Rect::new(x=0.0, y=0.0, width=100.0, height=50.0)
  let pressed = @views.handle_button_pointer(
    @views.button_on_click("Tap", () => clicks.val = clicks.val + 1),
    @core.PointerEvent::new(
      position=@core.Point::new(x=10.0, y=10.0),
      phase=@core.PointerPhase::Down,
    ),
    frame,
  )
  ignore(
    @views.handle_button_pointer(
      pressed,
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Up,
      ),
      frame,
    ),
  )
  inspect(clicks.val, content="1")
}

///|
test "label paints text" {
  let commands : Array[@core.DrawCommand] = []
  @views.label("Title").paint(
    @core.Rect::new(x=0.0, y=0.0, width=160.0, height=32.0),
    commands,
  )
  guard commands is [@core.DrawCommand::DrawText({ text: "Title", color, .. })] else {
    fail("expected label DrawText")
  }
  assert_true(color == @core.Color::black())
}

///|
test "button paints background and centered text command" {
  let commands : Array[@core.DrawCommand] = []
  @views.button("Tap").paint(
    @core.Rect::new(x=4.0, y=8.0, width=180.0, height=44.0),
    commands,
  )
  guard commands
    is [
      @core.DrawCommand::FillRect(_, _),
      @core.DrawCommand::DrawText({ text: "Tap", frame, .. }),
    ] else {
    fail("expected button rect and DrawText")
  }
  assert_true(frame == @core.Rect::new(x=4.0, y=8.0, width=180.0, height=44.0))
}

///|
test "modifiers build styled view specs" {
  let spec = @views.label("Styled")
    .font(@core.FontSpec::new(size=20.0, weight=700))
    .foreground(@core.Color::blue())
    .key("title")
    .to_spec()
  guard spec
    is @core.ViewSpec::TextSpec(
      {
        key: Some({ value: "title" }),
        font: { size: 20.0, weight: 700, .. },
        color,
        ..,
      }
    ) else {
    fail("expected styled text spec")
  }
  assert_true(color == @core.Color::blue())
}

///|
test "flex alignment modifiers build view specs" {
  let spec = @views.row([@views.label("A")])
    .main_axis_alignment(@core.MainAxisAlignment::MainCenter)
    .cross_axis_alignment(@core.CrossAxisAlignment::CrossEnd)
    .to_spec()
  guard spec
    is @core.ViewSpec::FlexSpec(
      {
        main_axis_alignment: @core.MainAxisAlignment::MainCenter,
        cross_axis_alignment: @core.CrossAxisAlignment::CrossEnd,
        ..,
      }
    ) else {
    fail("expected flex alignment")
  }
}

///|
test "theme modifier feeds environment style into view spec" {
  let theme = @views.theme(
    foreground=@core.Color::blue(),
    background=@core.Color::gray(),
    corner_radius=10.0,
  )
  let spec = @views.button("Themed").theme(theme).to_spec()
  guard spec
    is @core.ViewSpec::ButtonSpec(
      { foreground, background, corner_radius: 10.0, .. }
    ) else {
    fail("expected themed button spec")
  }
  assert_true(foreground == @core.Color::blue())
  assert_true(background == @core.Color::gray())
}

///|
test "container and spacer participate in layout" {
  let root = @views.column([
    @views.container(
      @views.label("A"),
      width=120.0,
      height=40.0,
      background=@core.Color::gray(),
      corner_radius=8.0,
    ),
    @views.spacer(min_length=12.0),
  ]).spacing(6.0)
  let layout = @core.layout_node(
    root,
    @core.Rect::new(x=0.0, y=0.0, width=200.0, height=100.0),
  )
  inspect(layout.children.length(), content="2")
  inspect(layout.children[0].frame.size.width, content="120")
}

///|
test "text field constructs binding backed spec" {
  let state = @core.State::new("Draft")
  let submitted = Ref(false)
  let spec = @views.text_field_on_submit(
    state.binding(),
    () => submitted.val = true,
    placeholder="New todo",
    width=220.0,
    height=40.0,
  ).to_spec()
  guard spec
    is @core.ViewSpec::TextFieldSpec(
      { placeholder: "New todo", size: { width: 220.0, height: 40.0 }, value, .. }
    ) else {
    fail("expected text field spec")
  }
  value.set("Changed")
  inspect(state.get(), content="Changed")
  ignore(submitted)
}
