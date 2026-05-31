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
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "native transport drives jsonl stdin stdout process" {
  let config = PiNativeTransportConfig::shell(
    script=(
      #|while IFS= read -r line; do
      #|  printf '{"echo":%s}\n' "$line"
      #|done
    ),
  )
  let start = pi_rpc_start_line(session_id="fixture", cwd="/repo")
  let input = pi_rpc_user_input_line(session_id="fixture", text="hello pi")
  let run = run_jsonl_session(config, session_id="fixture", [start, input])
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
