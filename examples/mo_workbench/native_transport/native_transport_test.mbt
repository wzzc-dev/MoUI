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
  let state = pi_rpc_get_state_line()
  let input = pi_rpc_prompt_line(message="Inspect renderer capability tests")
  let abort = pi_rpc_abort_line()
  json_inspect(@json.parse(state), content={ "type": "get_state" })
  json_inspect(@json.parse(input), content={
    "type": "prompt",
    "message": "Inspect renderer capability tests",
  })
  json_inspect(@json.parse(abort), content={ "type": "abort" })
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
  inspect(request.lines.length(), content="3")
  json_inspect(@json.parse(request.lines[0]), content={ "type": "get_state" })
  json_inspect(@json.parse(request.lines[1]), content={
    "type": "prompt",
    "message": "hello",
  })
  json_inspect(@json.parse(request.lines[2]), content={ "type": "abort" })
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
    "echo": { "type": "get_state" },
  })
  json_inspect(@json.parse(run.received_lines()[1]), content={
    "echo": { "type": "prompt", "message": "hello pi" },
  })
  assert_true(run.events.any(event => event is ProcessStarted(_)))
  assert_true(run.events.any(event => event is ProcessExited(0)))
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "native transport command run surfaces stderr and nonzero exit" {
  let config = PiNativeTransportConfig::shell(
    script=(
      #|if IFS= read -r line; then
      #|  printf 'pi exploded\n' >&2
      #|  exit 7
      #|fi
    ),
  )
  let run = run_jsonl_commands(config, [StartRpc("fixture", "/repo")])
  inspect(run.exit_code, content="7")
  assert_true(run.events.any(event => event is ProcessStarted(_)))
  assert_true(run.events.any(event => event is JsonLineSent(_, _)))
  assert_true(
    run.events.any(event => event is ProcessStderr("fixture", "pi exploded")),
  )
  assert_true(run.events.any(event => event is ProcessExited(7)))
  assert_true(
    run.events.any(event => {
      event is TransportFailed(reason) &&
      reason.contains("exited with code 7") &&
      reason.contains("pi exploded")
    }),
  )
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
    "echo": { "type": "get_state" },
  })
  json_inspect(@json.parse(run.received_lines()[1]), content={
    "count": 2,
    "echo": { "type": "prompt", "message": "first prompt" },
  })
  json_inspect(@json.parse(run.received_lines()[2]), content={
    "count": 3,
    "echo": { "type": "prompt", "message": "second prompt" },
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
    "echo": { "type": "abort" },
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
    content="3",
  )
  let received = events.val.filter(event => event is JsonLineReceived(_, _))
  inspect(received.length(), content="3")
  assert_true(events.val.any(event => event is ProcessExited(0)))
  match received[2] {
    JsonLineReceived(session, line) => {
      inspect(session, content="fixture")
      json_inspect(@json.parse(line), content={
        "count": 3,
        "echo": { "type": "prompt", "message": "second prompt" },
      })
    }
    _ => fail("expected received JSONL line")
  }
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "native transport owner surfaces stderr and nonzero exit" {
  let config = PiNativeTransportConfig::shell(
    script=(
      #|if IFS= read -r line; then
      #|  printf 'pi exploded\n' >&2
      #|  exit 7
      #|fi
    ),
  )
  let owner = PiNativeTransportOwner::new(config, session_id="fixture")
  let runtime = owner.runtime()
  let events : Ref[Array[@app.PiTransportEvent]] = Ref([])
  let emit = event => events.val.push(event)
  @async.with_task_group(group => {
    group.spawn_bg(() => owner.run())
    runtime.dispatch([StartRpc("fixture", "/repo")], emit)
    @async.sleep(20)
    owner.shutdown()
  })
  assert_true(events.val.any(event => event is ProcessStarted(_)))
  assert_true(events.val.any(event => event is JsonLineSent(_, _)))
  assert_true(
    events.val.any(event => event is ProcessStderr("fixture", "pi exploded")),
  )
  assert_true(events.val.any(event => event is ProcessExited(7)))
  assert_true(
    events.val.any(event => {
      event is TransportFailed(reason) &&
      reason.contains("exited with code 7") &&
      reason.contains("pi exploded")
    }),
  )
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "native transport owner restarts after unexpected process exit" {
  let config = PiNativeTransportConfig::shell(
    script=(
      #|if IFS= read -r line; then
      #|  printf '{"echo":%s}\n' "$line"
      #|  printf 'restartable failure\n' >&2
      #|  exit 7
      #|fi
    ),
  )
  let owner = PiNativeTransportOwner::new(config, session_id="fixture")
  let runtime = owner.runtime()
  let events : Ref[Array[@app.PiTransportEvent]] = Ref([])
  let emit = event => events.val.push(event)
  @async.with_task_group(group => {
    group.spawn_bg(() => owner.run())
    runtime.dispatch([StartRpc("fixture", "/repo")], emit)
    @async.sleep(20)
    runtime.dispatch([SendUserInput("fixture", "after restart")], emit)
    @async.sleep(20)
    owner.shutdown()
  })
  inspect(
    events.val.filter(event => event is ProcessStarted(_)).length(),
    content="2",
  )
  inspect(
    events.val.filter(event => event is JsonLineSent(_, _)).length(),
    content="2",
  )
  inspect(
    events.val.filter(event => event is JsonLineReceived(_, _)).length(),
    content="2",
  )
  inspect(
    events.val.filter(event => event is ProcessExited(7)).length(),
    content="2",
  )
  inspect(
    events.val.filter(event => event is TransportFailed(_)).length(),
    content="2",
  )
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
