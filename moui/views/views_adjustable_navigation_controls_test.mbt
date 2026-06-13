///|
test "resizable split view drag handle emits controlled primary width" {
  let last_width = Ref(0.0)
  let runtime = @core.AppRuntime::new_view(
    root=@views.resizable_split_view(
      primary=@views.text("Primary", width=120.0, height=24.0),
      detail=@views.text("Detail", width=160.0, height=24.0),
      primary_width=180.0,
      detail_width=180.0,
      height=96.0,
      min_primary_width=140.0,
      max_primary_width=220.0,
      on_drag=width => width,
    ),
    size=@core.Size::new(width=420.0, height=140.0),
    on_message=Some(width => last_width.val = width),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Primary"))
  assert_true(has_text(commands, "Detail"))
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=190.0, y=12.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=245.0, y=12.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  inspect(last_width.val, content="220")
}

///|
test "slider drag emits controlled value" {
  let last_value = Ref(0.0)
  let runtime = @core.AppRuntime::new_view(
    root=@views.slider(0.4, width=200.0, on_change=Some(value => value)),
    size=@core.Size::new(width=240.0, height=80.0),
    on_message=Some(value => last_value.val = value),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=80.0, y=14.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=140.0, y=14.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  assert_true(last_value.val >= 0.69)
  assert_true(last_value.val <= 0.71)
}

///|
test "slider drag remains stable across program rebuilds" {
  let seen = Ref(0.4)
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::simple(
      init=0.4,
      update=(_model, message) => {
        seen.val = message
        message
      },
      view=value => {
        @views.slider(value, width=200.0, on_change=Some(next => next))
      },
    ),
    size=@core.Size::new(width=240.0, height=80.0),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=80.0, y=14.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=140.0, y=14.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=180.0, y=14.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  assert_true(seen.val >= 0.89)
  assert_true(seen.val <= 0.91)
}
