///|
pub(all) struct PdfWorkbenchPdfliteNativeTransportConfig {
  command : String
  args : Array[String]
  cwd : String
}

///|
pub(all) struct PdfWorkbenchPdfliteNativeTransportEnvConfig {
  helper_path : String
  helper_args : String
  helper_cwd : String
}

///|
pub fn PdfWorkbenchPdfliteNativeTransportConfig::new(
  command~ : String,
  args? : Array[String] = [],
  cwd? : String = "",
) -> PdfWorkbenchPdfliteNativeTransportConfig {
  { command, args, cwd }
}

///|
pub fn PdfWorkbenchPdfliteNativeTransportEnvConfig::new(
  helper_path? : String = "",
  helper_args? : String = "",
  helper_cwd? : String = "",
) -> PdfWorkbenchPdfliteNativeTransportEnvConfig {
  { helper_path, helper_args, helper_cwd }
}

///|
pub fn PdfWorkbenchPdfliteNativeTransportEnvConfig::transport_config(
  self : PdfWorkbenchPdfliteNativeTransportEnvConfig,
) -> PdfWorkbenchPdfliteNativeTransportConfig? {
  let path = pdf_workbench_pdflite_helper_path(self.helper_path)
  if path == "" {
    None
  } else {
    Some(
      PdfWorkbenchPdfliteNativeTransportConfig::executable(
        path~,
        args=pdf_workbench_pdflite_helper_args(self.helper_args),
        cwd=self.helper_cwd.trim().to_owned(),
      ),
    )
  }
}

///|
pub fn pdf_workbench_pdflite_default_helper_path() -> String {
  "_build/native/debug/build/examples/pdf_workbench/pdflite_service_cli/pdflite_service_cli.exe"
}

///|
pub fn PdfWorkbenchPdfliteNativeTransportEnvConfig::document_services(
  self : PdfWorkbenchPdfliteNativeTransportEnvConfig,
) -> @app.PdfWorkbenchDocumentServices {
  match self.transport_config() {
    Some(config) => config.document_services()
    None => @app.PdfWorkbenchDocumentServices::lightweight()
  }
}

///|
fn pdf_workbench_pdflite_helper_path(value : String) -> String {
  let clean = value.trim().to_owned()
  if clean.to_lower() == "auto" {
    pdf_workbench_pdflite_default_helper_path()
  } else {
    clean
  }
}

///|
pub fn PdfWorkbenchPdfliteNativeTransportConfig::executable(
  path~ : String,
  args? : Array[String] = [],
  cwd? : String = "",
) -> PdfWorkbenchPdfliteNativeTransportConfig {
  PdfWorkbenchPdfliteNativeTransportConfig::new(command=path, args~, cwd~)
}

///|
pub fn PdfWorkbenchPdfliteNativeTransportConfig::shell(
  script~ : String,
  cwd? : String = "",
) -> PdfWorkbenchPdfliteNativeTransportConfig {
  PdfWorkbenchPdfliteNativeTransportConfig::new(
    command="sh",
    args=["-c", script],
    cwd~,
  )
}

///|
pub fn PdfWorkbenchPdfliteNativeTransportConfig::from_env_values(
  helper_path : String?,
  args_value? : String = "",
  cwd? : String = "",
) -> PdfWorkbenchPdfliteNativeTransportConfig? {
  match helper_path {
    Some(path) => {
      let clean_path = pdf_workbench_pdflite_helper_path(path)
      if clean_path == "" {
        None
      } else {
        Some(
          PdfWorkbenchPdfliteNativeTransportConfig::executable(
            path=clean_path,
            args=pdf_workbench_pdflite_helper_args(args_value),
            cwd=cwd.trim().to_owned(),
          ),
        )
      }
    }
    None => None
  }
}

///|
pub fn pdf_workbench_pdflite_helper_args(value : String) -> Array[String] {
  let clean = value.trim().to_owned()
  if clean == "" {
    return []
  }
  if pdf_workbench_pdflite_looks_like_json_array(clean) {
    match pdf_workbench_pdflite_helper_json_args(clean) {
      Some(args) => return args
      None => ()
    }
  }
  pdf_workbench_pdflite_helper_split_args(clean)
}

///|
pub fn PdfWorkbenchPdfliteNativeTransportConfig::command_label(
  self : PdfWorkbenchPdfliteNativeTransportConfig,
) -> String {
  if self.args.length() == 0 {
    self.command
  } else {
    self.command + " " + self.args.join(" ")
  }
}

