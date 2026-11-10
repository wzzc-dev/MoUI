///|
priv struct ParsedInspect {
  help : Bool
  json : Bool
  file : String?
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
      _ if argument.has_prefix("-") =>
        return Err("unknown option for moui inspect: " + name)
      _ => return Err("moui inspect does not accept positional arguments")
    }
    index += 1
  }
  Ok({ help: help.val, json: json.val, file: file.val, })
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
fn run_inspect(args : Array[String], cwd : String) -> CliOutcome {
  let parsed = match parse_inspect_args(args, cwd) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, false, inspect_usage())
  }
  if parsed.help {
    return stdout_outcome(inspect_usage())
  }
  let path = match parsed.file {
    Some(value) => value
    None => inspect_default_path(cwd)
  }
  if !@fs.path_exists(path) {
    return failed_outcome(
      "DevTools document not found: " +
      path +
      "; run `moui dev --inspect` and wait for the first sample",
      false,
      inspect_usage(),
    )
  }
  let text = @fs.read_file_to_string(path) catch {
    _ =>
      return failed_outcome(
        "could not read DevTools document: " + path,
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
