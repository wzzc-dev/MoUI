///|
async test "native transport default command targets pi rpc" {
  let config = PiNativeTransportConfig::pi(cwd="/tmp/demo")
  inspect(config.command, content="pi")
  inspect(config.args.length(), content="2")
  inspect(config.args[0], content="--mode")
  inspect(config.args[1], content="rpc")
  inspect(config.cwd, content="/tmp/demo")
  inspect(config.command_label(), content="pi --mode rpc")
}

///|
async test "native transport builds structured jsonl request lines" {
  let start = pi_rpc_start_line(session_id="session-1", cwd="/repo")
  let input = pi_rpc_user_input_line(
    session_id="session-1",
    text="Inspect renderer capability tests",
  )
  json_inspect(@json.parse(start), content={
    "type": "start_session",
    "session_id": "session-1",
    "cwd": "/repo",
  })
  json_inspect(@json.parse(input), content={
    "type": "user_input",
    "session_id": "session-1",
    "text": "Inspect renderer capability tests",
  })
  json_inspect(@json.parse(pi_rpc_cancel_line(session_id="session-1")), content={
    "type": "cancel_run",
    "session_id": "session-1",
  })
  json_inspect(@json.parse(pi_rpc_shutdown_line()), content={
    "type": "shutdown",
  })
}

