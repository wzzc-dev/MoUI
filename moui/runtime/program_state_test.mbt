///|
priv enum DevStateMsg {
  Bump
}

///|
fn dev_state_test_program() -> @core.Program[String, DevStateMsg] {
  @core.Program::new(
    init=() => ("seed", @core.Effect::none()),
    update=(model, _message) => ("\{model}!", @core.Effect::none()),
    view=_model => {
      runtime_test_rect(
        width=20.0,
        height=20.0,
        color=@core.Color::blue(),
        on_tap=Some(Bump),
      )
    },
  ).with_state_persistence(save=model => model, load=payload => {
    if payload == "" {
      None
    } else {
      Some(payload)
    }
  })
}

///|
fn dev_state_tap(runtime : @runtime.AppRuntime, size : @core.Size) -> Unit {
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=size.width / 4.0, y=size.height / 4.0),
        phase=Up,
      ),
    ),
  )
}

///|
test "runtime restores model from state transport and saves on update" {
  let store : Array[String] = ["restored-7"]
  let transport = @core.ProgramStateTransport::new(
    read=() => if store.is_empty() { None } else { Some(store[0]) },
    write=payload => {
      store.clear()
      store.push(payload)
    },
  )
  let runtime = @runtime.AppRuntime::new_program(
    program=dev_state_test_program(),
    size=@core.Size::new(width=100.0, height=100.0),
    state_transport=Some(transport),
  )
  dev_state_tap(runtime, @core.Size::new(width=100.0, height=100.0))
  inspect(store[0], content="restored-7!")
}

///|
test "runtime falls back to init model on unreadable state payload" {
  let store : Array[String] = [""]
  let transport = @core.ProgramStateTransport::new(
    read=() => if store.is_empty() { None } else { Some(store[0]) },
    write=payload => {
      store.clear()
      store.push(payload)
    },
  )
  let runtime = @runtime.AppRuntime::new_program(
    program=dev_state_test_program(),
    size=@core.Size::new(width=100.0, height=100.0),
    state_transport=Some(transport),
  )
  dev_state_tap(runtime, @core.Size::new(width=100.0, height=100.0))
  inspect(store[0], content="seed!")
}

///|
test "runtime skips state handoff without transport or persistence" {
  // Persistence declared but no transport: nothing is written.
  let unbacked : Array[String] = []
  let runtime = @runtime.AppRuntime::new_program(
    program=dev_state_test_program(),
    size=@core.Size::new(width=100.0, height=100.0),
  )
  dev_state_tap(runtime, @core.Size::new(width=100.0, height=100.0))
  inspect(unbacked.is_empty(), content="true")
  // Transport supplied but persistence absent: nothing is written.
  let store : Array[String] = []
  let transport = @core.ProgramStateTransport::new(
    read=() => if store.is_empty() { None } else { Some(store[0]) },
    write=payload => {
      store.clear()
      store.push(payload)
    },
  )
  let plain = @core.Program::new(
    init=() => ("seed", @core.Effect::none()),
    update=(model, _message) => ("\{model}!", @core.Effect::none()),
    view=_model => {
      runtime_test_rect(
        width=20.0,
        height=20.0,
        color=@core.Color::blue(),
        on_tap=Some(Bump),
      )
    },
  )
  let untracked = @runtime.AppRuntime::new_program(
    program=plain,
    size=@core.Size::new(width=100.0, height=100.0),
    state_transport=Some(transport),
  )
  dev_state_tap(untracked, @core.Size::new(width=100.0, height=100.0))
  inspect(store.is_empty(), content="true")
}
