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
  let clicks = Ref::new(0)
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
