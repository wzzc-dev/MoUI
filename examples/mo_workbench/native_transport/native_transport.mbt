///|
using @app {
  type PiTransportCommand,
  type PiTransportEvent,
  type PiTransportRuntime,
}

///|
pub(all) struct PiNativeTransportConfig {
  command : String
  args : Array[String]
  cwd : String
}

///|
pub(all) struct PiNativeTransportRun {
  events : Array[PiTransportEvent]
  exit_code : Int
} derive(Eq, Debug)

///|
pub(all) struct PiNativeTransportRequest {
  session_id : String
  lines : Array[String]
} derive(Eq, Debug)

///|
pub struct PiNativeTransportSession {
  priv session_id : String
  priv writer : @process.WriteToProcess
  priv sent_events : Array[PiTransportEvent]
  priv mut closed : Bool
}

///|
pub fn PiNativeTransportConfig::new(
  command~ : String,
  args? : Array[String] = [],
  cwd? : String = "",
) -> PiNativeTransportConfig {
  { command, args, cwd }
}

///|
pub fn PiNativeTransportConfig::pi(
  cwd? : String = "",
) -> PiNativeTransportConfig {
  PiNativeTransportConfig::new(command="pi", args=["--mode", "rpc"], cwd~)
}

///|
pub fn PiNativeTransportConfig::shell(
  script~ : String,
  cwd? : String = "",
) -> PiNativeTransportConfig {
  PiNativeTransportConfig::new(command="sh", args=["-c", script], cwd~)
}

///|
pub fn PiNativeTransportConfig::command_label(
  self : PiNativeTransportConfig,
) -> String {
  if self.args.length() == 0 {
    self.command
  } else {
    self.command + " " + self.args.join(" ")
  }
}

///|
pub fn pi_rpc_start_line(session_id~ : String, cwd~ : String) -> String {
  ({ "type": "start_session", "session_id": session_id, "cwd": cwd } : Json).stringify()
}

///|
pub fn pi_rpc_user_input_line(session_id~ : String, text~ : String) -> String {
  ({ "type": "user_input", "session_id": session_id, "text": text } : Json).stringify()
}

///|
pub fn pi_rpc_cancel_line(session_id~ : String) -> String {
  ({ "type": "cancel_run", "session_id": session_id } : Json).stringify()
}

///|
pub fn pi_rpc_shutdown_line() -> String {
  ({ "type": "shutdown" } : Json).stringify()
}

///|
pub fn PiNativeTransportRequest::from_commands(
  commands : Array[PiTransportCommand],
) -> PiNativeTransportRequest {
  commands_to_request(commands, default_session_id="process")
}

///|
fn commands_to_request(
  commands : Array[PiTransportCommand],
  default_session_id~ : String,
) -> PiNativeTransportRequest {
  let lines : Array[String] = []
  let mut session_id = default_session_id
  for command in commands {
    match command {
      StartRpc(session, cwd) => {
        if session_id == default_session_id {
          session_id = session
        }
        lines.push(pi_rpc_start_line(session_id=session, cwd~))
      }
      SendUserInput(session, text) => {
        if session_id == default_session_id {
          session_id = session
        }
        lines.push(pi_rpc_user_input_line(session_id=session, text~))
      }
      CancelRpcRun(session) => {
        if session_id == default_session_id {
          session_id = session
        }
        lines.push(pi_rpc_cancel_line(session_id=session))
      }
      Shutdown => lines.push(pi_rpc_shutdown_line())
    }
  }
  { session_id, lines }
}

///|
pub fn PiNativeTransportSession::session_id(
  self : PiNativeTransportSession,
) -> String {
  self.session_id
}

///|
pub async fn PiNativeTransportSession::send_commands(
  self : PiNativeTransportSession,
  commands : Array[PiTransportCommand],
) -> Unit {
  let request = commands_to_request(
    commands,
    default_session_id=self.session_id,
  )
  self.send_lines(request.session_id, request.lines)
}

///|
pub async fn PiNativeTransportSession::send_lines(
  self : PiNativeTransportSession,
  session_id : String,
  lines : Array[String],
) -> Unit {
  for line in lines {
    self.writer.write(line + "\n")
    self.sent_events.push(JsonLineSent(session_id, line))
  }
}

