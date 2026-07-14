///|
struct CliOptions {
  repo_root : String
  status_file : String
  smoke_source : String
  log_verifier_source : String
  unix_log_verifier_wrapper : String
  powershell_log_verifier_wrapper : String
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui_skia/verify_native_smoke_capabilities [options]
    #|
    #|Checks that every native smoke capability marker in skia-platform-status.json
    #|is emitted by the native smoke MoonBit sources, that the MoonBit native
    #|smoke log verifier consumes the status contract, and that the Unix and
    #|PowerShell compatibility paths delegate to that verifier.
    #|
    #|Options:
    #|  --repo-root PATH                 Repository root used to resolve relative paths. Defaults to cwd.
    #|  --status-file PATH               Platform status JSON file. Defaults to skia-platform-status.json.
    #|  --smoke-source PATH              Native smoke MoonBit source file or directory. Defaults to scripts/native_smoke.
    #|  --log-verifier-source PATH       MoonBit log verifier source file or directory. Defaults to tools/moui_skia/verify_native_smoke_log.
    #|  --unix-log-verifier PATH         Unix compatibility wrapper. Defaults to scripts/verify-native-smoke-log.sh.
    #|  --powershell-log-verifier PATH   PowerShell compatibility wrapper. Defaults to scripts/verify-native-smoke-log.ps1.
    #|  -h, --help                       Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let status_file = Ref("skia-platform-status.json")
  let smoke_source = Ref("scripts/native_smoke")
  let log_verifier_source = Ref("tools/moui_skia/verify_native_smoke_log")
  let unix_log_verifier_wrapper = Ref("scripts/verify-native-smoke-log.sh")
  let powershell_log_verifier_wrapper = Ref(
    "scripts/verify-native-smoke-log.ps1",
  )
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root.val = args[index + 1]
        index += 2
      }
      "--status-file" => {
        if index + 1 >= args.length() {
          return Err("missing value for --status-file")
        }
        status_file.val = args[index + 1]
        index += 2
      }
      "--smoke-source" => {
        if index + 1 >= args.length() {
          return Err("missing value for --smoke-source")
        }
        smoke_source.val = args[index + 1]
        index += 2
      }
      "--log-verifier-source" => {
        if index + 1 >= args.length() {
          return Err("missing value for --log-verifier-source")
        }
        log_verifier_source.val = args[index + 1]
        index += 2
      }
      "--unix-log-verifier" => {
        if index + 1 >= args.length() {
          return Err("missing value for --unix-log-verifier")
        }
        unix_log_verifier_wrapper.val = args[index + 1]
        index += 2
      }
      "--powershell-log-verifier" => {
        if index + 1 >= args.length() {
          return Err("missing value for --powershell-log-verifier")
        }
        powershell_log_verifier_wrapper.val = args[index + 1]
        index += 2
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({
    repo_root: repo_root.val,
    status_file: status_file.val,
    smoke_source: smoke_source.val,
    log_verifier_source: log_verifier_source.val,
    unix_log_verifier_wrapper: unix_log_verifier_wrapper.val,
    powershell_log_verifier_wrapper: powershell_log_verifier_wrapper.val,
    help: help.val,
  })
}

///|
fn json_string_field(fields : Map[String, Json], key : String) -> String {
  match fields.get(key) {
    Some(Json::String(value)) => value.trim().to_owned()
    _ => ""
  }
}

///|
fn json_object(
  value : Json,
  label : String,
) -> Result[Map[String, Json], String] {
  match value {
    Json::Object(fields) => Ok(fields)
    _ => Err(label)
  }
}

///|
fn native_smoke_capabilities(
  status : Map[String, Json],
) -> Result[Array[Json], String] {
  match status.get("native_smoke_capabilities") {
    Some(Json::Array(values)) if !values.is_empty() => Ok(values)
    _ => Err("platform status is missing native_smoke_capabilities")
  }
}

