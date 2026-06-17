///|
test "virtual node map maps direct event messages" {
  let view = raw_rect(
    width=10.0,
    height=10.0,
    color=@core.Color::blue(),
    on_tap=Some(1),
  ).map(value => value + 41)
  match view.virtual_node_ops() {
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
        state: virtual_node_test_state(),
        text_control: virtual_node_test_text_control(),
        text_system: @core.TextSystem::fallback(),
        environment: @core.Environment::neutral(),
      })
      if result.messages != [42] {
        fail("expected mapped direct message")
      }
    }
    None => fail("expected virtual node")
  }
}

///|
test "virtual node map maps nested children" {
  let child = raw_rect(
    width=10.0,
    height=10.0,
    color=@core.Color::blue(),
    on_tap=Some(7),
  )
  let view = raw_stack(children=[child]).map(value => "msg-\{value}")
  match view.virtual_node_ops() {
    Some(ops) =>
      match ops.children().get(0) {
        Some(child) =>
          match child.virtual_node_ops() {
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
                state: virtual_node_test_state(),
                text_control: virtual_node_test_text_control(),
                text_system: @core.TextSystem::fallback(),
                environment: @core.Environment::neutral(),
              })
              if result.messages != ["msg-7"] {
                fail("expected mapped child message")
              }
            }
            None => fail("expected child virtual node")
          }
        None => fail("expected child")
      }
    None => fail("expected virtual node")
  }
}

///|
fn virtual_node_test_state() -> @core.VirtualNodeStateContext {
  {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    scratch: "",
  }
}

///|
fn virtual_node_test_text_control() -> @core.TextControlStateContext {
  {
    caret: 0,
    selection: None,
    text_selection_anchor: None,
    composition: None,
    composition_cursor: None,
    undo_stack: [],
    redo_stack: [],
  }
}