///|
pub fn PiNativeTransportSession::close(self : PiNativeTransportSession) -> Unit {
  if !self.closed {
    self.writer.close()
    self.closed = true
  }
}

///|
pub async fn run_jsonl_session(
  config : PiNativeTransportConfig,
  session_id~ : String,
  lines : Array[String],
) -> PiNativeTransportRun {
  @async.with_task_group(group => {
    let (process_stdin, stdin_writer) = @process.write_to_process()
    let (stdout_reader, process_stdout) = @process.read_from_process()
    let (stderr_reader, process_stderr) = @process.read_from_process()
    let last_stderr = Ref("")
    let process = spawn_process(
      group,
      config,
      stdin=process_stdin,
      stdout=process_stdout,
      stderr=process_stderr,
    )
    let writer_task = group.spawn(() => {
      write_jsonl_lines(stdin_writer, session_id~, lines)
    })
    let reader_task = group.spawn(() => {
      read_jsonl_lines(stdout_reader, session_id~)
    })
    let stderr_task = group.spawn(() => {
      read_stderr_lines(stderr_reader, session_id~, last_stderr)
    })
    let exit_code = process.wait()
    let events : Array[PiTransportEvent] = [
      ProcessStarted(process.pid.to_string()),
    ]
    events.append(writer_task.wait())
    events.append(reader_task.wait())
    events.append(stderr_task.wait())
    append_process_exit_events(events, config, exit_code, last_stderr.val)
    { events, exit_code }
  })
}

///|
pub async fn run_interactive_jsonl_session(
  config : PiNativeTransportConfig,
  session_id~ : String,
  drive : async (PiNativeTransportSession) -> Unit,
) -> PiNativeTransportRun {
  @async.with_task_group(group => {
    let (process_stdin, stdin_writer) = @process.write_to_process()
    let (stdout_reader, process_stdout) = @process.read_from_process()
    let (stderr_reader, process_stderr) = @process.read_from_process()
    let last_stderr = Ref("")
    let process = spawn_process(
      group,
      config,
      stdin=process_stdin,
      stdout=process_stdout,
      stderr=process_stderr,
    )
    let session = PiNativeTransportSession::{
      session_id,
      writer: stdin_writer,
      sent_events: [],
      closed: false,
    }
    let reader_task = group.spawn(() => {
      read_jsonl_lines(stdout_reader, session_id~)
    })
    let stderr_task = group.spawn(() => {
      read_stderr_lines(stderr_reader, session_id~, last_stderr)
    })
    let events : Array[PiTransportEvent] = [
      ProcessStarted(process.pid.to_string()),
    ]
    defer session.close()
    drive(session)
    session.close()
    let exit_code = process.wait()
    events.append(session.sent_events)
    events.append(reader_task.wait())
    events.append(stderr_task.wait())
    append_process_exit_events(events, config, exit_code, last_stderr.val)
    { events, exit_code }
  })
}

///|
pub async fn run_jsonl_commands(
  config : PiNativeTransportConfig,
  commands : Array[PiTransportCommand],
) -> PiNativeTransportRun {
  let request = PiNativeTransportRequest::from_commands(commands)
  run_jsonl_session(config, session_id=request.session_id, request.lines)
}

///|
pub async fn run_jsonl_command_batches(
  config : PiNativeTransportConfig,
  session_id~ : String,
  batches : Array[Array[PiTransportCommand]],
) -> PiNativeTransportRun {
  run_interactive_jsonl_session(config, session_id~, session => {
    for commands in batches {
      session.send_commands(commands)
    }
  })
}

///|
pub fn run_jsonl_command_batches_blocking(
  config : PiNativeTransportConfig,
  session_id~ : String,
  batches : Array[Array[PiTransportCommand]],
) -> PiNativeTransportRun {
  let result : Ref[PiNativeTransportRun?] = Ref(None)
  @async.run_async_main(() => {
    let run = run_jsonl_command_batches(config, session_id~, batches) catch {
      err => failed_run("\{err}")
    }
    result.val = Some(run)
  })
  match result.val {
    Some(run) => run
    None => failed_run("native async session did not produce a result")
  }
}

