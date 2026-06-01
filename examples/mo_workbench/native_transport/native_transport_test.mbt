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
  let new_session = pi_rpc_new_session_line()
  let messages = pi_rpc_get_messages_line()
  let available_models = pi_rpc_get_available_models_line()
  let fork_messages = pi_rpc_get_fork_messages_line()
  let commands = pi_rpc_get_commands_line()
  let stats = pi_rpc_get_session_stats_line()
  let fork = pi_rpc_fork_line(entry_id="entry-1")
  let export_default = pi_rpc_export_html_line(output_path="")
  let export_path = pi_rpc_export_html_line(
    output_path="/tmp/mo-workbench.html",
  )
  let set_model = pi_rpc_set_model_line(provider="openai", model_id="gpt-5")
  let model = pi_rpc_cycle_model_line()
  let compact = pi_rpc_compact_line(custom_instructions="")
  let compact_custom = pi_rpc_compact_line(
    custom_instructions="Preserve file decisions",
  )
  let thinking = pi_rpc_cycle_thinking_level_line()
  let steering = pi_rpc_set_steering_mode_line(mode="all")
  let follow_up = pi_rpc_set_follow_up_mode_line(mode="one-at-a-time")
  let switch_session = pi_rpc_switch_session_line(session_path="/tmp/pi.jsonl")
  let session_name = pi_rpc_set_session_name_line(name="Mo Workbench")
  let input = pi_rpc_prompt_line(message="Inspect renderer capability tests")
  let steer = pi_rpc_steer_line(message="Prefer narrow edits")
  let follow_up_input = pi_rpc_follow_up_line(message="Update docs")
  let bash = pi_rpc_bash_line(command="moon check")
  let abort_bash = pi_rpc_abort_bash_line()
  let abort = pi_rpc_abort_line()
  json_inspect(@json.parse(state), content={ "type": "get_state" })
  json_inspect(@json.parse(new_session), content={ "type": "new_session" })
  json_inspect(@json.parse(messages), content={ "type": "get_messages" })
  json_inspect(@json.parse(available_models), content={
    "type": "get_available_models",
  })
  json_inspect(@json.parse(fork_messages), content={
    "type": "get_fork_messages",
  })
  json_inspect(@json.parse(commands), content={ "type": "get_commands" })
  json_inspect(@json.parse(stats), content={ "type": "get_session_stats" })
  json_inspect(@json.parse(fork), content={
    "type": "fork",
    "entryId": "entry-1",
  })
  json_inspect(@json.parse(export_default), content={ "type": "export_html" })
  json_inspect(@json.parse(export_path), content={
    "type": "export_html",
    "outputPath": "/tmp/mo-workbench.html",
  })
  json_inspect(@json.parse(set_model), content={
    "type": "set_model",
    "provider": "openai",
    "modelId": "gpt-5",
  })
  json_inspect(@json.parse(model), content={ "type": "cycle_model" })
  json_inspect(@json.parse(compact), content={ "type": "compact" })
  json_inspect(@json.parse(compact_custom), content={
    "type": "compact",
    "customInstructions": "Preserve file decisions",
  })
  json_inspect(@json.parse(thinking), content={ "type": "cycle_thinking_level" })
  json_inspect(@json.parse(steering), content={
    "type": "set_steering_mode",
    "mode": "all",
  })
  json_inspect(@json.parse(follow_up), content={
    "type": "set_follow_up_mode",
    "mode": "one-at-a-time",
  })
  json_inspect(@json.parse(switch_session), content={
    "type": "switch_session",
    "sessionPath": "/tmp/pi.jsonl",
  })
  json_inspect(@json.parse(session_name), content={
    "type": "set_session_name",
    "name": "Mo Workbench",
  })
  json_inspect(@json.parse(input), content={
    "type": "prompt",
    "message": "Inspect renderer capability tests",
  })
  json_inspect(@json.parse(steer), content={
    "type": "steer",
    "message": "Prefer narrow edits",
  })
  json_inspect(@json.parse(follow_up_input), content={
    "type": "follow_up",
    "message": "Update docs",
  })
  json_inspect(@json.parse(bash), content={
    "type": "bash",
    "command": "moon check",
  })
  json_inspect(@json.parse(abort_bash), content={ "type": "abort_bash" })
  json_inspect(@json.parse(abort), content={ "type": "abort" })
}