///|
fn native_smoke_conditional_capabilities(
  status : Map[String, Json],
) -> Result[Array[Json], String] {
  match status.get("native_smoke_conditional_capabilities") {
    None | Some(Json::Null) => Ok([])
    Some(Json::Array(values)) => Ok(values)
    _ =>
      Err(
        "platform status native_smoke_conditional_capabilities must be a list",
      )
  }
}

///|
fn push_missing_marker(
  marker : String,
  smoke_source : String,
  missing_from_source : Array[String],
) -> Unit {
  if !smoke_source.contains(marker) {
    missing_from_source.push(marker)
  }
}

///|
fn verify_log_verifier_source(
  log_verifier_source : String,
) -> Result[Unit, String] {
  let required_tokens = [
    "native_smoke_capabilities", "native_smoke_expected_values", "native_smoke_conditional_capabilities",
  ]
  for token in required_tokens {
    if !log_verifier_source.contains(token) {
      return Err(
        "native smoke log verifier source is missing status contract token: " +
        token,
      )
    }
  }
  Ok(())
}

///|
fn verify_log_verifier_wrapper(
  wrapper_text : String,
  wrapper_path : String,
) -> Result[Unit, String] {
  if !wrapper_text.contains("tools/moui_skia/verify_native_smoke_log") &&
    !wrapper_text.contains("verify_native_smoke_log.exe") {
    return Err(
      "native smoke log compatibility wrapper does not delegate to the MoonBit verifier: " +
      wrapper_path,
    )
  }
  Ok(())
}

