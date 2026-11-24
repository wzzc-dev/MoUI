///|
/// A program whose command table is what the host would hand to `ShowMenu`,
/// plus the log its commands' messages land in. Right-click commands need a
/// program: a plain `new_view` runtime has no action-command table at all.
fn context_menu_test_runtime(
  log : Ref[Array[String]],
  commands : Array[@core.ProgramCommand[String]],
) -> @runtime.AppRuntime {
  let root : @core.View[String] = @views.text(
    "surface",
    width=240.0,
    height=120.0,
  )
  let program = @core.Program::simple(
    init=0,
    update=(model, message) => {
      log.val.push(message)
      model + 1
    },
    view=_model => root,
  ).with_commands(commands=_model => commands)
  @runtime.AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=240.0, height=120.0),
  )
}

///|
/// Two rows share `Activate` on purpose: the fallback must dispatch the exact
/// command the user picked, not the first row carrying that intent.
fn context_menu_test_commands() -> Array[@core.ProgramCommand[String]] {
  [
    @core.ProgramCommand::new(
      command=@core.ActionCommand::new(
        intent=@core.Activate,
        label="New Document",
        context_menu=true,
      ),
      message="new",
    ),
    @core.ProgramCommand::new(
      command=@core.ActionCommand::new(
        intent=@core.Activate,
        label="Open Document",
        context_menu=true,
      ),
      message="open",
    ),
    @core.ProgramCommand::new(
      command=@core.ActionCommand::new(
        intent=@core.Submit,
        label="Run",
        context_menu=true,
      ),
      message="run",
    ),
  ]
}

///|
fn context_menu_test_driver(
  log : Ref[Array[String]],
  commands : Array[@core.ProgramCommand[String]],
) -> HostRuntimeDriver {
  let runtime = context_menu_test_runtime(log, commands)
  HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
}

///|
fn context_menu_test_key(key : String) -> @core.KeyboardEvent {
  @core.KeyboardEvent::new(key~)
}

///|
test "an unavailable menu service opens the view-level menu" {
  let log : Ref[Array[String]] = Ref([])
  let driver = context_menu_test_driver(log, context_menu_test_commands())
  let result = driver.show_context_menu(
    @backend_host.HostServiceBridge::unavailable(),
  )
  assert_true(driver.context_menu_is_open())
  // Mounting the layer requests a root rebuild, so the host repaints the same
  // frame the click arrived in.
  assert_true(result.needs_rebuild)
  match driver.context_menu {
    Some(menu) => {
      assert_eq(menu.commands.length(), 3)
      assert_eq(menu.commands[0].display_label(), "New Document")
      // Native context menus open with no row highlighted; Enter stays inert
      // until the keyboard walk visits a row.
      assert_eq(menu.active, -1)
      assert_true(menu.active_command() is None)
    }
    None => fail("expected the view-level menu to be open")
  }
}

///|
test "only the canonical unavailable answer opens the fallback" {
  let log : Ref[Array[String]] = Ref([])
  let driver = context_menu_test_driver(log, context_menu_test_commands())
  // A platform that answered with a real menu (even a dismissal) must not get
  // a second, view-level menu on top of it.
  let services = @backend_host.HostServiceBridge::new(
    capabilities=@backend_host.HostServiceCapabilities::new(menus=true),
    handle=_request => {
      @backend_host.HostServiceResponse::Unavailable("menu cancelled")
    },
  )
  ignore(driver.show_context_menu(services))
  assert_true(!driver.context_menu_is_open())
}

///|
test "the keyboard walk skips disabled rows and does not wrap" {
  let log : Ref[Array[String]] = Ref([])
  let commands = [
    @core.ProgramCommand::new(
      command=@core.ActionCommand::new(
        intent=@core.Activate,
        label="Enabled",
        context_menu=true,
      ),
      message="enabled",
    ),
    @core.ProgramCommand::new(
      command=@core.ActionCommand::new(
        intent=@core.Activate,
        label="Disabled",
        enabled=false,
        context_menu=true,
      ),
      message="disabled",
    ),
    @core.ProgramCommand::new(
      command=@core.ActionCommand::new(
        intent=@core.Submit,
        label="Run",
        context_menu=true,
      ),
      message="run",
    ),
  ]
  let driver = context_menu_test_driver(log, commands)
  let services = @backend_host.HostServiceBridge::unavailable()
  ignore(driver.show_context_menu(services))
  let active = () => {
    let menu = driver.context_menu
    match menu {
      Some(menu) => menu.active
      None => -99
    }
  }
  ignore(
    driver.dispatch_keyboard_with_services(
      context_menu_test_key("ArrowDown"),
      services,
    ),
  )
  assert_eq(active(), 0)
  // The disabled row is jumped over, not highlighted.
  ignore(
    driver.dispatch_keyboard_with_services(
      context_menu_test_key("ArrowDown"),
      services,
    ),
  )
  assert_eq(active(), 2)
  // At the bottom the highlight stays put: a context menu does not wrap.
  ignore(
    driver.dispatch_keyboard_with_services(
      context_menu_test_key("ArrowDown"),
      services,
    ),
  )
  assert_eq(active(), 2)
  ignore(
    driver.dispatch_keyboard_with_services(
      context_menu_test_key("ArrowUp"),
      services,
    ),
  )
  assert_eq(active(), 0)
  // Up from the first row jumps the disabled row as well, then stays.
  ignore(
    driver.dispatch_keyboard_with_services(
      context_menu_test_key("ArrowUp"),
      services,
    ),
  )
  assert_eq(active(), 0)
  ignore(
    driver.dispatch_keyboard_with_services(
      context_menu_test_key("End"),
      services,
    ),
  )
  assert_eq(active(), 2)
  ignore(
    driver.dispatch_keyboard_with_services(
      context_menu_test_key("Home"),
      services,
    ),
  )
  assert_eq(active(), 0)
}

