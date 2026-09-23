///|
test "host driver skips context menu without focused text input" {
  let submitted = Ref(0)
  let saw_menu = Ref(false)
  let runtime = host_test_runtime_with_commands(
    root=@views.empty(),
    size=@core.Size::new(width=10.0, height=10.0),
    commands=[@core.ActionCommand::new(intent=Submit, label="Submit")],
    on_message=_ => submitted.val = submitted.val + 1,
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let services = @backend.HostServiceBridge::new(
    capabilities=@backend.HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          saw_menu.val = true
          MenuCommand(commands[0].intent)
        }
        _ => Unavailable("unexpected request")
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
        intent=Activate,
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
        intent=Activate,
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
        intent=Activate,
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
        intent=Activate,
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
  let services = @backend.HostServiceBridge::new(
    capabilities=@backend.HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          for command in commands {
            seen_labels.push(command.label)
          }
          MenuAction(commands[1])
        }
        _ => Unavailable("unexpected request")
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
test "host driver merges the editing group into a focused text context menu" {
  let runtime = host_test_runtime_with_commands(
    root=host_test_text_field("", width=240.0, height=40.0).map(_ => ()),
    size=@core.Size::new(width=240.0, height=60.0),
    commands=[
      @core.ActionCommand::new(
        intent=Activate,
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
        intent=Activate,
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
        intent=Activate,
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
        intent=Activate,
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
  let copy_enabled = Ref(false)
  let cut_enabled = Ref(false)
  let services = @backend.HostServiceBridge::new(
    capabilities=@backend.HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          for command in commands {
            seen_labels.push(command.label)
            if command.label == "Copy" {
              copy_enabled.val = command.enabled
            }
            if command.label == "Cut" {
              cut_enabled.val = command.enabled
            }
          }
          Unavailable("cancelled")
        }
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
  ignore(driver.show_context_menu(services))
  // The editing group leads the menu the way mature editors present it, and
  // the program's own commands follow instead of being replaced by it.
  inspect(
    seen_labels.join(","),
    content="Copy,Cut,Paste,Undo,Redo,Select All,New Document,Open Document",
  )
  // Nothing is selected, so the two commands that need one are disabled.
  assert_false(copy_enabled.val)
  assert_false(cut_enabled.val)
}

///|
test "host driver keeps document actions beside Cut and Copy with a selection" {
  let value = Ref("hello world")
  let runtime = host_test_text_field_runtime(
    value~,
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let seen_labels : Array[String] = []
  let copy_enabled = Ref(false)
  let cut_enabled = Ref(false)
  let services = @backend.HostServiceBridge::new(
    capabilities=@backend.HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          for command in commands {
            seen_labels.push(command.label)
            if command.label == "Copy" {
              copy_enabled.val = command.enabled
            }
            if command.label == "Cut" {
              cut_enabled.val = command.enabled
            }
          }
          Unavailable("cancelled")
        }
        _ => Unavailable("unexpected request")
      }
    },
  )
  // Press, drag across the text, release: the field now has a selection.
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
  ignore(
    driver.dispatch(
      Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=120.0, y=10.0),
          phase=Move,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=120.0, y=10.0),
          phase=Up,
        ),
      ),
    ),
  )
  ignore(driver.show_context_menu(services))
  assert_true(copy_enabled.val)
  assert_true(cut_enabled.val)
}
