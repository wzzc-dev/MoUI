///|
test "program commands dispatch through the FIFO typed update queue" {
  let seen : Array[Int] = []
  let program = @core.Program::simple(
    init=0,
    update=(model, message) => {
      seen.push(message)
      model + message
    },
    view=_model => @views.empty(),
  ).with_commands(commands=model => {
    [
      @core.ProgramCommand::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Activate,
          label="Add one",
        ),
        message=model + 1,
      ),
      @core.ProgramCommand::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Submit,
          label="Add ten",
          context_menu=true,
        ),
        message=10,
      ),
    ]
  })
  let runtime = new_program_with_dimensions(program~, width=100.0, height=100.0)
  assert_true(runtime.dispatch_command(@core.CommandIntent::Activate))
  assert_true(runtime.dispatch_command(@core.CommandIntent::Submit))
  assert_eq(seen, [1, 10])
  assert_eq(runtime.action_commands().length(), 2)
}
