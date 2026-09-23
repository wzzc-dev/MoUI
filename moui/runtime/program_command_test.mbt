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
        command=@core.ActionCommand::new(intent=Activate, label="Add one"),
        message=model + 1,
      ),
      @core.ProgramCommand::new(
        command=@core.ActionCommand::new(
          intent=Submit,
          label="Add ten",
          context_menu=true,
        ),
        message=10,
      ),
    ]
  })
  let runtime = @runtime.new_program_with_dimensions(
    program~,
    width=100.0,
    height=100.0,
  )
  assert_true(runtime.dispatch_command(Activate))
  assert_true(runtime.dispatch_command(Submit))
  assert_eq(seen, [1, 10])
  assert_eq(runtime.action_commands().length(), 2)
}