///|
test "Enter runs the highlighted row and closes the menu" {
  let log : Ref[Array[String]] = Ref([])
  let driver = context_menu_test_driver(log, context_menu_test_commands())
  let services = @backend_host.HostServiceBridge::unavailable()
  ignore(driver.show_context_menu(services))
  // Walk to the second row: both rows carry `Activate`, so this is only right
  // if the whole command is dispatched.
  ignore(
    driver.dispatch_keyboard_with_services(
      context_menu_test_key("ArrowDown"),
      services,
    ),
  )
  ignore(
    driver.dispatch_keyboard_with_services(
      context_menu_test_key("ArrowDown"),
      services,
    ),
  )
  ignore(
    driver.dispatch_keyboard_with_services(
      context_menu_test_key("Enter"),
      services,
    ),
  )
  assert_true(!driver.context_menu_is_open())
  if log.val != ["open"] {
    fail("expected the highlighted row's own message")
  }
}

///|
test "clicking a row dispatches the whole command, not just its intent" {
  let log : Ref[Array[String]] = Ref([])
  let driver = context_menu_test_driver(log, context_menu_test_commands())
  let services = @backend_host.HostServiceBridge::unavailable()
  ignore(driver.show_context_menu(services))
  // The row button reports the full command through the layer's mailbox; this
  // is the message the click path produces.
  match driver.context_menu {
    Some(menu) =>
      menu.messages.push(HostContextMenuMessage::Select(menu.commands[1]))
    None => fail("expected the view-level menu to be open")
  }
  driver.settle_context_menu()
  assert_true(!driver.context_menu_is_open())
  if log.val != ["open"] {
    fail("expected the clicked row's own message")
  }
}

///|
test "Escape, a dismiss, and any other key all close the menu" {
  let log : Ref[Array[String]] = Ref([])
  let driver = context_menu_test_driver(log, context_menu_test_commands())
  let services = @backend_host.HostServiceBridge::unavailable()
  // Escape is the top-most dismissal while the layer is up.
  ignore(driver.show_context_menu(services))
  ignore(driver.dispatch_escape())
  assert_true(!driver.context_menu_is_open())
  // A click on the barrier reports the dismiss message.
  ignore(driver.show_context_menu(services))
  match driver.context_menu {
    Some(menu) => menu.messages.push(HostContextMenuMessage::Dismiss)
    None => fail("expected the view-level menu to be open")
  }
  driver.settle_context_menu()
  assert_true(!driver.context_menu_is_open())
  // Any other key closes the menu and is handed back to the app instead of
  // being swallowed by a layer the user is done with.
  ignore(driver.show_context_menu(services))
  ignore(
    driver.dispatch_keyboard_with_services(context_menu_test_key("k"), services),
  )
  assert_true(!driver.context_menu_is_open())
  if log.val.length() != 0 {
    fail("no row ran, so the program must not have seen a command")
  }
}

///|
test "the menu reopens after a root rebuild" {
  let log : Ref[Array[String]] = Ref([])
  let driver = context_menu_test_driver(log, context_menu_test_commands())
  let services = @backend_host.HostServiceBridge::unavailable()
  ignore(driver.show_context_menu(services))
  ignore(driver.dispatch_escape())
  // A theme change rebuilds the root (and with it every declaration); the
  // host layer must still be installable afterwards.
  driver.runtime.set_environment(@core.Environment::neutral())
  ignore(driver.runtime.draw_frame())
  ignore(driver.show_context_menu(services))
  assert_true(driver.context_menu_is_open())
  ignore(
    driver.dispatch_keyboard_with_services(
      context_menu_test_key("ArrowDown"),
      services,
    ),
  )
  ignore(
    driver.dispatch_keyboard_with_services(
      context_menu_test_key("Enter"),
      services,
    ),
  )
  if log.val != ["new"] {
    fail("expected the reopened menu to dispatch")
  }
}