///|
fn verify_capability_markers(
  status : Map[String, Json],
  smoke_source : String,
  log_verifier_source : String,
  unix_log_verifier_wrapper : String,
  powershell_log_verifier_wrapper : String,
  smoke_source_path : String,
  log_verifier_source_path : String,
  unix_log_verifier_path : String,
  powershell_log_verifier_path : String,
) -> Result[Unit, String] {
  let capabilities = match native_smoke_capabilities(status) {
    Ok(values) => values
    Err(message) => return Err(message)
  }
  let conditional_capabilities = match
    native_smoke_conditional_capabilities(status) {
    Ok(values) => values
    Err(message) => return Err(message)
  }

  let seen_markers : Map[String, Bool] = Map([])
  let missing_from_source : Array[String] = []

  for capability in capabilities {
    let fields = match
      json_object(
        capability, "native_smoke_capabilities entries must be objects",
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let marker = json_string_field(fields, "marker")
    let capability_id = json_string_field(fields, "id")
    if marker == "" {
      return Err("native smoke capability is missing marker: " + capability_id)
    }
    if seen_markers.contains(marker) {
      return Err("duplicate native smoke capability marker: " + marker)
    }
    seen_markers[marker] = true
    push_missing_marker(marker, smoke_source, missing_from_source)
  }

  for capability in conditional_capabilities {
    let fields = match
      json_object(
        capability, "native_smoke_conditional_capabilities entries must be objects",
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let marker = json_string_field(fields, "marker")
    let when_marker = json_string_field(fields, "when_marker")
    let when_value = json_string_field(fields, "when_value")
    let capability_id = json_string_field(fields, "id")
    if marker == "" {
      return Err(
        "native smoke conditional capability is missing marker: " +
        capability_id,
      )
    }
    if when_marker == "" {
      return Err(
        "native smoke conditional capability is missing when_marker: " +
        capability_id,
      )
    }
    if when_value == "" {
      return Err(
        "native smoke conditional capability is missing when_value: " +
        capability_id,
      )
    }
    if seen_markers.contains(marker) {
      return Err("duplicate native smoke capability marker: " + marker)
    }
    if !seen_markers.contains(when_marker) {
      return Err(
        "native smoke conditional capability references an unknown condition marker: " +
        capability_id +
        ": " +
        when_marker,
      )
    }
    seen_markers[marker] = true
    push_missing_marker(marker, smoke_source, missing_from_source)
  }

  if !missing_from_source.is_empty() {
    return Err(
      "native smoke capabilities are not emitted by " +
      smoke_source_path +
      ": " +
      @tools.comma_join(missing_from_source),
    )
  }
  match verify_log_verifier_source(log_verifier_source) {
    Ok(_) => ()
    Err(message) => return Err(message + " in " + log_verifier_source_path)
  }
  match
    verify_log_verifier_wrapper(
      unix_log_verifier_wrapper, unix_log_verifier_path,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    verify_log_verifier_wrapper(
      powershell_log_verifier_wrapper, powershell_log_verifier_path,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(())
}

///|
fn verify_native_smoke_capabilities(
  options : CliOptions,
) -> Result[String, String] {
  let resolved_status_file = @tools.resolve_path(
    options.repo_root,
    options.status_file,
  )
  let resolved_smoke_source = @tools.resolve_path(
    options.repo_root,
    options.smoke_source,
  )
  let resolved_log_verifier_source = @tools.resolve_path(
    options.repo_root,
    options.log_verifier_source,
  )
  let resolved_unix_log_verifier = @tools.resolve_path(
    options.repo_root,
    options.unix_log_verifier_wrapper,
  )
  let resolved_powershell_log_verifier = @tools.resolve_path(
    options.repo_root,
    options.powershell_log_verifier_wrapper,
  )

  let status_text = match
    @tools.read_required_text(
      resolved_status_file, "required capability smoke input",
    ) {
    Ok(text) => text
    Err(message) => return Err(message)
  }
  let unix_log_verifier = match
    @tools.read_required_text(
      resolved_unix_log_verifier, "required capability smoke input",
    ) {
    Ok(text) => text
    Err(message) => return Err(message)
  }
  let powershell_log_verifier = match
    @tools.read_required_text(
      resolved_powershell_log_verifier, "required capability smoke input",
    ) {
    Ok(text) => text
    Err(message) => return Err(message)
  }
  let smoke_source = match
    @tools.read_file_or_directory_text(
      resolved_smoke_source, ".mbt", "required capability smoke input is missing: ",
      "native smoke source directory has no .mbt files: ",
    ) {
    Ok(text) => text
    Err(message) => return Err(message)
  }
  let log_verifier_source = match
    @tools.read_file_or_directory_text(
      resolved_log_verifier_source, ".mbt", "required capability smoke input is missing: ",
      "native smoke log verifier source directory has no .mbt files: ",
    ) {
    Ok(text) => text
    Err(message) => return Err(message)
  }

  let status_json = @json.parse(status_text) catch {
    _ => return Err("Skia platform status JSON is invalid")
  }
  let status = match
    json_object(status_json, "Skia platform status JSON root must be an object") {
    Ok(fields) => fields
    Err(message) => return Err(message)
  }
  match
    verify_capability_markers(
      status, smoke_source, log_verifier_source, unix_log_verifier, powershell_log_verifier,
      resolved_smoke_source, resolved_log_verifier_source, resolved_unix_log_verifier,
      resolved_powershell_log_verifier,
    ) {
    Ok(_) =>
      Ok(
        "Verified native smoke capability markers across " +
        resolved_status_file +
        ", " +
        resolved_smoke_source +
        ", " +
        resolved_log_verifier_source +
        ", " +
        resolved_unix_log_verifier +
        ", and " +
        resolved_powershell_log_verifier +
        ".",
      )
    Err(message) => Err(message)
  }
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match verify_native_smoke_capabilities(options) {
        Ok(message) => {
          println(message)
          0
        }
        Err(message) => {
          println(message)
          1
        }
      }
    Err(message) => {
      println(message)
      println(usage())
      2
    }
  }
}

///|
fn main {
  let code = run(@tools.args_without_program(@env.args()))
  if code != 0 {
    @sys.exit(code)
  }
}
