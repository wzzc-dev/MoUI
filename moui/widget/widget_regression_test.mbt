///|
test "widget map maps direct event messages" {
  let view = rect(
    width=10.0,
    height=10.0,
    color=@core.Color::blue(),
    on_tap=Some(1),
  ).map(value => value + 41)
  match view.widget_ops() {
    Some(ops) => {
      let result = ops.event({
        frame: @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        child_frames: [],
        event: @core.AppEvent::Pointer(
          @core.PointerEvent::new(
            position=@core.Point::new(x=5.0, y=5.0),
            phase=@core.PointerPhase::Up,
          ),
        ),
        focused: false,
        state: widget_test_state(),
        text_system: @core.TextSystem::fallback(),
        environment: @core.Environment::default(),
      })
      if result.messages != [42] {
        fail("expected mapped direct message")
      }
    }
    None => fail("expected widget ops")
  }
}

///|
test "widget map maps nested children" {
  let child = rect(
    width=10.0,
    height=10.0,
    color=@core.Color::blue(),
    on_tap=Some(7),
  )
  let view = stack(children=[child]).map(value => "msg-\{value}")
  match view.widget_ops() {
    Some(ops) =>
      match ops.children().get(0) {
        Some(child) =>
          match child.widget_ops() {
            Some(child_ops) => {
              let result = child_ops.event({
                frame: @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
                child_frames: [],
                event: @core.AppEvent::Pointer(
                  @core.PointerEvent::new(
                    position=@core.Point::new(x=5.0, y=5.0),
                    phase=@core.PointerPhase::Up,
                  ),
                ),
                focused: false,
                state: widget_test_state(),
                text_system: @core.TextSystem::fallback(),
                environment: @core.Environment::default(),
              })
              if result.messages != ["msg-7"] {
                fail("expected mapped child message")
              }
            }
            None => fail("expected child widget ops")
          }
        None => fail("expected child")
      }
    None => fail("expected widget ops")
  }
}

///|
fn widget_test_state() -> @core.WidgetStateContext {
  {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
  }
}
