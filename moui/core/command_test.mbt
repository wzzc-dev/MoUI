///|
test "interrupt command intent is labelled, serialisable, and bindable" {
  let command = @core.ActionCommand::new(intent=@core.Interrupt)
  assert_eq(command.display_label(), "Interrupt")
  inspect(@core.Interrupt.to_json() == Json("Interrupt"), content="true")
  let dispatched = Ref(false)
  let commands = @core.ActionCommandMap::new(bindings=[
    @core.CommandBinding::new(command~, handle=() => dispatched.val = true),
  ])
  assert_true(commands.dispatch_intent(@core.Interrupt))
  assert_true(dispatched.val)
}