///|
pub fn PdfWorkbenchPdfliteNativeTransportConfig::document_services(
  self : PdfWorkbenchPdfliteNativeTransportConfig,
) -> @app.PdfWorkbenchDocumentServices {
  @app.PdfWorkbenchDocumentServices::new(
    load=(path, bytes) => {
      match
        self.run_request_blocking(
          @protocol.PdfWorkbenchPdfliteServiceRequest::LoadDocument(path, bytes),
        ) {
        @protocol.PdfWorkbenchPdfliteServiceResponse::DocumentLoaded(document) =>
          @app.PdfWorkbenchLoadResult::Loaded(document)
        @protocol.PdfWorkbenchPdfliteServiceResponse::ServiceFailed(reason) =>
          @app.PdfWorkbenchLoadResult::Failed(reason)
        @protocol.PdfWorkbenchPdfliteServiceResponse::WritebackReady(_, _) =>
          @app.PdfWorkbenchLoadResult::Failed(
            "pdflite native transport returned writeback response while loading",
          )
      }
    },
    writeback=document => {
      match
        self.run_request_blocking(
          @protocol.PdfWorkbenchPdfliteServiceRequest::WritebackDocument(
            document.path,
            document.original_bytes,
            document.edits,
          ),
        ) {
        @protocol.PdfWorkbenchPdfliteServiceResponse::WritebackReady(
          bytes,
          diagnostics
        ) =>
          @app.PdfWorkbenchDocumentWritebackResult::WritebackReady(
            bytes, diagnostics,
          )
        @protocol.PdfWorkbenchPdfliteServiceResponse::ServiceFailed(reason) =>
          @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(reason)
        @protocol.PdfWorkbenchPdfliteServiceResponse::DocumentLoaded(_) =>
          @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(
            "pdflite native transport returned load response while writing",
          )
      }
    },
  )
}

///|
fn PdfWorkbenchPdfliteNativeTransportConfig::run_request_blocking(
  self : PdfWorkbenchPdfliteNativeTransportConfig,
  request : @protocol.PdfWorkbenchPdfliteServiceRequest,
) -> @protocol.PdfWorkbenchPdfliteServiceResponse {
  if self.command.trim().to_owned() == "" {
    return @protocol.PdfWorkbenchPdfliteServiceResponse::ServiceFailed(
      "pdflite helper command is not configured",
    )
  }
  let result : Ref[@protocol.PdfWorkbenchPdfliteServiceResponse?] = Ref(None)
  @async.run_async_main(() => {
    let response = self.run_request(request) catch {
      err =>
        @protocol.PdfWorkbenchPdfliteServiceResponse::ServiceFailed("\{err}")
    }
    result.val = Some(response)
  })
  match result.val {
    Some(response) => response
    None =>
      @protocol.PdfWorkbenchPdfliteServiceResponse::ServiceFailed(
        "pdflite native transport did not produce a response",
      )
  }
}

///|
async fn PdfWorkbenchPdfliteNativeTransportConfig::run_request(
  self : PdfWorkbenchPdfliteNativeTransportConfig,
  request : @protocol.PdfWorkbenchPdfliteServiceRequest,
) -> @protocol.PdfWorkbenchPdfliteServiceResponse {
  let request_line = request.to_json_line()
  let original_bytes = pdf_workbench_pdflite_request_original_bytes(request)
  @async.with_task_group(group => {
    let (process_stdin, stdin_writer) = @process.write_to_process()
    let (stdout_reader, process_stdout) = @process.read_from_process()
    let (stderr_reader, process_stderr) = @process.read_from_process()
    let process = pdf_workbench_pdflite_spawn_process(
      group,
      self,
      stdin=process_stdin,
      stdout=process_stdout,
      stderr=process_stderr,
    )
    let writer_task = group.spawn(() => {
      pdf_workbench_pdflite_write_request(stdin_writer, request_line)
    })
    let reader_task = group.spawn(() => {
      pdf_workbench_pdflite_read_lines(stdout_reader)
    })
    let stderr_task = group.spawn(() => {
      pdf_workbench_pdflite_read_lines(stderr_reader)
    })
    let exit_code = process.wait()
    writer_task.wait()
    let response_lines = reader_task.wait()
    let stderr_lines = stderr_task.wait()
    pdf_workbench_pdflite_decode_run_response(
      self,
      exit_code,
      response_lines,
      stderr_lines,
      original_bytes~,
    )
  })
}

