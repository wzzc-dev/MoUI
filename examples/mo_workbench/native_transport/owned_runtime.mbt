///|
priv struct PiNativeTransportBatch {
  commands : Array[PiTransportCommand]
}

///|
pub struct PiNativeTransportOwner {
  priv config : PiNativeTransportConfig
  priv session_id : String
  priv queue : @aqueue.Queue[PiNativeTransportBatch]
  priv mut emit : ((PiTransportEvent) -> Unit)?
  priv mut running : Bool
  priv mut stopped : Bool
  priv mut shutdown_requested : Bool
}

///|
pub fn PiNativeTransportOwner::new(
  config : PiNativeTransportConfig,
  session_id? : String = "process",
) -> PiNativeTransportOwner {
  {
    config,
    session_id,
    queue: @aqueue.Queue::new(kind=Unbounded),
    emit: None,
    running: false,
    stopped: false,
    shutdown_requested: false,
  }
}

///|
pub fn PiNativeTransportOwner::runtime(
  self : PiNativeTransportOwner,
) -> PiTransportRuntime {
  PiTransportRuntime::new(run=(commands, emit) => {
    self.emit = Some(emit)
    self.enqueue(commands)
  })
}

///|
pub fn PiNativeTransportOwner::shutdown(self : PiNativeTransportOwner) -> Unit {
  if !self.shutdown_requested {
    self.shutdown_requested = true
    ignore(
      self.queue.try_put(PiNativeTransportBatch::{ commands: [Shutdown] }) catch {
        _ => false
      },
    )
  }
}

///|
pub async fn PiNativeTransportOwner::run(self : PiNativeTransportOwner) -> Unit {
  if self.running || self.stopped {
    return ()
  }
  self.running = true
  defer {
    self.running = false
    self.stopped = true
  }
  let first = Some(self.queue.get()) catch {
    err => {
      self.emit_event(TransportFailed("native Pi queue failed: \{err}"))
      None
    }
  }
  match first {
    Some(batch) =>
      if !batch.shutdown_without_process() {
        self.run_process(batch) catch {
          err =>
            self.emit_event(TransportFailed("native Pi owner failed: \{err}"))
        }
      }
    None => ()
  }
}

///|
fn PiNativeTransportOwner::enqueue(
  self : PiNativeTransportOwner,
  commands : Array[PiTransportCommand],
) -> Unit {
  if commands.is_empty() {
    return ()
  }
  if self.stopped || self.shutdown_requested {
    self.emit_event(TransportFailed("native Pi session is already closed"))
  } else {
    let enqueued = self.queue.try_put(PiNativeTransportBatch::{ commands, }) catch {
      err => {
        self.emit_event(TransportFailed("native Pi queue failed: \{err}"))
        false
      }
    }
    if !enqueued {
      self.emit_event(TransportFailed("native Pi queue rejected command batch"))
    }
  }
}

///|
async fn PiNativeTransportOwner::run_process(
  self : PiNativeTransportOwner,
  first : PiNativeTransportBatch,
) -> Unit {
  @async.with_task_group(group => {
    let (process_stdin, stdin_writer) = @process.write_to_process()
    let (stdout_reader, process_stdout) = @process.read_from_process()
    let (stderr_reader, process_stderr) = @process.read_from_process()
    let process = spawn_process(
      group,
      self.config,
      stdin=process_stdin,
      stdout=process_stdout,
      stderr=process_stderr,
    )
    let active_session = Ref(self.session_id)
    let last_stderr = Ref("")
    self.emit_event(ProcessStarted(process.pid.to_string()))
    let stdout_task = group.spawn(allow_failure=true, () => {
      emit_jsonl_lines(stdout_reader, active_session, event => {
        self.emit_event(event)
      })
    })
    let stderr_task = group.spawn(allow_failure=true, () => {
      emit_stderr_lines(stderr_reader, active_session, last_stderr, event => {
        self.emit_event(event)
      })
    })
    let mut should_close = self.send_batch(stdin_writer, active_session, first)
    let mut observed_exit : Int? = None
    while !should_close && observed_exit is None {
      match process.try_wait() {
        Some(code) => {
          observed_exit = Some(code)
          should_close = true
        }
        None =>
          match (self.queue.try_get() catch { _ => None }) {
            Some(batch) =>
              should_close = self.send_batch(
                stdin_writer, active_session, batch,
              )
            None => @async.sleep(8)
          }
      }
    }
    stdin_writer.close()
    let exit_code = match observed_exit {
      Some(code) => code
      None => process.wait()
    }
    stdout_task.wait() catch {
      _ => ()
    }
    stderr_task.wait() catch {
      _ => ()
    }
    self.emit_event(ProcessExited(exit_code))
    if exit_code != 0 {
      self.emit_event(
        TransportFailed(
          process_exit_failure_reason(self.config, exit_code, last_stderr.val),
        ),
      )
    }
  })
}

///|
async fn PiNativeTransportOwner::send_batch(
  self : PiNativeTransportOwner,
  writer : @process.WriteToProcess,
  active_session : Ref[String],
  batch : PiNativeTransportBatch,
) -> Bool {
  let request = commands_to_request(
    batch.commands,
    default_session_id=active_session.val,
  )
  active_session.val = request.session_id
  for line in request.lines {
    writer.write(line + "\n")
    self.emit_event(JsonLineSent(request.session_id, line))
  }
  batch.commands.any(command => command is Shutdown)
}

///|
fn PiNativeTransportOwner::emit_event(
  self : PiNativeTransportOwner,
  event : PiTransportEvent,
) -> Unit {
  match self.emit {
    Some(emit) => emit(event)
    None => ()
  }
}

///|
fn PiNativeTransportBatch::shutdown_without_process(
  self : PiNativeTransportBatch,
) -> Bool {
  self.commands.length() == 1 && self.commands[0] is Shutdown
}

///|
async fn emit_jsonl_lines(
  reader : @process.ReadFromProcess,
  active_session : Ref[String],
  emit : (PiTransportEvent) -> Unit,
) -> Unit {
  defer reader.close()
  for ;; {
    guard reader.read_until("\n") is Some(line) else { break }
    let line = line.trim(char_set="\r").to_owned()
    if line != "" {
      emit(JsonLineReceived(active_session.val, line))
    }
  }
}

///|
async fn emit_stderr_lines(
  reader : @process.ReadFromProcess,
  active_session : Ref[String],
  last_stderr : Ref[String],
  emit : (PiTransportEvent) -> Unit,
) -> Unit {
  defer reader.close()
  for ;; {
    guard reader.read_until("\n") is Some(line) else { break }
    let line = line.trim(char_set="\r").to_owned()
    if line != "" {
      last_stderr.val = line
      emit(ProcessStderr(active_session.val, line))
    }
  }
}
