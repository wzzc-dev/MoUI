///|
test "Program commands stay typed and can be mapped" {
  let command = @core.ProgramCommand::new(
    command=@core.ActionCommand::new(
      intent=@core.CommandIntent::Submit,
      label="Save",
    ),
    message="save",
  )
  assert_eq(command.command().display_label(), "Save")
  assert_eq(command.message(), "save")
  assert_eq(command.map(message => message.length()).message(), 4)
}

///|
test "Program with_commands derives declarations from the model" {
  let program = @core.Program::simple(
    init=1,
    update=(model, delta) => model + delta,
    view=_model => abort("view is not evaluated by this test"),
  ).with_commands(commands=model => {
    [
      @core.ProgramCommand::new(
        command=@core.ActionCommand::new(intent=@core.CommandIntent::Activate),
        message=model,
      ),
    ]
  })
  let commands = program.runtime_commands(7)
  assert_eq(commands.length(), 1)
  assert_eq(commands[0].message(), 7)
}