///|
async test "native transport maps command batches to jsonl requests" {
  let request = PiNativeTransportRequest::from_commands([
    StartRpc("session-1", "/repo"),
    SendUserInput("session-1", "hello"),
    CancelRpcRun("session-1"),
    Shutdown,
  ])
  inspect(request.session_id, content="session-1")
  inspect(request.lines.length(), content="4")
  json_inspect(@json.parse(request.lines[0]), content={
    "type": "start_session",
    "session_id": "session-1",
    "cwd": "/repo",
  })
  json_inspect(@json.parse(request.lines[1]), content={
    "type": "user_input",
    "session_id": "session-1",
    "text": "hello",
  })
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "native transport drives jsonl command batch through stdin stdout process" {
  let config = PiNativeTransportConfig::shell(
    script=(
      #|while IFS= read -r line; do
      #|  printf '{"echo":%s}\n' "$line"
      #|done
    ),
  )
  let run = run_jsonl_commands(config, [
    StartRpc("fixture", "/repo"),
    SendUserInput("fixture", "hello pi"),
  ])
  inspect(run.exit_code, content="0")
  inspect(run.sent_lines().length(), content="2")
  inspect(run.received_lines().length(), content="2")
  json_inspect(@json.parse(run.received_lines()[0]), content={
    "echo": { "type": "start_session", "session_id": "fixture", "cwd": "/repo" },
  })
  json_inspect(@json.parse(run.received_lines()[1]), content={
    "echo": {
      "type": "user_input",
      "session_id": "fixture",
      "text": "hello pi",
    },
  })
  assert_true(run.events.any(event => event is ProcessStarted(_)))
  assert_true(run.events.any(event => event is ProcessExited(0)))
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "native transport keeps one jsonl process across command batches" {
  let config = PiNativeTransportConfig::shell(
    script=(
      #|count=0
      #|while IFS= read -r line; do
      #|  count=$((count + 1))
      #|  printf '{"count":%s,"echo":%s}\n' "$count" "$line"
      #|done
    ),
  )
  let run = run_interactive_jsonl_session(config, session_id="fixture", session => {
    session.send_commands([StartRpc(session.session_id(), "/repo")])
    @async.sleep(1)
    session.send_commands([SendUserInput(session.session_id(), "first prompt")])
    @async.sleep(1)
    session.send_commands([SendUserInput(session.session_id(), "second prompt")])
  })
  inspect(run.exit_code, content="0")
  inspect(run.sent_lines().length(), content="3")
  inspect(run.received_lines().length(), content="3")
  json_inspect(@json.parse(run.received_lines()[0]), content={
    "count": 1,
    "echo": { "type": "start_session", "session_id": "fixture", "cwd": "/repo" },
  })
  json_inspect(@json.parse(run.received_lines()[1]), content={
    "count": 2,
    "echo": {
      "type": "user_input",
      "session_id": "fixture",
      "text": "first prompt",
    },
  })
  json_inspect(@json.parse(run.received_lines()[2]), content={
    "count": 3,
    "echo": {
      "type": "user_input",
      "session_id": "fixture",
      "text": "second prompt",
    },
  })
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "native transport command batch runner reuses one jsonl process" {
  let config = PiNativeTransportConfig::shell(
    script=(
      #|count=0
      #|while IFS= read -r line; do
      #|  count=$((count + 1))
      #|  printf '{"count":%s,"echo":%s}\n' "$count" "$line"
      #|done
    ),
  )
  let run = run_jsonl_command_batches(config, session_id="fixture", [
    [StartRpc("fixture", "/repo")],
    [SendUserInput("fixture", "first prompt")],
    [SendUserInput("fixture", "second prompt"), CancelRpcRun("fixture")],
  ])
  inspect(run.exit_code, content="0")
  inspect(run.sent_lines().length(), content="4")
  inspect(run.received_lines().length(), content="4")
  inspect(
    run.events.filter(event => event is ProcessStarted(_)).length(),
    content="1",
  )
  json_inspect(@json.parse(run.received_lines()[3]), content={
    "count": 4,
    "echo": { "type": "cancel_run", "session_id": "fixture" },
  })
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "native transport owner reuses one jsonl process across runtime dispatches" {
  let config = PiNativeTransportConfig::shell(
    script=(
      #|count=0
      #|while IFS= read -r line; do
      #|  count=$((count + 1))
      #|  printf '{"count":%s,"echo":%s}\n' "$count" "$line"
      #|done
    ),
  )
  let owner = PiNativeTransportOwner::new(config, session_id="fixture")
  let runtime = owner.runtime()
  let events : Ref[Array[@app.PiTransportEvent]] = Ref([])
  let emit = event => events.val.push(event)
  @async.with_task_group(group => {
    group.spawn_bg(() => owner.run())
    runtime.dispatch([StartRpc("fixture", "/repo")], emit)
    @async.sleep(1)
    runtime.dispatch([SendUserInput("fixture", "first prompt")], emit)
    @async.sleep(1)
    runtime.dispatch(
      [SendUserInput("fixture", "second prompt"), Shutdown],
      emit,
    )
  })
  inspect(
    events.val.filter(event => event is ProcessStarted(_)).length(),
    content="1",
  )
  inspect(
    events.val.filter(event => event is JsonLineSent(_, _)).length(),
    content="4",
  )
  let received = events.val.filter(event => event is JsonLineReceived(_, _))
  inspect(received.length(), content="4")
  assert_true(events.val.any(event => event is ProcessExited(0)))
  match received[2] {
    JsonLineReceived(session, line) => {
      inspect(session, content="fixture")
      json_inspect(@json.parse(line), content={
        "count": 3,
        "echo": {
          "type": "user_input",
          "session_id": "fixture",
          "text": "second prompt",
        },
      })
    }
    _ => fail("expected received JSONL line")
  }
}

///|
#cfg(all(target="native", not(platform="windows")))
test "native transport runtime emits command batch events through app hook" {
  let config = PiNativeTransportConfig::shell(
    script=(
      #|while IFS= read -r line; do
      #|  printf '{"echo":%s}\n' "$line"
      #|done
    ),
  )
  let events : Ref[Array[@app.PiTransportEvent]] = Ref([])
  config
  .runtime()
  .dispatch(
    [StartRpc("fixture", "/repo"), SendUserInput("fixture", "hello pi")],
    event => {
      let next = events.val.copy()
      next.push(event)
      events.val = next
    },
  )
  inspect(events.val.length(), content="6")
  assert_true(events.val.any(event => event is ProcessStarted(_)))
  assert_true(events.val.any(event => event is JsonLineReceived(_, _)))
  assert_true(events.val.any(event => event is ProcessExited(0)))
}
