///|
using @app {type PiTransportEvent}

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
pub async fn run_jsonl_session(
  config : PiNativeTransportConfig,
  session_id~ : String,
  lines : Array[String],
) -> PiNativeTransportRun {
  @async.with_task_group(group => {
    let (process_stdin, stdin_writer) = @process.write_to_process()
    let (stdout_reader, process_stdout) = @process.read_from_process()
    let process = spawn_process(
      group,
      config,
      stdin=process_stdin,
      stdout=process_stdout,
    )
    let writer_task = group.spawn(() => {
      write_jsonl_lines(stdin_writer, session_id~, lines)
    })
    let reader_task = group.spawn(() => {
      read_jsonl_lines(stdout_reader, session_id~)
    })
    let exit_code = process.wait()
    let events : Array[PiTransportEvent] = [
      ProcessStarted(process.pid.to_string()),
    ]
    events.append(writer_task.wait())
    events.append(reader_task.wait())
    events.push(ProcessExited(exit_code))
    { events, exit_code }
  })
}

///|
async fn[X] spawn_process(
  group : @async.TaskGroup[X],
  config : PiNativeTransportConfig,
  stdin~ : &@process.ProcessInput,
  stdout~ : &@process.ProcessOutput,
) -> @process.Process {
  if config.cwd == "" {
    @process.spawn(group, config.command, config.args, stdin~, stdout~)
  } else {
    @process.spawn(
      group,
      config.command,
      config.args,
      stdin~,
      stdout~,
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