///|
async test "native transport maps command batches to jsonl requests" {
  let request = PiNativeTransportRequest::from_commands([
    StartRpc("session-1", "/repo"),
    NewRpcSession("session-1"),
    SwitchRpcSession("session-1", "/tmp/pi.jsonl"),
    FetchRpcAvailableModels("session-1"),
    FetchRpcMessages("session-1"),
    FetchRpcForkMessages("session-1"),
    FetchRpcCommands("session-1"),
    FetchRpcSessionStats("session-1"),
    ForkRpcSession("session-1", "entry-1"),
    ExportRpcSessionHtml("session-1", "/tmp/mo-workbench.html"),
    SetRpcModel("session-1", "openai", "gpt-5"),
    CycleRpcModel("session-1"),
    CompactRpcSession("session-1", ""),
    CycleRpcThinkingLevel("session-1"),
    SetRpcSteeringMode("session-1", "all"),
    SetRpcFollowUpMode("session-1", "one-at-a-time"),
    SetRpcSessionName("session-1", "Mo Workbench"),
    SendUserInput("session-1", "hello"),
    SendSteeringInput("session-1", "prefer tests"),
    SendFollowUpInput("session-1", "update docs"),
    RunShellCommand("session-1", "moon check"),
    CancelShellCommand("session-1"),
    CancelRpcRun("session-1"),
    Shutdown,
  ])
  inspect(request.session_id, content="session-1")
  inspect(request.lines.length(), content="23")
  json_inspect(@json.parse(request.lines[0]), content={ "type": "get_state" })
  json_inspect(@json.parse(request.lines[1]), content={ "type": "new_session" })
  json_inspect(@json.parse(request.lines[2]), content={
    "type": "switch_session",
    "sessionPath": "/tmp/pi.jsonl",
  })
  json_inspect(@json.parse(request.lines[3]), content={
    "type": "get_available_models",
  })
  json_inspect(@json.parse(request.lines[4]), content={ "type": "get_messages" })
  json_inspect(@json.parse(request.lines[5]), content={
    "type": "get_fork_messages",
  })
  json_inspect(@json.parse(request.lines[6]), content={ "type": "get_commands" })
  json_inspect(@json.parse(request.lines[7]), content={
    "type": "get_session_stats",
  })
  json_inspect(@json.parse(request.lines[8]), content={
    "type": "fork",
    "entryId": "entry-1",
  })
  json_inspect(@json.parse(request.lines[9]), content={
    "type": "export_html",
    "outputPath": "/tmp/mo-workbench.html",
  })
  json_inspect(@json.parse(request.lines[10]), content={
    "type": "set_model",
    "provider": "openai",
    "modelId": "gpt-5",
  })
  json_inspect(@json.parse(request.lines[11]), content={ "type": "cycle_model" })
  json_inspect(@json.parse(request.lines[12]), content={ "type": "compact" })
  json_inspect(@json.parse(request.lines[13]), content={
    "type": "cycle_thinking_level",
  })
  json_inspect(@json.parse(request.lines[14]), content={
    "type": "set_steering_mode",
    "mode": "all",
  })
  json_inspect(@json.parse(request.lines[15]), content={
    "type": "set_follow_up_mode",
    "mode": "one-at-a-time",
  })
  json_inspect(@json.parse(request.lines[16]), content={
    "type": "set_session_name",
    "name": "Mo Workbench",
  })
  json_inspect(@json.parse(request.lines[17]), content={
    "type": "prompt",
    "message": "hello",
  })
  json_inspect(@json.parse(request.lines[18]), content={
    "type": "steer",
    "message": "prefer tests",
  })
  json_inspect(@json.parse(request.lines[19]), content={
    "type": "follow_up",
    "message": "update docs",
  })
  json_inspect(@json.parse(request.lines[20]), content={
    "type": "bash",
    "command": "moon check",
  })
  json_inspect(@json.parse(request.lines[21]), content={ "type": "abort_bash" })
  json_inspect(@json.parse(request.lines[22]), content={ "type": "abort" })
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