///|
async fn[X] pdf_workbench_pdflite_spawn_process(
  group : @async.TaskGroup[X],
  config : PdfWorkbenchPdfliteNativeTransportConfig,
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
async fn pdf_workbench_pdflite_write_request(
  writer : @process.WriteToProcess,
  line : String,
) -> Unit {
  defer writer.close()
  writer.write(line + "\n")
}

///|
async fn pdf_workbench_pdflite_read_lines(
  reader : @process.ReadFromProcess,
) -> Array[String] {
  defer reader.close()
  let lines : Array[String] = []
  for ;; {
    guard reader.read_until("\n") is Some(line) else { break }
    let trimmed = line.trim(char_set="\r").to_owned()
    if trimmed != "" {
      lines.push(trimmed)
    }
  }
  lines
}

///|
fn pdf_workbench_pdflite_decode_run_response(
  config : PdfWorkbenchPdfliteNativeTransportConfig,
  exit_code : Int,
  response_lines : Array[String],
  stderr_lines : Array[String],
  original_bytes~ : Bytes,
) -> @protocol.PdfWorkbenchPdfliteServiceResponse {
  if exit_code != 0 {
    return @protocol.PdfWorkbenchPdfliteServiceResponse::ServiceFailed(
      pdf_workbench_pdflite_exit_failure(config, exit_code, stderr_lines),
    )
  }
  if response_lines.is_empty() {
    return @protocol.PdfWorkbenchPdfliteServiceResponse::ServiceFailed(
      "pdflite helper produced no JSONL response",
    )
  }
  match
    @protocol.PdfWorkbenchPdfliteServiceResponse::from_json_line(
      response_lines[0],
      original_bytes~,
    ) {
    Some(response) => response
    None =>
      @protocol.PdfWorkbenchPdfliteServiceResponse::ServiceFailed(
        "pdflite helper returned malformed JSONL response",
      )
  }
}

///|
fn pdf_workbench_pdflite_exit_failure(
  config : PdfWorkbenchPdfliteNativeTransportConfig,
  exit_code : Int,
  stderr_lines : Array[String],
) -> String {
  let prefix = config.command_label() +
    " exited with code " +
    exit_code.to_string()
  match stderr_lines.last() {
    Some(line) => prefix + ": " + line
    None => prefix
  }
}

///|
fn pdf_workbench_pdflite_request_original_bytes(
  request : @protocol.PdfWorkbenchPdfliteServiceRequest,
) -> Bytes {
  match request {
    @protocol.PdfWorkbenchPdfliteServiceRequest::LoadDocument(_, bytes) => bytes
    @protocol.PdfWorkbenchPdfliteServiceRequest::WritebackDocument(_, bytes, _) =>
      bytes
  }
}

///|
fn pdf_workbench_pdflite_looks_like_json_array(value : String) -> Bool {
  let chars = value.to_array()
  !chars.is_empty() && chars[0] == '['
}

///|
fn pdf_workbench_pdflite_helper_json_args(value : String) -> Array[String]? {
  let parsed = @json.parse(value) catch { _ => return None }
  guard parsed is Json::Array(values) else { return None }
  let args : Array[String] = []
  for item in values {
    guard item is Json::String(arg) else { return None }
    let clean = arg.trim().to_owned()
    if clean != "" {
      args.push(clean)
    }
  }
  Some(args)
}

///|
fn pdf_workbench_pdflite_helper_split_args(value : String) -> Array[String] {
  let args : Array[String] = []
  let current : Array[Char] = []
  for ch in value.to_array() {
    if pdf_workbench_pdflite_arg_whitespace(ch) {
      pdf_workbench_pdflite_push_arg(args, current)
    } else {
      current.push(ch)
    }
  }
  pdf_workbench_pdflite_push_arg(args, current)
  args
}

///|
fn pdf_workbench_pdflite_push_arg(
  args : Array[String],
  current : Array[Char],
) -> Unit {
  if !current.is_empty() {
    let arg = String::from_array(current).trim().to_owned()
    if arg != "" {
      args.push(arg)
    }
    current.clear()
  }
}

///|
fn pdf_workbench_pdflite_arg_whitespace(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}
