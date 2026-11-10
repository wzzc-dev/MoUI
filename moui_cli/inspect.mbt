///|
priv struct ParsedInspect {
  help : Bool
  json : Bool
  file : String?
  port : Int32?
  request_method : String
}

///|
fn inspect_usage() -> String {
  (
    #|Usage: moui inspect [options]
    #|
    #|Read the latest DevTools document published by `moui dev --inspect`.
    #|
    #|Options:
    #|  --file PATH   DevTools document path. Defaults to MOUI_DEVTOOLS_FILE
    #|                or .moui/devtools.json.
    #|  --port PORT   Connect to the running DevTools socket instead of a file.
    #|  --method NAME Request method: all (default), snapshot, trace,
    #|                diagnostics, or ping.
    #|  --json        Print the raw document JSON.
    #|  -h, --help    Show this help.
  )
}

///|
fn parse_inspect_args(
  args : Array[String],
  cwd : String,
) -> Result[ParsedInspect, String] {
  let help = Ref(false)
  let json = Ref(false)
  let file : Ref[String?] = Ref(None)
  let port : Ref[Int32?] = Ref(None)
  let request_method = Ref("all")
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    let (name, inline) = option_parts(argument)
    match name {
      "-h" | "--help" =>
        match flag_without_value(inline, name) {
          Ok(_) => help.val = true
          Err(message) => return Err(message)
        }
      "--json" =>
        match flag_without_value(inline, name) {
          Ok(_) => json.val = true
          Err(message) => return Err(message)
        }
      "--file" =>
        match option_value(args, index, inline, name) {
          Ok((value, next)) => {
            file.val = Some(make_absolute(value, cwd))
            index = next
            continue
          }
          Err(message) => return Err(message)
        }
      "--port" =>
        match option_value(args, index, inline, name) {
          Ok((value, next)) =>
            match parse_int(value) {
              Ok(number) if number > 0 => {
                port.val = Some(number)
                index = next
                continue
              }
              _ => return Err("--port must be a positive integer")
            }
          Err(message) => return Err(message)
        }
      "--method" =>
        match option_value(args, index, inline, name) {
          Ok((value, next)) => {
            request_method.val = value
            index = next
            continue
          }
          Err(message) => return Err(message)
        }
      _ if argument.has_prefix("-") =>
        return Err("unknown option for moui inspect: " + name)
      _ => return Err("moui inspect does not accept positional arguments")
    }
    index += 1
  }
  Ok({
    help: help.val,
    json: json.val,
    file: file.val,
    port: port.val,
    request_method: request_method.val,
  })
}

///|
fn inspect_default_path(cwd : String) -> String {
  match @env.get_env_var("MOUI_DEVTOOLS_FILE") {
    Some(path) if path != "" => make_absolute(path, cwd)
    _ => make_absolute(".moui/devtools.json", cwd)
  }
}

///|
/// Render a DevTools document as human text without re-parsing the typed
/// inspector payload. Missing fields fall back to the raw JSON.
fn inspect_document_text(text : String) -> String {
  let parsed = @json.parse(text) catch { _ => return text }
  let fields = match parsed {
    Object(fields) => fields
    _ => return text
  }
  let builder = StringBuilder()
  match fields.get("reportText") {
    Some(String(value)) => builder.write_string(value)
    _ => ()
  }
  match fields.get("traceText") {
    Some(String(value)) => {
      if builder.to_string() != "" {
        builder.write_string("\n\n")
      }
      builder.write_string(value)
    }
    _ => ()
  }
  match fields.get("diagnostics") {
    Some(Array(items)) =>
      if items.length() > 0 {
        if builder.to_string() != "" {
          builder.write_string("\n\n")
        }
        builder.write_string("diagnostics: " + items.length().to_string())
      }
    _ => ()
  }
  let rendered = builder.to_string()
  if rendered == "" {
    text
  } else {
    rendered
  }
}

///|
fn inspect_read_file(path : String) -> String? {
  if !@fs.path_exists(path) {
    return None
  }
  let text = @fs.read_file_to_string(path) catch { _ => return None }
  Some(text)
}

///|
fn inspect_default_port(cwd : String) -> Int32? {
  let path = match @devtools_socket.devtools_port_file_path() {
    Some(value) => make_absolute(value, cwd)
    None => make_absolute(".moui/devtools.port", cwd)
  }
  if !@fs.path_exists(path) {
    return None
  }
  let text = @fs.read_file_to_string(path) catch { _ => return None }
  match parse_int(text.trim().to_owned()) {
    Ok(port) if port > 0 => Some(port)
    _ => None
  }
}

///|
fn inspect_source_text(parsed : ParsedInspect, cwd : String) -> String? {
  match parsed.file {
    Some(path) => inspect_read_file(path)
    None => {
      let port = match parsed.port {
        Some(value) => Some(value)
        None => inspect_default_port(cwd)
      }
      match port {
        Some(value) =>
          match
            @devtools_socket.request(
              value,
              request_method=parsed.request_method,
            ) {
            Some(text) => Some(text)
            None => inspect_read_file(inspect_default_path(cwd))
          }
        None => inspect_read_file(inspect_default_path(cwd))
      }
    }
  }
}

///|
fn run_inspect(args : Array[String], cwd : String) -> CliOutcome {
  let parsed = match parse_inspect_args(args, cwd) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, false, inspect_usage())
  }
  if parsed.help {
    return stdout_outcome(inspect_usage())
  }
  let text = match inspect_source_text(parsed, cwd) {
    Some(value) => value
    None =>
      return failed_outcome(
        "DevTools snapshot not found; run `moui dev --inspect` and wait for the first sample",
        false,
        inspect_usage(),
      )
  }
  if parsed.json {
    stdout_outcome(text)
  } else {
    stdout_outcome(inspect_document_text(text) + "\n")
  }
}
