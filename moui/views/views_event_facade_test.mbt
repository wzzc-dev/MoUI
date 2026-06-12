///|
test "typed button dispatches message" {
  let clicks = Ref(0)
  let runtime = @core.AppRuntime::new_view(
    root=@views.button("Click", on_click=1, width=120.0, height=44.0),
    size=@core.Size::new(width=160.0, height=80.0),
    on_message=Some(message => clicks.val = clicks.val + message),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(clicks.val, content="1")
}

///|
test "view map lifts child message" {
  let seen = Ref("")
  let view = @views.button("Save", on_click="save").map(message => {
    "child:" + message
  })
  let runtime = @core.AppRuntime::new_view(
    root=view,
    size=@core.Size::new(width=160.0, height=80.0),
    on_message=Some(message => seen.val = message),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(seen.val, content="child:save")
}

///|
test "text field submit emits typed message" {
  let submitted = Ref(false)
  let runtime = @core.AppRuntime::new_view(
    root=@views.text_field(
      "hello",
      on_input=_value => false,
      on_submit=Some(true),
    ),
    size=@core.Size::new(width=260.0, height=80.0),
    on_message=Some(message => submitted.val = message),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(submitted.val, content="true")
}
