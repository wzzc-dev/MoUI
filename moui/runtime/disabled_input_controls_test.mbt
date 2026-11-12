///|
enum DisabledControlMsg {
  DisabledControlActivated
}

///|
test "disabled controls ignore direct pointer activation" {
  let received : Array[DisabledControlMsg] = []
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.column(
      [
        @views.checkbox("Check", checked=false, on_change=_checked => {
          DisabledControlActivated
        })
        .disabled(disabled=true)
        .frame(width=200.0, height=40.0),
        @views.toggle("Toggle", false, on_change=_checked => {
          DisabledControlActivated
        })
        .disabled(disabled=true)
        .frame(width=200.0, height=40.0),
        @views.radio("Radio", false, on_change=_selected => {
          DisabledControlActivated
        })
        .disabled(disabled=true)
        .frame(width=200.0, height=40.0),
        @views.slider(0.5, on_change=Some(_value => DisabledControlActivated))
        .disabled(disabled=true)
        .frame(width=200.0, height=40.0),
      ],
      spacing=0.0,
    ),
    size=@core.Size::new(width=220.0, height=200.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.draw_frame())
  for y in [20.0, 60.0, 100.0, 140.0] {
    runtime.dispatch_event(
      Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=20.0, y~),
          phase=Down,
        ),
      ),
    )
    runtime.dispatch_event(
      Pointer(
        @core.PointerEvent::new(position=@core.Point::new(x=20.0, y~), phase=Up),
      ),
    )
  }
  if !received.is_empty() {
    fail("disabled controls must not dispatch pointer activation")
  }
}
