///|
fn window_test_runtime_with_commands(
  root~ : @core.View[Unit],
  size~ : @core.Size,
  commands~ : Array[@core.ActionCommand],
  on_message? : (Int) -> Unit = _ => (),
) -> @runtime.AppRuntime {
  let program_commands : Array[@core.ProgramCommand[Int]] = []
  for index, command in commands {
    program_commands.push(@core.ProgramCommand::new(command~, message=index))
  }
  @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init=(),
      update=(_model, message) => {
        if message >= 0 {
          on_message(message)
        }
        ()
      },
      view=_ => root.map(_ => -1),
    ).with_commands(commands=_ => program_commands),
    size~,
  )
}
