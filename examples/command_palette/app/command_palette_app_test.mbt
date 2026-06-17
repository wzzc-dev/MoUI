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
test "command palette command map dispatches shortcut but not disabled" {
  let map = action_command_map()
  let save_event = @core.KeyboardEvent::new(
    key="s",
    modifiers=@core.KeyModifiers::new(meta=true),
  )
  match map.dispatch_shortcut(save_event) {
    Some(@core.CommandIntent::Submit) => ()
    _ => fail("expected submit shortcut")
  }
  let archive_event = @core.KeyboardEvent::new(
    key="Backspace",
    modifiers=@core.KeyModifiers::new(meta=true),
  )
  match map.dispatch_shortcut(archive_event) {
    None => ()
    Some(_) => fail("disabled command should not dispatch")
  }
  assert_false(map.dispatch_intent(@core.CommandIntent::Cancel))
}

///|
test "command palette runtime exposes command rows" {
  let commands = test_runtime(@app.program(), width=800.0, height=680.0).draw_commands()
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
  let services = @host.HostAppServices::new(
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
  inspect(summary.descriptors.length(), content="1")
  inspect(summary.descriptors[0].key(), content="host:command-menu")
  inspect(summary.descriptors[0].kind(), content="host-service")
  inspect(summary.descriptors[0].label(), content="Show command menu")
  let model = @core.State::new(opening)
  match effect {
    @core.Effect::Run(_descriptor, run) =>
      run(message => {
        let (next, _effect) = model
          .get()
          .update_with_services(message, services)
        model.set(next)
      })
    _ => fail("expected native menu effect")
  }
  assert_true(saw_menu.val)
  inspect(model.get().last_result, content="Dispatched: Save Document")
}

///|
test "command palette shortcut dispatch does not regress runtime command map" {
  let runtime = test_runtime(@app.program(), width=800.0, height=680.0)
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
  program : @core.Program[CommandPaletteModel, CommandPaletteMsg],
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  let runtime = @runtime.new_program_with_dimensions(program~, width~, height~)
  runtime.set_action_commands(action_command_map())
  runtime
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}
