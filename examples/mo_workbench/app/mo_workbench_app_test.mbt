///|
test "workbench dispatch queues prompt for selected session" {
  let model = WorkbenchModel::new()
    .update(PromptChanged("Inspect the Skia renderer route"))
    .update(DispatchPrompt)
  inspect(model.prompt, content="")
  inspect(model.last_status, content="Queued prompt for Pi JSONL RPC")
  inspect(model.pending_transport_count(), content="1")
  match model.transport.command_queue[0] {
    SendUserInput(session, text) => {
      inspect(session, content="moui-skia")
      inspect(text, content="Inspect the Skia renderer route")
    }
    _ => fail("expected queued user input")
  }
}

///|
test "workbench applies transport events to model timeline" {
  let model = WorkbenchModel::new().update(
    ReceiveTransport(ProcessStarted("4242")),
  )
  inspect(model.transport.status_label(), content="Running")
  inspect(model.transport.last_json_line, content="pid 4242")
  assert_true(
    model.events.any(event => event.title == "Pi RPC process started"),
  )
}

///|
test "workbench command completion updates command table state" {
  let model = WorkbenchModel::new().update(QueueCommand("moon check"))
  let command_id = model.commands.length()
  let completed = model.update(MarkCommandComplete(command_id, 1))
  assert_true(completed.commands.length() == command_id)
  inspect(completed.commands[command_id - 1].status, content="failed")
  match completed.commands[command_id - 1].exit_code {
    Some(code) => inspect(code, content="1")
    None => fail("expected command exit code")
  }
}

///|
test "workbench runtime draws agent desktop shell" {
  let commands = @app.runtime(width=1220.0, height=780.0).draw_commands()
  assert_true(has_text(commands, "Mo Workbench"))
  assert_true(has_text(commands, "A Pi agent desktop"))
  assert_true(has_text(commands, "Project Sessions"))
  assert_true(has_text(commands, "PiTransport"))
  assert_true(has_text(commands, "Pi JSONL RPC"))
  let command_commands = WorkbenchModel::new()
    .update(SelectPanel("commands"))
    .runtime(width=1220.0, height=780.0)
    .draw_commands()
  assert_true(has_text(command_commands, "Queue Tests"))
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is DrawText({ text: value, .. }) && value == text
  })
}
