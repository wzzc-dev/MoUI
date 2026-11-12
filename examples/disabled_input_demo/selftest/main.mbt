///|
fn click(runtime : @runtime.AppRuntime, x : Double, y : Double) -> Unit {
  ignore(
    runtime.dispatch_event(
      Pointer(
        @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase=Down),
      ),
    ),
  )
  ignore(
    runtime.dispatch_event(
      Pointer(
        @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase=Up),
      ),
    ),
  )
}

///|
fn messages_after_clicks(enabled : Bool) -> Array[@disabled_demo.Msg] {
  let received : Array[@disabled_demo.Msg] = []
  let model = @disabled_demo.Model::with_enabled(enabled)
  let runtime = @runtime.AppRuntime::new_view(
    root=@disabled_demo.probe_view(model),
    size=@core.Size::new(width=260.0, height=220.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.draw_frame())
  for y in [20.0, 60.0, 100.0, 140.0, 180.0] {
    click(runtime, 20.0, y)
  }
  received
}

///|
fn main {
  let disabled = messages_after_clicks(false)
  let enabled = messages_after_clicks(true)
  println(
    "disabled-input demo self-test: disabled_messages=\{disabled.length()} enabled_messages=\{enabled.length()}",
  )
  if !disabled.is_empty() {
    abort("FAIL: a disabled control dispatched a message")
  }
  if enabled.length() != 5 {
    abort("FAIL: enabled controls should dispatch one message each")
  }
  println("PASS: disabled controls were inert; enabled controls responded")
}