///|
test "a focused text field prepends the editing group with Cut/Copy disabled" {
  let log : Ref[Array[String]] = Ref([])
  let received : Ref[Array[String]] = Ref([])
  let field : @core.View[String] = @views.text_field(
    "untitled.md",
    on_input=value => {
      received.val.push(value)
      "typed"
    },
    width=200.0,
    height=40.0,
  )
  let root : @core.View[String] = @views.column(
    [field, @views.spacer(min_length=80.0)],
    spacing=0.0,
  )
  let program = @core.Program::simple(
    init=0,
    update=(model, message) => {
      log.val.push(message)
      model + 1
    },
    view=_model => root,
  ).with_commands(commands=_model => context_menu_test_commands())
  let runtime = @runtime.AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=240.0, height=120.0),
  )
  ignore(runtime.draw_frame())
  // Focus the field: without focus there is no text target, so the editing
  // group would not appear at all.
  ignore(
    runtime.dispatch_event(
      @core.Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=12.0, y=20.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    runtime.dispatch_event(
      @core.Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=12.0, y=20.0),
          phase=@core.PointerPhase::Up,
        ),
      ),
    ),
  )
  if !runtime.focused_text_input().focused {
    fail("expected the field to take the click")
  }
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(
    driver.show_context_menu(@backend_host.HostServiceBridge::unavailable()),
  )
  match driver.context_menu {
    Some(menu) => {
      let labels = menu.commands.map(command => command.display_label())
      // Editing group first, then the program's own actions: the same order
      // the native path hands to `ShowMenu`.
      assert_eq(labels[0], "Copy")
      assert_eq(labels[1], "Cut")
      assert_eq(labels[2], "Paste")
      assert_true(labels.any(label => label == "Select All"))
      assert_true(labels.any(label => label == "New Document"))
      // Nothing is selected yet, so clipboard-writing rows stay disabled.
      assert_true(!menu.commands[0].enabled)
      assert_true(!menu.commands[1].enabled)
      assert_true(menu.is_enabled(menu.first_enabled()))
    }
    None => fail("expected the view-level menu to be open")
  }
}

///|
/// Center of the semantics node labelled `label` in the fallback menu: where a
/// pointer press has to land to hit that row.
fn context_menu_row_center(
  runtime : @runtime.AppRuntime,
  label : String,
) -> @core.Point? {
  match runtime.read_semantics() {
    Ok(@runtime.SemanticsRead::Full(snapshot)) => {
      for node in snapshot.nodes() {
        if node.label == label {
          return Some(
            @core.Point::new(
              x=node.frame.origin.x + node.frame.size.width / 2.0,
              y=node.frame.origin.y + node.frame.size.height / 2.0,
            ),
          )
        }
      }
      None
    }
    _ => None
  }
}

///|
/// The defect this locks down: a mouse press on a menu row used to run the
/// focus commit first, which cleared the covered text field's focus — so the
/// row's `Cut` reached `dispatch_focused_text_command` with no target and the
/// menu closed without editing anything. The keyboard path never pressed, so
/// Enter worked while clicking did not.
test "a mouse press on a row cuts the focused text and keeps its focus" {
  let log : Ref[Array[String]] = Ref([])
  let value : Ref[String] = Ref("hello world")
  let field : @core.View[String] = @views.text_field(
    value.val,
    on_input=input => {
      value.val = input
      "input"
    },
    width=200.0,
    height=36.0,
  )
  let root : @core.View[String] = @views.column(
    [field, @views.spacer(min_length=80.0)],
    spacing=0.0,
  )
  let program = @core.Program::simple(
    init=0,
    update=(model, message) => {
      log.val.push(message)
      model + 1
    },
    view=_model => root,
  ).with_commands(commands=_model => context_menu_test_commands())
  let runtime = @runtime.AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=420.0, height=320.0),
  )
  ignore(runtime.draw_frame())
  for phase in [@core.PointerPhase::Down, @core.PointerPhase::Up] {
    ignore(
      runtime.dispatch_event(
        @core.Pointer(
          @core.PointerEvent::new(
            position=@core.Point::new(x=12.0, y=18.0),
            phase~,
          ),
        ),
      ),
    )
  }
  if !runtime.focused_text_input().focused {
    fail("expected the field to take the click")
  }
  if !runtime.select_focused_text_all() {
    fail("expected select all to be handled")
  }
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let services = @backend_host.HostServiceBridge::unavailable()
  ignore(driver.show_context_menu(services))
  ignore(runtime.layout())
  let center = match context_menu_row_center(runtime, "Cut") {
    Some(point) => point
    None => fail("expected the Cut row to be laid out")
  }
  for phase in [@core.PointerPhase::Down, @core.PointerPhase::Up] {
    ignore(
      driver.dispatch(
        @backend_host.Event::Pointer(
          @core.PointerEvent::new(position=center, phase~),
        ),
      ),
    )
  }
  assert_true(!driver.context_menu_is_open())
  // The press must not have taken focus: it is what the cut needs to land.
  assert_true(runtime.focused_text_input().focused)
  // `on_input` is the app-visible result of the edit; the field reports the
  // cut text to the program, which is what "the row ran" means here.
  if value.val != "" {
    fail("expected the clicked row to cut the selected text")
  }
}
