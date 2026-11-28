///|
fn window_test_interrupt_runtime(
  text : Ref[String],
  interrupts : Ref[Int32],
) -> @apphost.AppRuntime {
  let commands : Array[@core.ProgramCommand[String]] = [
    @core.ProgramCommand::new(
      command=@core.ActionCommand::new(
        intent=@core.Interrupt,
        label="Interrupt",
      ),
      message="interrupt",
    ),
  ]
  @apphost.AppRuntime::new_program(
    program=@core.Program::simple(
      init=(),
      update=(_model, message) => {
        if message == "interrupt" {
          interrupts.val = interrupts.val + 1
        } else {
          text.val = message
        }
      },
      view=_model => {
        @views.column([host_test_text_field(text.val)], spacing=0.0)
      },
    ).with_commands(commands=_model => commands),
    size=@core.Size::new(width=240.0, height=60.0),
  )
}

///|
test "host driver maps plain ctrl+c to interrupt and copy chords to copy" {
  let runtime = window_test_runtime_with_commands(
    root=@views.empty(),
    size=@core.Size::new(width=10.0, height=10.0),
    commands=[],
  )
  let driver = @apphost.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let chord = fn(key : String, modifiers : @core.KeyModifiers) {
    @core.KeyboardEvent::new(
      key~,
      text=None,
      pressed=true,
      repeat=false,
      modifiers~,
    )
  }
  let control = @core.KeyModifiers::new(control=true)
  let shifted_control = @core.KeyModifiers::new(shift=true, control=true)
  let meta = @core.KeyModifiers::new(meta=true)
  assert_eq(
    driver.keyboard_command_intent(chord("c", control)),
    Some(@core.Interrupt),
  )
  assert_eq(driver.keyboard_command_intent(chord("c", meta)), Some(@core.Copy))
  assert_eq(
    driver.keyboard_command_intent(chord("c", shifted_control)),
    Some(@core.Copy),
  )
  assert_eq(
    driver.keyboard_command_intent(chord("Insert", control)),
    Some(@core.Copy),
  )
  assert_eq(
    driver.keyboard_command_intent(
      chord("c", @core.KeyModifiers::new(meta=true, shift=true)),
    ),
    None,
  )
  assert_eq(
    driver.keyboard_command_intent(chord("x", control)),
    Some(@core.Cut),
  )
  assert_eq(
    driver.keyboard_command_intent(chord("v", control)),
    Some(@core.Paste),
  )
}

///|
test "host driver passes interrupt through focused text to app commands" {
  let text = Ref("")
  let interrupts = Ref(0)
  let runtime = window_test_interrupt_runtime(text, interrupts)
  let driver = @apphost.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let clipboard = Ref("unchanged")
  let bridge = @backend_host.HostServiceBridge::new(
    capabilities=@backend_host.HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        Clipboard(WriteText(value)) => {
          clipboard.val = value
          ClipboardWritten
        }
        Clipboard(ReadText) => ClipboardText(clipboard.val)
        _ => Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=Down,
        ),
      ),
    ),
  )
  ignore(driver.dispatch(TextInput(InsertText("hello"))))
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="c",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
      bridge,
    ),
  )
  inspect(interrupts.val, content="1")
  inspect(text.val, content="hello")
  inspect(clipboard.val, content="unchanged")
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
      bridge,
    ),
  )
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="c",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
      bridge,
    ),
  )
  inspect(clipboard.val, content="hello")
  clipboard.val = ""
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="c",
        modifiers=@core.KeyModifiers::new(shift=true, control=true),
      ),
      bridge,
    ),
  )
  inspect(clipboard.val, content="hello")
  inspect(interrupts.val, content="1")
}
