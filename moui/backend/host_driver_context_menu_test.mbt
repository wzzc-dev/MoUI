///|
test "host driver skips context menu without focused text input" {
  let submitted = Ref(0)
  let saw_menu = Ref(false)
  let runtime = host_test_runtime_with_commands(
    root=@views.empty(),
    size=@core.Size::new(width=10.0, height=10.0),
    commands=[
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Submit,
        label="Submit",
      ),
    ],
    on_message=_ => submitted.val = submitted.val + 1,
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let services = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          saw_menu.val = true
          HostServiceResponse::MenuCommand(commands[0].intent)
        }
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(driver.show_context_menu(services))
  inspect(saw_menu.val, content="false")
  inspect(submitted.val, content="0")
}

///|
test "host driver shows marked document context menu commands without text focus" {
  let new_document = Ref(0)
  let open_document = Ref(0)
  let runtime = host_test_runtime_with_commands(
    root=@views.empty(),
    size=@core.Size::new(width=10.0, height=10.0),
    commands=[
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Activate,
        label="New Document",
        context_menu=true,
        shortcut=Some(
          @core.KeyboardShortcut::new(
            key="n",
            modifiers=@core.KeyModifiers::new(meta=true),
          ),
        ),
      ),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Activate,
        label="New Document",
        context_menu=true,
        shortcut=Some(
          @core.KeyboardShortcut::new(
            key="n",
            modifiers=@core.KeyModifiers::new(control=true),
          ),
        ),
      ),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Activate,
        label="Open Document",
        context_menu=true,
        shortcut=Some(
          @core.KeyboardShortcut::new(
            key="o",
            modifiers=@core.KeyModifiers::new(meta=true),
          ),
        ),
      ),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Activate,
        label="Open Document",
        context_menu=true,
        shortcut=Some(
          @core.KeyboardShortcut::new(
            key="o",
            modifiers=@core.KeyModifiers::new(control=true),
          ),
        ),
      ),
    ],
    on_message=index => {
      if index < 2 {
        new_document.val = new_document.val + 1
      } else {
        open_document.val = open_document.val + 1
      }
    },
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let seen_labels : Array[String] = []
  let services = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          for command in commands {
            seen_labels.push(command.label)
          }
          HostServiceResponse::MenuAction(commands[1])
        }
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(driver.show_context_menu(services))
  inspect(seen_labels.length(), content="2")
  inspect(seen_labels[0], content="New Document")
  inspect(seen_labels[1], content="Open Document")
  inspect(new_document.val, content="0")
  inspect(open_document.val, content="1")
}

///|
test "host driver shows document actions in focused text context menu without selection" {
  let runtime = host_test_runtime_with_commands(
    root=host_test_text_field("", width=240.0, height=40.0).map(_ => ()),
    size=@core.Size::new(width=240.0, height=60.0),
    commands=[
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Activate,
        label="New Document",
        context_menu=true,
        shortcut=Some(
          @core.KeyboardShortcut::new(
            key="n",
            modifiers=@core.KeyModifiers::new(meta=true),
          ),
        ),
      ),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Activate,
        label="New Document",
        context_menu=true,
        shortcut=Some(
          @core.KeyboardShortcut::new(
            key="n",
            modifiers=@core.KeyModifiers::new(control=true),
          ),
        ),
      ),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Activate,
        label="Open Document",
        context_menu=true,
        shortcut=Some(
          @core.KeyboardShortcut::new(
            key="o",
            modifiers=@core.KeyModifiers::new(meta=true),
          ),
        ),
      ),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Activate,
        label="Open Document",
        context_menu=true,
        shortcut=Some(
          @core.KeyboardShortcut::new(
            key="o",
            modifiers=@core.KeyModifiers::new(control=true),
          ),
        ),
      ),
    ],
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let seen_labels : Array[String] = []
  let services = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          for command in commands {
            seen_labels.push(command.label)
          }
          HostServiceResponse::Unavailable("cancelled")
        }
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      Event::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(driver.show_context_menu(services))
  inspect(seen_labels.length(), content="2")
  assert_true(seen_labels.any(label => label == "New Document"))
  assert_true(seen_labels.any(label => label == "Open Document"))
  assert_false(seen_labels.any(label => label == "Copy"))
  assert_false(seen_labels.any(label => label == "Paste"))
}
