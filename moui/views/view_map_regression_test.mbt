///|
fn[Msg] view_map_test_rect(
  width~ : Double,
  height~ : Double,
  color~ : @core.Color,
  on_tap? : Msg? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="Rect"),
    revision=() => "view-map-test-rect:\{width}:\{height}",
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
      )
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::FillRect(ctx.frame, color),
      ])
    },
    event=ctx => {
      match (ctx.event, on_tap) {
        (@core.AppEvent::Pointer(event), Some(message)) =>
          if event.phase == @core.PointerPhase::Up &&
            ctx.frame.contains(event.position) {
            @core.ViewEventResult::message(message)
          } else {
            @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
}

///|
fn[Msg] view_map_test_stack(
  children~ : Array[@core.View[Msg]],
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="Stack"),
    revision=() => "view-map-test-stack",
    children=() => children,
    layout=ctx => {
      let mut width = 0.0
      let mut height = 0.0
      let frames : Array[@core.Rect] = []
      for size in ctx.child_sizes {
        if size.width > width {
          width = size.width
        }
        if size.height > height {
          height = size.height
        }
      }
      let size = ctx.constraints.constrain(@core.Size::new(width~, height~))
      for _child in ctx.child_sizes {
        frames.push(
          @core.Rect::new(x=0.0, y=0.0, width=size.width, height=size.height),
        )
      }
      @core.ViewLayoutResult::new(size~, child_frames=frames)
    },
  )
}

///|
test "view map maps direct event messages" {
  let view = view_map_test_rect(
    width=10.0,
    height=10.0,
    color=@core.Color::blue(),
    on_tap=Some(1),
  ).map(value => value + 41)
  let result = view.event({
    frame: @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
    child_frames: [],
    event: @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=5.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
    focused: false,
    state: view_test_state(),
    text_control: view_test_text_control(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
  })
  if result.messages != [42] {
    fail("expected mapped direct message")
  }
}

///|
test "view map maps nested children" {
  let child = view_map_test_rect(
    width=10.0,
    height=10.0,
    color=@core.Color::blue(),
    on_tap=Some(7),
  )
  let view = view_map_test_stack(children=[child]).map(value => "msg-\{value}")
  match view.children().get(0) {
    Some(child) => {
      let result = child.event({
        frame: @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        child_frames: [],
        event: @core.AppEvent::Pointer(
          @core.PointerEvent::new(
            position=@core.Point::new(x=5.0, y=5.0),
            phase=@core.PointerPhase::Up,
          ),
        ),
        focused: false,
        state: view_test_state(),
        text_control: view_test_text_control(),
        text_system: @core.TextSystem::fallback(),
        environment: @core.Environment::neutral(),
      })
      if result.messages != ["msg-7"] {
        fail("expected mapped child message")
      }
    }
    None => fail("expected child")
  }
}

///|
fn view_test_state() -> @core.ViewStateContext {
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
fn view_test_text_control() -> @core.TextControlStateContext {
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