///|
pub fn run_jsonl_commands_blocking(
  config : PiNativeTransportConfig,
  commands : Array[PiTransportCommand],
) -> PiNativeTransportRun {
  let result : Ref[PiNativeTransportRun?] = Ref(None)
  @async.run_async_main(() => {
    let run = run_jsonl_commands(config, commands) catch {
      err => failed_run("\{err}")
    }
    result.val = Some(run)
  })
  match result.val {
    Some(run) => run
    None => failed_run("native async transport did not produce a result")
  }
}

///|
pub fn PiNativeTransportConfig::runtime(
  self : PiNativeTransportConfig,
) -> PiTransportRuntime {
  PiTransportRuntime::new(run=(commands, emit) => {
    let run = run_jsonl_commands_blocking(self, commands)
    for event in run.events {
      emit(event)
    }
  })
}

///|
fn failed_run(reason : String) -> PiNativeTransportRun {
  { events: [TransportFailed(reason)], exit_code: -1 }
}

///|
fn append_process_exit_events(
  events : Array[PiTransportEvent],
  config : PiNativeTransportConfig,
  exit_code : Int,
  last_stderr : String,
) -> Unit {
  events.push(ProcessExited(exit_code))
  if exit_code != 0 {
    events.push(
      TransportFailed(
        process_exit_failure_reason(config, exit_code, last_stderr),
      ),
    )
  }
}

///|
fn process_exit_failure_reason(
  config : PiNativeTransportConfig,
  exit_code : Int,
  last_stderr : String,
) -> String {
  let prefix = config.command_label() +
    " exited with code " +
    exit_code.to_string()
  if last_stderr == "" {
    prefix
  } else {
    prefix + ": " + last_stderr
  }
}

///|
async fn[X] spawn_process(
  group : @async.TaskGroup[X],
  config : PiNativeTransportConfig,
  stdin~ : &@process.ProcessInput,
  stdout~ : &@process.ProcessOutput,
  stderr? : &@process.ProcessOutput,
) -> @process.Process {
  if config.cwd == "" {
    @process.spawn(group, config.command, config.args, stdin~, stdout~, stderr?)
  } else {
    @process.spawn(
      group,
      config.command,
      config.args,
      stdin~,
      stdout~,
      stderr?,
      cwd=config.cwd,
    )
  }
}

///|
async fn write_jsonl_lines(
  writer : @process.WriteToProcess,
  session_id~ : String,
  lines : Array[String],
) -> Array[PiTransportEvent] {
  defer writer.close()
  let events : Array[PiTransportEvent] = []
  for line in lines {
    writer.write(line + "\n")
    events.push(JsonLineSent(session_id, line))
  }
  events
}

///|
async fn read_jsonl_lines(
  reader : @process.ReadFromProcess,
  session_id~ : String,
) -> Array[PiTransportEvent] {
  defer reader.close()
  let events : Array[PiTransportEvent] = []
  for ;; {
    guard reader.read_until("\n") is Some(line) else { break }
    let line = line.trim(char_set="\r").to_owned()
    if line != "" {
      events.push(JsonLineReceived(session_id, line))
    }
  }
  events
}

///|
async fn read_stderr_lines(
  reader : @process.ReadFromProcess,
  session_id~ : String,
  last_stderr : Ref[String],
) -> Array[PiTransportEvent] {
  defer reader.close()
  let events : Array[PiTransportEvent] = []
  for ;; {
    guard reader.read_until("\n") is Some(line) else { break }
    let line = line.trim(char_set="\r").to_owned()
    if line != "" {
      last_stderr.val = line
      events.push(ProcessStderr(session_id, line))
    }
  }
  events
}

///|
pub fn PiNativeTransportRun::received_lines(
  self : PiNativeTransportRun,
) -> Array[String] {
  let lines : Array[String] = []
  for event in self.events {
    match event {
      JsonLineReceived(_session, line) => lines.push(line)
      _ => ()
    }
  }
  lines
}

///|
pub fn PiNativeTransportRun::sent_lines(
  self : PiNativeTransportRun,
) -> Array[String] {
  let lines : Array[String] = []
  for event in self.events {
    match event {
      JsonLineSent(_session, line) => lines.push(line)
      _ => ()
    }
  }
  lines
}
