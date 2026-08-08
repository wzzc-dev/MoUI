///|
test "command palette filters metadata and shortcuts" {
  let model = CommandPaletteModel::new().update(QueryChanged("edit"))
  let filtered = model.filtered_commands()
  inspect(filtered.length(), content="2")
  assert_true(
    filtered.any(command => command.display_label() == "Copy Selection"),
  )
  assert_true(
    filtered.any(command => command.display_label() == "Paste Selection"),
  )
  let shortcut = CommandPaletteModel::new().update(QueryChanged("Meta+s"))
  inspect(shortcut.filtered_commands().length(), content="1")
  inspect(
    shortcut.filtered_commands()[0].display_label(),
    content="Save Document",
  )
}

///|
test "command palette dispatches enabled and ignores disabled" {
  let saved = CommandPaletteModel::new().update(
    CommandSelected(@core.CommandIntent::Submit),
  )
  inspect(saved.dispatched.length(), content="1")
  inspect(saved.last_result, content="Dispatched: Save Document")
  let disabled = saved.update(CommandSelected(@core.CommandIntent::Cancel))
  inspect(disabled.dispatched.length(), content="1")
  inspect(disabled.last_result, content="Disabled: Archive Document")
}

///|
test "command palette Program declares enabled and disabled shortcuts" {
  let commands = program().runtime_commands(CommandPaletteModel::new())
  inspect(commands.length(), content="5")
  assert_true(
    commands.any(command => {
      command.command().intent == @core.CommandIntent::Submit &&
      command.command().enabled
    }),
  )
  assert_true(
    commands.any(command => {
      command.command().intent == @core.CommandIntent::Cancel &&
      !command.command().enabled
    }),
  )
}

///|
test "command palette runtime exposes command rows" {
  let commands = test_runtime(program(), width=800.0, height=680.0).draw_commands()
  assert_true(has_text(commands, "Command Palette"))
  assert_true(has_text(commands, "Save Document"))
  assert_true(has_text(commands, "Meta+s"))
  assert_true(has_text(commands, "Archive Document"))
  assert_true(has_text(commands, "Native Menu"))
  assert_true(has_text(commands, "Context menu fallback"))
  assert_true(has_text(commands, "Dispatch Log"))
}

///|
test "command palette host menu service dispatches selected command" {
  let saw_menu = Ref(false)
  let services = @backend_common_services.app_services(
    bridge=@host.HostServiceBridge::new(
      capabilities=@host.HostServiceCapabilities::new(menus=true),
      handle=request => {
        match request {
          @host.HostServiceRequest::ShowMenu(commands) => {
            saw_menu.val = true
            @host.HostServiceResponse::MenuCommand(commands[0].intent)
          }
          _ =>
            @host.HostServiceResponse::Unavailable(
              request.unavailable_message(),
            )
        }
      },
    ),
  )
  let (opening, effect) = CommandPaletteModel::new().update_with_services(
    ShowNativeMenu,
    services,
  )
  inspect(opening.last_result, content="Opening native menu")
  let summary = @runtime.effect_plan_summary(effect)
  inspect(summary.descriptors().length(), content="1")
  inspect(summary.descriptors()[0].key(), content="menu:context")
  inspect(summary.descriptors()[0].kind(), content="service")
  inspect(summary.descriptors()[0].label(), content="Show context menu")
  let model = Ref(opening)
  match effect {
    @moui.Effect::Task(_descriptor, start) =>
      ignore(
        start(message => {
          let (next, _effect) = model.val.update_with_services(
            message, services,
          )
          model.val = next
        }),
      )
    _ => fail("expected typed menu service task")
  }
  assert_true(saw_menu.val)
  inspect(model.val.last_result, content="Dispatched: Save Document")
}

///|
test "command palette shortcut dispatch does not regress runtime command map" {
  let runtime = test_runtime(program(), width=800.0, height=680.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="s",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  assert_true(
    runtime
    .action_commands()
    .any(command => command.display_label() == "Save Document"),
  )
}

///|
fn test_runtime(
  program : @moui.Program[CommandPaletteModel, CommandPaletteMsg],
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(program~, width~, height~)
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}
